class_name PersonaStarChart
extends Control

const BACKGROUND_COLOR := Color("050a18")
const FIELD_CENTER := Vector2(650, 292)
const CARD_SIZE := CardHandCard.CARD_SIZE
const PERSONA_ICON_SIZE := Vector2(150, 84)
const MAX_LEVEL := 10
const LEVEL_ONE_LENGTH := 48.0
const CARD_CLEARANCE := 2.0
const ICON_OVERLAP := 2.0
const TOTAL_TWEEN_SECONDS := 0.32
const CANDIDATE_BOUNDS := Rect2(180, 80, 930, 500)
const POPUP_SAFE_RECT := Rect2(860, 0, 420, 132)
const PAIR_TRACK_CURVE_SEGMENTS := 32
const PAIR_TRACK_CONTROL_PULL := 0.78
const PERSONA_ICON_POSITIONS := {
	CardPropertySet.PERSONA_NIGHTWALKER: Vector2(32, 40),
	CardPropertySet.PERSONA_MOURNER: Vector2(32, 380),
	CardPropertySet.PERSONA_DREAMWALKER: Vector2(1066, 142),
	CardPropertySet.PERSONA_HOMECOMER: Vector2(1066, 380),
}
const PERSONA_COLORS := PersonaVisuals.COLORS
const PAIR_TRACK_ANCHORS := {
	&"nightwalker|mourner": Vector2(220, 286),
	&"nightwalker|dreamwalker": Vector2(650, 88),
	&"nightwalker|homecomer": Vector2(952, 500),
	&"mourner|dreamwalker": Vector2(330, 510),
	&"mourner|homecomer": Vector2(650, 590),
	&"dreamwalker|homecomer": Vector2(1085, 326),
}

var target_totals: Dictionary = {}
var displayed_totals: Dictionary = {}
var total_tweens: Dictionary = {}
var pulse_strengths: Dictionary = {}
var active_pair_recipes: Array[SynthesisRecipeDefinition] = []
var hovered_persona_id: StringName
var totals_initialized := false
var paints_background := true:
	set(value):
		if paints_background == value:
			return
		paints_background = value
		queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for persona_id in CardPropertySet.PERSONAS:
		target_totals[persona_id] = 0.0
		displayed_totals[persona_id] = 0.0
		pulse_strengths[persona_id] = 0.0
	set_process(false)
	queue_redraw()


func set_totals(totals: Dictionary) -> void:
	for persona_id in CardPropertySet.PERSONAS:
		var next_total := float(maxi(int(totals.get(persona_id, 0)), 0))
		var previous_target := float(target_totals.get(persona_id, 0.0))
		var current_total := float(displayed_totals.get(persona_id, previous_target))
		target_totals[persona_id] = next_total
		var previous_tween := total_tweens.get(persona_id) as Tween
		if previous_tween != null and previous_tween.is_valid():
			previous_tween.kill()
		total_tweens.erase(persona_id)
		if not totals_initialized or not is_inside_tree() or is_equal_approx(current_total, next_total):
			displayed_totals[persona_id] = next_total
		else:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_method(
				_set_displayed_total.bind(persona_id),
				current_total,
				next_total,
				TOTAL_TWEEN_SECONDS,
			)
			total_tweens[persona_id] = tween
		if totals_initialized and next_total > previous_target:
			pulse_strengths[persona_id] = 1.0
			set_process(true)
	totals_initialized = true
	queue_redraw()


func set_hovered_persona(persona_id: StringName) -> void:
	if hovered_persona_id == persona_id:
		return
	hovered_persona_id = persona_id
	queue_redraw()


func set_candidate_recipes(recipes: Array[SynthesisRecipeDefinition]) -> void:
	active_pair_recipes.clear()
	for recipe in recipes:
		if _ordered_recipe_personas(recipe).size() == 2:
			active_pair_recipes.append(recipe)
	queue_redraw()


func persona_color(persona_id: StringName) -> Color:
	return PersonaVisuals.color(persona_id)


func axis_progress_points(persona_id: StringName, amount: float) -> PackedVector2Array:
	var start := _axis_start(persona_id)
	if amount <= 0.0:
		return PackedVector2Array([start, start])
	return PackedVector2Array([start, axis_point(persona_id, amount)])


func axis_point(persona_id: StringName, amount: float) -> Vector2:
	var start := _axis_start(persona_id)
	var end := _axis_end(persona_id)
	var direction := (end - start).normalized()
	var available_length := start.distance_to(end)
	var visible_length := _level_length(amount, available_length)
	return start + direction * visible_length


func candidate_position(recipe: SynthesisRecipeDefinition) -> Vector2:
	if recipe == null:
		return FIELD_CENTER
	var personas := _ordered_recipe_personas(recipe)
	if personas.size() == 1:
		var persona_id := personas[0]
		return axis_point(persona_id, float(recipe.required_value(persona_id)))
	if personas.size() != 2:
		return FIELD_CENTER
	var track_points := pair_track_points(recipe)
	if track_points.is_empty():
		return FIELD_CENTER
	var stable_offset := absi(String(recipe.id).hash()) % 5 - 2
	var midpoint := clampi(track_points.size() / 2 + stable_offset, 0, track_points.size() - 1)
	return track_points[midpoint]


func pair_track_points(recipe: SynthesisRecipeDefinition) -> PackedVector2Array:
	var personas := _ordered_recipe_personas(recipe)
	if personas.size() != 2:
		return PackedVector2Array()
	var first_id := personas[0]
	var second_id := personas[1]
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
	for persona_id in CardPropertySet.PERSONAS:
		var strength := maxf(float(pulse_strengths.get(persona_id, 0.0)) - delta * 2.4, 0.0)
		pulse_strengths[persona_id] = strength
		still_pulsing = still_pulsing or strength > 0.0
	queue_redraw()
	if not still_pulsing:
		set_process(false)


func _draw() -> void:
	if paints_background:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_orbit_rings()
	for persona_id in CardPropertySet.PERSONAS:
		_draw_persona_axis(persona_id)
	_draw_pair_tracks()
	_draw_center_ornament()


func _draw_pair_tracks() -> void:
	for recipe in active_pair_recipes:
		var personas := _ordered_recipe_personas(recipe)
		var points := pair_track_points(recipe)
		if personas.size() != 2 or points.size() < 2:
			continue
		var includes_hover := hovered_persona_id in personas
		var muted_by_hover := not hovered_persona_id.is_empty() and not includes_hover
		var pulse := maxf(
			float(pulse_strengths.get(personas[0], 0.0)),
			float(pulse_strengths.get(personas[1], 0.0)),
		)
		var alpha := 0.22 + pulse * 0.24
		if includes_hover:
			alpha = maxf(alpha, 0.46)
		elif muted_by_hover:
			alpha = 0.07
		for index in range(points.size() - 1):
			if index % 2 != 0:
				continue
			var segment_persona := personas[0] if index < (points.size() - 1) / 2 else personas[1]
			draw_line(
				points[index],
				points[index + 1],
				Color(persona_color(segment_persona), alpha),
				1.55 if includes_hover else 1.2,
				true,
			)
		var endpoint_alpha := minf(alpha + 0.20, 1.0)
		draw_circle(points[0], 3.2, Color(persona_color(personas[0]), endpoint_alpha))
		draw_circle(points[-1], 3.2, Color(persona_color(personas[1]), endpoint_alpha))


func _draw_orbit_rings() -> void:
	var reference_id := CardPropertySet.PERSONA_NIGHTWALKER
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


func _draw_persona_axis(persona_id: StringName) -> void:
	var start := _axis_start(persona_id)
	var end := _axis_end(persona_id)
	var direction := (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var hovered := hovered_persona_id == persona_id
	draw_line(start, end, Color("dce7ef", 0.055 if not hovered else 0.12), 7.0, true)
	draw_line(start, end, Color("dce7ef", 0.20 if not hovered else 0.42), 1.25, true)
	for level in range(1, MAX_LEVEL + 1):
		var tick_center := axis_point(persona_id, float(level))
		var tick_half_length := 7.0 if level in [5, 10] else 4.0
		var tick_alpha := 0.42 if level in [5, 10] else 0.23
		draw_line(
			tick_center - normal * tick_half_length,
			tick_center + normal * tick_half_length,
			Color("dce7ef", tick_alpha),
			1.2,
			true,
		)
	var displayed_total := float(displayed_totals.get(persona_id, 0.0))
	if displayed_total <= 0.0:
		return
	var progress_end := axis_point(persona_id, displayed_total)
	var color := persona_color(persona_id)
	draw_line(start, progress_end, Color(color, 0.10), 11.0, true)
	draw_line(start, progress_end, Color(color, 0.28), 5.0, true)
	draw_line(start, progress_end, Color(color, 0.96), 1.8, true)
	draw_circle(progress_end, 11.0, Color(color, 0.09), true, -1.0, true)
	draw_circle(progress_end, 5.0, Color(color, 0.34), true, -1.0, true)
	draw_circle(progress_end, 2.6, Color(color, 1.0), true, -1.0, true)
	var pulse := float(pulse_strengths.get(persona_id, 0.0))
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


func _set_displayed_total(value: float, persona_id: StringName) -> void:
	displayed_totals[persona_id] = value
	queue_redraw()


func _axis_start(persona_id: StringName) -> Vector2:
	var direction := (_persona_icon_center(persona_id) - FIELD_CENTER).normalized()
	var distance := _center_to_rect_edge_distance(CARD_SIZE, direction) + CARD_CLEARANCE
	return FIELD_CENTER + direction * distance


func _axis_end(persona_id: StringName) -> Vector2:
	var icon_center := _persona_icon_center(persona_id)
	var direction := (icon_center - FIELD_CENTER).normalized()
	var icon_edge_distance := _center_to_rect_edge_distance(PERSONA_ICON_SIZE, direction)
	return icon_center - direction * (icon_edge_distance - ICON_OVERLAP)


func _persona_icon_center(persona_id: StringName) -> Vector2:
	var icon_position := PERSONA_ICON_POSITIONS.get(persona_id, Vector2.ZERO) as Vector2
	return icon_position + PERSONA_ICON_SIZE * 0.5


func _level_length(amount: float, available_length: float) -> float:
	if amount <= 0.0:
		return 0.0
	var clamped_amount := clampf(amount, 1.0, float(MAX_LEVEL))
	var first_length := minf(LEVEL_ONE_LENGTH, available_length)
	var growth := (clamped_amount - 1.0) / float(MAX_LEVEL - 1)
	return lerpf(first_length, available_length, growth)


func _ordered_recipe_personas(recipe: SynthesisRecipeDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	for persona_id in CardPropertySet.PERSONAS:
		if recipe.required_value(persona_id) > 0:
			result.append(persona_id)
	return result


func _pair_id(first: StringName, second: StringName) -> StringName:
	var first_index := CardPropertySet.PERSONAS.find(first)
	var second_index := CardPropertySet.PERSONAS.find(second)
	return (
		StringName("%s|%s" % [first, second])
		if first_index <= second_index
		else StringName("%s|%s" % [second, first])
	)


static func _center_to_rect_edge_distance(rect_size: Vector2, direction: Vector2) -> float:
	var distance_x := INF if is_zero_approx(direction.x) else rect_size.x * 0.5 / absf(direction.x)
	var distance_y := INF if is_zero_approx(direction.y) else rect_size.y * 0.5 / absf(direction.y)
	return minf(distance_x, distance_y)
