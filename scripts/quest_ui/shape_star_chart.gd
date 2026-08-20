class_name ShapeStarChart
extends Control

const BACKGROUND_COLOR := Color("050a18")
const FIELD_CENTER := Vector2(650, 292)
const CARD_SIZE := CardHandCard.CARD_SIZE
const SHAPE_ICON_SIZE := Vector2(150, 84)
const MAX_LEVEL := 10
const LEVEL_ONE_LENGTH := 48.0
const CARD_CLEARANCE := 2.0
const ICON_OVERLAP := 2.0
const TOTAL_TWEEN_SECONDS := 0.32
const CANDIDATE_BOUNDS := Rect2(180, 80, 930, 500)
const POPUP_SAFE_RECT := Rect2(860, 0, 420, 132)
const PAIR_TRACK_CURVE_SEGMENTS := 32
const PAIR_TRACK_CONTROL_PULL := 0.78
const SHAPE_ICON_POSITIONS := {
	CardPropertySet.SHAPE_LIGHT: Vector2(32, 40),
	CardPropertySet.SHAPE_TEAR: Vector2(32, 380),
	CardPropertySet.SHAPE_DREAM: Vector2(1066, 142),
	CardPropertySet.SHAPE_SLEEP: Vector2(1066, 380),
}
const SHAPE_COLORS := ShapeVisuals.COLORS
const PAIR_TRACK_ANCHORS := {
	&"light|tear": Vector2(220, 286),
	&"light|dream": Vector2(650, 88),
	&"light|sleep": Vector2(952, 500),
	&"tear|dream": Vector2(330, 510),
	&"tear|sleep": Vector2(650, 590),
	&"dream|sleep": Vector2(1085, 326),
}

var target_totals: Dictionary = {}
var displayed_totals: Dictionary = {}
var total_tweens: Dictionary = {}
var pulse_strengths: Dictionary = {}
var active_pair_recipes: Array[SynthesisRecipeDefinition] = []
var hovered_shape_id: StringName
var totals_initialized := false
var background_visible := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for shape_id in CardPropertySet.SHAPES:
		target_totals[shape_id] = 0.0
		displayed_totals[shape_id] = 0.0
		pulse_strengths[shape_id] = 0.0
	set_process(false)
	queue_redraw()


func set_totals(totals: Dictionary) -> void:
	for shape_id in CardPropertySet.SHAPES:
		var next_total := float(maxi(int(totals.get(shape_id, 0)), 0))
		var previous_target := float(target_totals.get(shape_id, 0.0))
		var current_total := float(displayed_totals.get(shape_id, previous_target))
		target_totals[shape_id] = next_total
		var previous_tween := total_tweens.get(shape_id) as Tween
		if previous_tween != null and previous_tween.is_valid():
			previous_tween.kill()
		total_tweens.erase(shape_id)
		if not totals_initialized or not is_inside_tree() or is_equal_approx(current_total, next_total):
			displayed_totals[shape_id] = next_total
		else:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_method(
				_set_displayed_total.bind(shape_id),
				current_total,
				next_total,
				TOTAL_TWEEN_SECONDS,
			)
			total_tweens[shape_id] = tween
		if totals_initialized and next_total > previous_target:
			pulse_strengths[shape_id] = 1.0
			set_process(true)
	totals_initialized = true
	queue_redraw()


func set_hovered_shape(shape_id: StringName) -> void:
	if hovered_shape_id == shape_id:
		return
	hovered_shape_id = shape_id
	queue_redraw()


func set_background_visible(visible: bool) -> void:
	if background_visible == visible:
		return
	background_visible = visible
	queue_redraw()


func set_candidate_recipes(recipes: Array[SynthesisRecipeDefinition]) -> void:
	active_pair_recipes.clear()
	for recipe in recipes:
		if _ordered_recipe_shapes(recipe).size() == 2:
			active_pair_recipes.append(recipe)
	queue_redraw()


func shape_color(shape_id: StringName) -> Color:
	return ShapeVisuals.color(shape_id)


func axis_progress_points(shape_id: StringName, amount: float) -> PackedVector2Array:
	var start := _axis_start(shape_id)
	if amount <= 0.0:
		return PackedVector2Array([start, start])
	return PackedVector2Array([start, axis_point(shape_id, amount)])


func axis_point(shape_id: StringName, amount: float) -> Vector2:
	var start := _axis_start(shape_id)
	var end := _axis_end(shape_id)
	var direction := (end - start).normalized()
	var available_length := start.distance_to(end)
	var visible_length := _level_length(amount, available_length)
	return start + direction * visible_length


func candidate_position(
	recipe: SynthesisRecipeDefinition,
	required_shapes: Dictionary = {},
) -> Vector2:
	if recipe == null:
		return FIELD_CENTER
	var shapes := _ordered_recipe_shapes(recipe)
	if shapes.size() == 1:
		var shape_id := shapes[0]
		var required_value := (
			int(required_shapes.get(shape_id, recipe.required_value(shape_id)))
			if not required_shapes.is_empty()
			else recipe.required_value(shape_id)
		)
		return axis_point(shape_id, float(required_value))
	if shapes.size() != 2:
		return FIELD_CENTER
	var track_points := pair_track_points(recipe)
	if track_points.is_empty():
		return FIELD_CENTER
	var stable_offset := absi(String(recipe.id).hash()) % 5 - 2
	var midpoint := clampi(track_points.size() / 2 + stable_offset, 0, track_points.size() - 1)
	return track_points[midpoint]


func pair_track_points(recipe: SynthesisRecipeDefinition) -> PackedVector2Array:
	var shapes := _ordered_recipe_shapes(recipe)
	if shapes.size() != 2:
		return PackedVector2Array()
	var first_id := shapes[0]
	var second_id := shapes[1]
	var start := axis_point(first_id, float(recipe.required_value(first_id)))
	var end := axis_point(second_id, float(recipe.required_value(second_id)))
	var pair_id := _pair_id(first_id, second_id)
	var anchor := PAIR_TRACK_ANCHORS.get(pair_id, FIELD_CENTER) as Vector2
	var first_control := start.lerp(anchor, PAIR_TRACK_CONTROL_PULL)
	var second_control := end.lerp(anchor, PAIR_TRACK_CONTROL_PULL)
	var points := PackedVector2Array()
	for step in range(PAIR_TRACK_CURVE_SEGMENTS + 1):
		var t := float(step) / float(PAIR_TRACK_CURVE_SEGMENTS)
		var inverse := 1.0 - t
		points.append(
			start * inverse * inverse * inverse
			+ first_control * 3.0 * inverse * inverse * t
			+ second_control * 3.0 * inverse * t * t
			+ end * t * t * t
		)
	return points


func _process(delta: float) -> void:
	var still_pulsing := false
	for shape_id in CardPropertySet.SHAPES:
		var strength := maxf(float(pulse_strengths.get(shape_id, 0.0)) - delta * 2.4, 0.0)
		pulse_strengths[shape_id] = strength
		still_pulsing = still_pulsing or strength > 0.0
	queue_redraw()
	if not still_pulsing:
		set_process(false)


func _draw() -> void:
	if background_visible:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_orbit_rings()
	for shape_id in CardPropertySet.SHAPES:
		_draw_shape_axis(shape_id)
	_draw_pair_tracks()
	_draw_center_ornament()


func _draw_pair_tracks() -> void:
	for recipe in active_pair_recipes:
		var shapes := _ordered_recipe_shapes(recipe)
		var points := pair_track_points(recipe)
		if shapes.size() != 2 or points.size() < 2:
			continue
		var includes_hover := hovered_shape_id in shapes
		var muted_by_hover := not hovered_shape_id.is_empty() and not includes_hover
		var pulse := maxf(
			float(pulse_strengths.get(shapes[0], 0.0)),
			float(pulse_strengths.get(shapes[1], 0.0)),
		)
		var alpha := 0.22 + pulse * 0.24
		if includes_hover:
			alpha = maxf(alpha, 0.46)
		elif muted_by_hover:
			alpha = 0.07
		for index in range(points.size() - 1):
			if index % 2 != 0:
				continue
			var segment_shape := shapes[0] if index < (points.size() - 1) / 2 else shapes[1]
			draw_line(
				points[index],
				points[index + 1],
				Color(shape_color(segment_shape), alpha),
				1.55 if includes_hover else 1.2,
				true,
			)
		var endpoint_alpha := minf(alpha + 0.20, 1.0)
		draw_circle(points[0], 3.2, Color(shape_color(shapes[0]), endpoint_alpha))
		draw_circle(points[-1], 3.2, Color(shape_color(shapes[1]), endpoint_alpha))


func _draw_orbit_rings() -> void:
	var reference_id := CardPropertySet.SHAPE_LIGHT
	for level in [2, 4, 6, 8, 10]:
		var radius := FIELD_CENTER.distance_to(axis_point(reference_id, float(level)))
		var alpha := 0.045 if level not in [5, 10] else 0.07
		draw_arc(
			FIELD_CENTER,
			radius,
			0.0,
			TAU,
			160,
			Color("b9c9d8", alpha),
			1.0,
			true,
		)


func _draw_shape_axis(shape_id: StringName) -> void:
	var start := _axis_start(shape_id)
	var end := _axis_end(shape_id)
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var hovered := hovered_shape_id == shape_id
	var color := shape_color(shape_id)
	if hovered:
		# Layered strokes approximate a soft additive glow without making the
		# precise axis harder to read against the dark chart.
		draw_line(start, end, Color(color, 0.055), 18.0, true)
		draw_line(start, end, Color(color, 0.14), 9.0, true)
		draw_line(start, end, Color(color, 0.72), 1.65, true)
	else:
		draw_line(start, end, Color("dce7ef", 0.055), 7.0, true)
		draw_line(start, end, Color("dce7ef", 0.20), 1.25, true)
	for level in range(1, MAX_LEVEL + 1):
		var tick_center := axis_point(shape_id, float(level))
		var tick_half_length := 7.0 if level in [5, 10] else 4.0
		var tick_alpha := 0.42 if level in [5, 10] else 0.23
		draw_line(
			tick_center - normal * tick_half_length,
			tick_center + normal * tick_half_length,
			Color(color, minf(tick_alpha + 0.18, 0.72))
			if hovered
			else Color("dce7ef", tick_alpha),
			1.45 if hovered else 1.2,
			true,
		)
	var displayed_total := float(displayed_totals.get(shape_id, 0.0))
	if displayed_total <= 0.0:
		return
	var progress_end := axis_point(shape_id, displayed_total)
	draw_line(start, progress_end, Color(color, 0.10), 11.0, true)
	draw_line(start, progress_end, Color(color, 0.28), 5.0, true)
	draw_line(start, progress_end, Color(color, 0.96), 1.8, true)
	draw_circle(progress_end, 11.0, Color(color, 0.09), true, -1.0, true)
	draw_circle(progress_end, 5.0, Color(color, 0.34), true, -1.0, true)
	draw_circle(progress_end, 2.6, Color(color, 1.0), true, -1.0, true)
	var pulse := float(pulse_strengths.get(shape_id, 0.0))
	if pulse > 0.0:
		draw_arc(
			progress_end,
			8.0 + (1.0 - pulse) * 15.0,
			0.0,
			TAU,
			40,
			Color(color, pulse * 0.72),
			1.8,
			true,
		)


func _draw_center_ornament() -> void:
	for radius in [60.0, 66.0]:
		draw_arc(
			FIELD_CENTER,
			radius,
			0.0,
			TAU,
			96,
			Color("b8c7d4", 0.055),
			1.0,
			true,
		)


func _set_displayed_total(value: float, shape_id: StringName) -> void:
	displayed_totals[shape_id] = value
	queue_redraw()


func _axis_start(shape_id: StringName) -> Vector2:
	var direction := (_shape_icon_center(shape_id) - FIELD_CENTER).normalized()
	var distance := _center_to_rect_edge_distance(CARD_SIZE, direction) + CARD_CLEARANCE
	return FIELD_CENTER + direction * distance


func _axis_end(shape_id: StringName) -> Vector2:
	var icon_center := _shape_icon_center(shape_id)
	var direction := (icon_center - FIELD_CENTER).normalized()
	var icon_edge_distance := _center_to_rect_edge_distance(SHAPE_ICON_SIZE, direction)
	return icon_center - direction * (icon_edge_distance - ICON_OVERLAP)


func _shape_icon_center(shape_id: StringName) -> Vector2:
	var icon_position := SHAPE_ICON_POSITIONS.get(shape_id, Vector2.ZERO) as Vector2
	return icon_position + SHAPE_ICON_SIZE * 0.5


func _level_length(amount: float, available_length: float) -> float:
	if amount <= 0.0:
		return 0.0
	var clamped_amount := clampf(amount, 1.0, float(MAX_LEVEL))
	var first_length := minf(LEVEL_ONE_LENGTH, available_length)
	var growth := (clamped_amount - 1.0) / float(MAX_LEVEL - 1)
	return lerpf(first_length, available_length, growth)


func _ordered_recipe_shapes(recipe: SynthesisRecipeDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	for shape_id in CardPropertySet.SHAPES:
		if recipe.required_value(shape_id) > 0:
			result.append(shape_id)
	return result


func _pair_id(first: StringName, second: StringName) -> StringName:
	var first_index := CardPropertySet.SHAPES.find(first)
	var second_index := CardPropertySet.SHAPES.find(second)
	return (
		StringName("%s|%s" % [first, second])
		if first_index <= second_index
		else StringName("%s|%s" % [second, first])
	)


static func _center_to_rect_edge_distance(rect_size: Vector2, direction: Vector2) -> float:
	var distance_x := INF if is_zero_approx(direction.x) else rect_size.x * 0.5 / absf(direction.x)
	var distance_y := INF if is_zero_approx(direction.y) else rect_size.y * 0.5 / absf(direction.y)
	return minf(distance_x, distance_y)
