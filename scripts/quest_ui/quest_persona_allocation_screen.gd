class_name QuestPersonaAllocationScreen
extends Control

signal allocation_confirmed(levels: Dictionary)

const TOTAL_POINTS := 5
const MAX_VALUE := 3
const FIELD_CENTER := Vector2(640, 270)
const NODE_SIZE := Vector2(22, 22)
const NODE_DOT_RADIUS := 2.0
const NODE_PULSE_MIN_RADIUS := 3.5
const NODE_PULSE_MAX_RADIUS := 11.0
const NODE_DISTANCES := [150.0, 210.0, 270.0]
const AXIS_END_DISTANCE := 270.0
const ICON_SIZE := Vector2(120, 68)
const ICON_CENTERS := {
	CardPropertySet.SHAPE_LIGHT: Vector2(270, 148),
	CardPropertySet.SHAPE_TEAR: Vector2(270, 452),
	CardPropertySet.SHAPE_DREAM: Vector2(1010, 148),
	CardPropertySet.SHAPE_SLEEP: Vector2(1010, 452),
}
const ICON_DISPLAY_SCALES := {
	CardPropertySet.SHAPE_LIGHT: 1.0,
	CardPropertySet.SHAPE_TEAR: 1.0,
	CardPropertySet.SHAPE_DREAM: 1.22,
	CardPropertySet.SHAPE_SLEEP: 0.72,
}
const ICON_GLOW_SCALES := [1.08, 1.17, 1.29]
const ICON_GLOW_ALPHAS := [0.42, 0.18, 0.065]
const PORTRAIT_SIZE := Vector2(235.5, 540)
const PORTRAIT_BOTTOM := 728.0
const PERSONA_TITLE_FONT_SIZE := 27
const PERSONA_BODY_FONT_SIZE := 18
const PERSONA_COPY_RECTS := {
	# Each copy block is centered on its icon so both the title and body remain
	# visually anchored to that symbol.
	CardPropertySet.SHAPE_LIGHT: Rect2(80, 210, 380, 118),
	CardPropertySet.SHAPE_TEAR: Rect2(80, 500, 380, 118),
	CardPropertySet.SHAPE_DREAM: Rect2(820, 210, 380, 118),
	CardPropertySet.SHAPE_SLEEP: Rect2(820, 500, 380, 118),
}
const PERSONA_COPY_KEYS := {
	CardPropertySet.SHAPE_LIGHT: &"opening.allocation.persona.light.body",
	CardPropertySet.SHAPE_TEAR: &"opening.allocation.persona.tear.body",
	CardPropertySet.SHAPE_DREAM: &"opening.allocation.persona.dream.body",
	CardPropertySet.SHAPE_SLEEP: &"opening.allocation.persona.sleep.body",
}

var selected_values: Dictionary = {}
var node_buttons: Dictionary = {}
var icon_buttons: Dictionary = {}
var icon_glow_layers: Dictionary = {}
var value_labels: Dictionary = {}
var persona_copy_labels: Dictionary = {}
var pulse_strengths: Dictionary = {}
var hovered_shape_id: StringName
var pinned_shape_id: StringName
var node_pulse_phase := 0.0
var title_label: Label
var remaining_label: Label
var enter_button: Button
var points_glow_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for shape_id in CardPropertySet.SHAPES:
		selected_values[shape_id] = 0
		pulse_strengths[shape_id] = 0.0
	_build_node_buttons()
	_build_portrait()
	_build_shape_icons()
	_build_persona_copy()
	_build_heading()
	_build_enter_button()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	set_process(true)
	_refresh()
	queue_redraw()


func reset_draft() -> void:
	for shape_id in CardPropertySet.SHAPES:
		selected_values[shape_id] = 0
		pulse_strengths[shape_id] = 0.0
	hovered_shape_id = &""
	pinned_shape_id = &""
	node_pulse_phase = 0.0
	set_process(true)
	_refresh()
	queue_redraw()


func remaining_points() -> int:
	var spent := 0
	for shape_id in CardPropertySet.SHAPES:
		spent += int(selected_values.get(shape_id, 0))
	return TOTAL_POINTS - spent


func selected_value(shape_id: StringName) -> int:
	return int(selected_values.get(shape_id, 0))


func _build_node_buttons() -> void:
	for shape_id in CardPropertySet.SHAPES:
		var shape_nodes: Dictionary = {}
		for value in range(1, MAX_VALUE + 1):
			var button := Button.new()
			button.name = "%sValue%d" % [String(shape_id).to_pascal_case(), value]
			button.position = _node_position(shape_id, value) - NODE_SIZE * 0.5
			button.size = NODE_SIZE
			button.custom_minimum_size = NODE_SIZE
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.tooltip_text = ""
			var empty_style := StyleBoxEmpty.new()
			for state_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
				button.add_theme_stylebox_override(state_name, empty_style)
			button.pressed.connect(_on_node_pressed.bind(shape_id, value))
			add_child(button)
			shape_nodes[value] = button
		node_buttons[shape_id] = shape_nodes


func _build_portrait() -> void:
	var portrait := Sprite2D.new()
	portrait.name = "BagPortrait"
	portrait.texture = load("res://resources/character/bag.png") as Texture2D
	portrait.position = Vector2(
		FIELD_CENTER.x,
		PORTRAIT_BOTTOM - PORTRAIT_SIZE.y * 0.5,
	)
	if portrait.texture != null:
		var texture_size := portrait.texture.get_size()
		var scale_factor := PORTRAIT_SIZE.y / maxf(texture_size.y, 1.0)
		portrait.scale = Vector2.ONE * scale_factor
	add_child(portrait)


func _build_shape_icons() -> void:
	for shape_id in CardPropertySet.SHAPES:
		var button := Button.new()
		button.name = "%sPersonaButton" % String(shape_id).to_pascal_case()
		button.position = (ICON_CENTERS[shape_id] as Vector2) - ICON_SIZE * 0.5
		button.size = ICON_SIZE
		button.custom_minimum_size = ICON_SIZE
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = ""
		button.pressed.connect(_on_icon_pressed.bind(shape_id))
		button.mouse_entered.connect(_on_icon_hovered.bind(shape_id))
		button.mouse_exited.connect(_on_icon_unhovered.bind(shape_id))
		add_child(button)

		var texture := ShapeVisuals.symbol_texture(shape_id)
		var display_scale := float(ICON_DISPLAY_SCALES.get(shape_id, 1.0))
		var display_size := ICON_SIZE * display_scale
		var glows: Array[TextureRect] = []
		for glow_index in range(ICON_GLOW_SCALES.size()):
			var glow := TextureRect.new()
			glow.name = "Glow%d" % (glow_index + 1)
			glow.texture = texture
			_configure_icon_texture(glow, display_size)
			glow.pivot_offset = display_size * 0.5
			glow.scale = Vector2.ONE * float(ICON_GLOW_SCALES[glow_index])
			glow.self_modulate = Color(
				ShapeVisuals.color(shape_id),
				float(ICON_GLOW_ALPHAS[glow_index]),
			)
			var material := CanvasItemMaterial.new()
			material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = material
			glow.visible = false
			button.add_child(glow)
			glows.append(glow)
		icon_glow_layers[shape_id] = glows

		var image := TextureRect.new()
		image.name = "PersonaIcon"
		image.texture = texture
		_configure_icon_texture(image, display_size)
		button.add_child(image)

		var value_label := Label.new()
		value_label.name = "Value"
		value_label.anchor_left = 0.76
		value_label.anchor_top = 0.62
		value_label.anchor_right = 1.0
		value_label.anchor_bottom = 1.0
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 22)
		value_label.add_theme_color_override("font_color", Color("f1f2e8"))
		value_label.add_theme_color_override("font_outline_color", Color("111a22"))
		value_label.add_theme_constant_override("outline_size", 4)
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(value_label)
		icon_buttons[shape_id] = button
		value_labels[shape_id] = value_label


func _build_persona_copy() -> void:
	for shape_id in CardPropertySet.SHAPES:
		var copy := RichTextLabel.new()
		copy.name = "%sPersonaCopy" % String(shape_id).to_pascal_case()
		var copy_rect := PERSONA_COPY_RECTS[shape_id] as Rect2
		copy.position = copy_rect.position
		copy.size = copy_rect.size
		copy.bbcode_enabled = true
		copy.fit_content = false
		copy.scroll_active = false
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_theme_font_size_override("normal_font_size", PERSONA_BODY_FONT_SIZE)
		copy.add_theme_constant_override("line_separation", -3)
		copy.add_theme_color_override("default_color", Color("e9eef0", 0.92))
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.visible = false
		add_child(copy)
		persona_copy_labels[shape_id] = copy


func _configure_icon_texture(image: TextureRect, display_size: Vector2) -> void:
	image.anchor_left = 0.5
	image.anchor_top = 0.5
	image.anchor_right = 0.5
	image.anchor_bottom = 0.5
	image.offset_left = -display_size.x * 0.5
	image.offset_top = -display_size.y * 0.5
	image.offset_right = display_size.x * 0.5
	image.offset_bottom = display_size.y * 0.5
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_heading() -> void:
	title_label = Label.new()
	title_label.name = "Title"
	title_label.position = Vector2(250, 24)
	title_label.size = Vector2(780, 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color("eef3f5"))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	remaining_label = Label.new()
	remaining_label.name = "RemainingPoints"
	remaining_label.position = Vector2(390, 72)
	remaining_label.size = Vector2(500, 34)
	remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	remaining_label.add_theme_font_size_override("font_size", 19)
	remaining_label.add_theme_color_override("font_color", Color("d8e0e5"))
	remaining_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(remaining_label)


func _build_enter_button() -> void:
	enter_button = Button.new()
	enter_button.name = "EnterAtriumButton"
	enter_button.position = Vector2(1024, 618)
	enter_button.size = Vector2(220, 58)
	enter_button.custom_minimum_size = enter_button.size
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	enter_button.add_theme_font_size_override("font_size", 20)
	enter_button.add_theme_color_override("font_color", Color("eef3f5"))
	enter_button.add_theme_color_override("font_hover_color", Color.WHITE)
	enter_button.add_theme_stylebox_override(
		"normal", _button_style(Color("203a4f", 0.88), Color("91aebd", 0.62), 1)
	)
	enter_button.add_theme_stylebox_override(
		"hover", _button_style(Color("2a4b63", 0.96), Color("c8e2ed", 0.90), 2)
	)
	enter_button.add_theme_stylebox_override(
		"pressed", _button_style(Color("172e40", 0.98), Color("dcecf2", 0.92), 2)
	)
	enter_button.pressed.connect(_on_enter_pressed)
	add_child(enter_button)


func _process(delta: float) -> void:
	node_pulse_phase = fmod(node_pulse_phase + delta * 0.72, 1.0)
	for shape_id in CardPropertySet.SHAPES:
		var next_strength := maxf(
			float(pulse_strengths.get(shape_id, 0.0)) - delta * 1.8,
			0.0,
		)
		pulse_strengths[shape_id] = next_strength
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050a18"))
	for shape_id in CardPropertySet.SHAPES:
		_draw_axis(shape_id)


func _draw_axis(shape_id: StringName) -> void:
	var direction := _axis_direction(shape_id)
	var axis_end := FIELD_CENTER + direction * AXIS_END_DISTANCE
	var base_color := Color("dce7ef", 0.14)
	draw_line(FIELD_CENTER, axis_end, base_color, 1.4, true)

	var shape_color := ShapeVisuals.color(shape_id)
	if hovered_shape_id == shape_id:
		draw_line(FIELD_CENTER, axis_end, Color(shape_color, 0.12), 10.0, true)
		draw_line(FIELD_CENTER, axis_end, Color(shape_color, 0.58), 2.0, true)
	var selected := selected_value(shape_id)
	var pulse := float(pulse_strengths.get(shape_id, 0.0))
	if selected > 0:
		var progress_end := _node_position(shape_id, selected)
		draw_line(
			FIELD_CENTER,
			progress_end,
			Color(shape_color, 0.08 + pulse * 0.08),
			14.0,
			true,
		)
		draw_line(
			FIELD_CENTER,
			progress_end,
			Color(shape_color, 0.30 + pulse * 0.22),
			6.0,
			true,
		)
		draw_line(FIELD_CENTER, progress_end, Color(shape_color, 0.95), 2.2, true)

	var synchronized_pulse := node_pulse_phase
	for value in range(1, MAX_VALUE + 1):
		_draw_axis_node(
			_node_position(shape_id, value),
			shape_color,
			value <= selected,
			synchronized_pulse,
		)


func _draw_axis_node(
	position_on_axis: Vector2,
	shape_color: Color,
	lit: bool,
	synchronized_pulse: float,
) -> void:
	var ring_radius := lerpf(
		NODE_PULSE_MIN_RADIUS,
		NODE_PULSE_MAX_RADIUS,
		synchronized_pulse,
	)
	var ring_alpha := pow(1.0 - synchronized_pulse, 1.35) * 0.48
	draw_circle(
		position_on_axis,
		ring_radius,
		Color("f4f7f7", ring_alpha),
		false,
		1.25,
		true,
	)
	if lit:
		draw_circle(
			position_on_axis,
			4.0,
			Color(shape_color, 0.16),
		)
		draw_circle(position_on_axis, NODE_DOT_RADIUS + 0.6, Color(shape_color, 0.98))
		return
	draw_circle(
		position_on_axis,
		NODE_DOT_RADIUS,
		Color("e7eef2", 0.58),
	)


func _axis_direction(shape_id: StringName) -> Vector2:
	return ((ICON_CENTERS[shape_id] as Vector2) - FIELD_CENTER).normalized()


func _node_position(shape_id: StringName, value: int) -> Vector2:
	var index := clampi(value, 1, MAX_VALUE) - 1
	return FIELD_CENTER + _axis_direction(shape_id) * float(NODE_DISTANCES[index])


func _on_node_pressed(shape_id: StringName, value: int) -> void:
	_pin_persona_copy(shape_id)
	var current := selected_value(shape_id)
	var requested := 0 if current == value else value
	var delta := requested - current
	if delta > remaining_points():
		_flash_remaining_points()
		return
	selected_values[shape_id] = requested
	pulse_strengths[shape_id] = 1.0 if requested > 0 else 0.0
	_refresh()
	queue_redraw()


func _on_icon_pressed(shape_id: StringName) -> void:
	_pin_persona_copy(shape_id)


func _pin_persona_copy(shape_id: StringName) -> void:
	pinned_shape_id = shape_id
	_refresh_persona_copy()


func _on_icon_hovered(shape_id: StringName) -> void:
	hovered_shape_id = shape_id
	for glow in icon_glow_layers.get(shape_id, []):
		(glow as TextureRect).visible = true
	_refresh_persona_copy()
	queue_redraw()


func _on_icon_unhovered(shape_id: StringName) -> void:
	if hovered_shape_id == shape_id:
		hovered_shape_id = &""
	for glow in icon_glow_layers.get(shape_id, []):
		(glow as TextureRect).visible = false
	_refresh_persona_copy()
	queue_redraw()


func _on_enter_pressed() -> void:
	if remaining_points() != 0:
		return
	allocation_confirmed.emit(selected_values.duplicate(true))


func _refresh() -> void:
	_refresh_text()
	_refresh_persona_copy()
	for shape_id in CardPropertySet.SHAPES:
		(value_labels[shape_id] as Label).text = str(selected_value(shape_id))
	enter_button.visible = remaining_points() == 0


func _refresh_text() -> void:
	if title_label == null:
		return
	title_label.text = TranslationServer.translate(&"opening.allocation.title")
	remaining_label.text = TranslationServer.translate(
		&"opening.allocation.remaining"
	) % remaining_points()
	enter_button.text = TranslationServer.translate(&"opening.allocation.enter")


func _refresh_persona_copy() -> void:
	var displayed_shape_id := hovered_shape_id if not hovered_shape_id.is_empty() else pinned_shape_id
	for shape_id in CardPropertySet.SHAPES:
		var copy := persona_copy_labels.get(shape_id) as RichTextLabel
		if copy == null:
			continue
		copy.visible = shape_id == displayed_shape_id
		if not copy.visible:
			continue
		var accent := ShapeVisuals.color(shape_id).to_html(false)
		var persona_name := TranslationServer.translate(
			PersonaCardCatalog.PERSONA_NAME_KEYS[shape_id]
		)
		var body := TranslationServer.translate(PERSONA_COPY_KEYS[shape_id]) % accent
		copy.text = (
			"[center][font_size=%d][color=#%s]%s[/color][/font_size]"
			+ "[/center]\n[center][font_size=%d]%s[/font_size][/center]"
		) % [PERSONA_TITLE_FONT_SIZE, accent, persona_name, PERSONA_BODY_FONT_SIZE, body]


func is_node_lit(shape_id: StringName, value: int) -> bool:
	return value > 0 and value <= selected_value(shape_id)


func _flash_remaining_points() -> void:
	if points_glow_tween != null and points_glow_tween.is_valid():
		points_glow_tween.kill()
	remaining_label.add_theme_color_override("font_color", Color("fff0f1"))
	remaining_label.add_theme_color_override("font_outline_color", Color("ff697c"))
	remaining_label.add_theme_constant_override("outline_size", 7)
	points_glow_tween = create_tween()
	points_glow_tween.tween_method(_set_points_glow_alpha, 1.0, 0.0, 1.0)
	points_glow_tween.finished.connect(_finish_points_glow)


func _set_points_glow_alpha(alpha: float) -> void:
	remaining_label.add_theme_color_override(
		"font_outline_color", Color("ff697c", alpha)
	)


func _finish_points_glow() -> void:
	remaining_label.add_theme_color_override("font_color", Color("d8e0e5"))
	remaining_label.add_theme_constant_override("outline_size", 0)
	points_glow_tween = null


func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
	_refresh_persona_copy()


static func _button_style(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color("79b8d4", 0.14)
	style.shadow_size = 8
	return style
