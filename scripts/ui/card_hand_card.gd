class_name CardHandCard
extends PanelContainer

signal inspect_requested(definition: CardItemDefinition)
signal drag_started(card: CardItemState)
signal drag_finished(card: CardItemState, succeeded: bool)

const CARD_SIZE := Vector2(120, 146)
const CARD_BACKGROUND: Texture2D = preload("res://resources/ui/shell/hand-card.png")
const FROSTED_DIALOGUE_SHADER: Shader = preload(
	"res://resources/shaders/frosted_dialogue.gdshader"
)
const PERSONA_PAPER_ALPHA := 0.10
const PERSONA_GLASS_ALPHA := 0.72

var card: CardItemState
var definition: CardItemDefinition
var title_label: Label
var title_host: Control
var card_background: TextureRect
var persona_glass: ColorRect
var persona_icon_background: Panel
var highlight_outline: Panel
var item_image: TextureRect
var value_label: Label
var drag_enabled := true
var drag_in_progress := false
var drag_origin_location: CardItemState.Location = CardItemState.Location.HAND
var drag_origin_activity_id: StringName
var drag_origin_slot_id: StringName
var drag_origin_self_modulate := Color.WHITE
var drag_origin_mouse_filter := Control.MOUSE_FILTER_PASS
var drag_origin_visible := true
var drag_origin_global_position := Vector2.ZERO
var drag_grab_position := Vector2.ZERO
var click_candidate := false
var rule_match_highlighted := false
var return_animation_seconds := 0.18
var return_animation_active := false
var highlight_tween: Tween


func setup(
	item_state: CardItemState,
	item_definition: CardItemDefinition,
	can_drag: bool = true,
) -> void:
	card = item_state
	definition = item_definition
	drag_enabled = can_drag
	if is_node_ready():
		_refresh()


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	persona_glass = ColorRect.new()
	persona_glass.name = "PersonaFrostedGlass"
	persona_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	persona_glass.color = Color.WHITE
	persona_glass.self_modulate = Color(1.0, 1.0, 1.0, PERSONA_GLASS_ALPHA)
	persona_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass_material := ShaderMaterial.new()
	glass_material.shader = FROSTED_DIALOGUE_SHADER
	glass_material.set_shader_parameter("blur_lod", 2.45)
	glass_material.set_shader_parameter("tint_strength", 0.20)
	glass_material.set_shader_parameter("brightness", 1.04)
	glass_material.set_shader_parameter("distortion_px", 0.75)
	glass_material.set_shader_parameter("dispersion_px", 0.60)
	glass_material.set_shader_parameter("corner_radius_px", 8.0)
	glass_material.set_shader_parameter("edge_depth_px", 8.0)
	persona_glass.material = glass_material
	persona_glass.resized.connect(_update_persona_glass_size)
	add_child(persona_glass)
	card_background = TextureRect.new()
	card_background.name = "CardPaperBackground"
	card_background.texture = CARD_BACKGROUND
	card_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_background.stretch_mode = TextureRect.STRETCH_SCALE
	card_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_background)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var image_host := Control.new()
	image_host.custom_minimum_size = Vector2(100, 94)
	image_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(image_host)
	persona_icon_background = Panel.new()
	persona_icon_background.name = "PersonaIconColor"
	persona_icon_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	persona_icon_background.offset_left = 5.0
	persona_icon_background.offset_top = 5.0
	persona_icon_background.offset_right = -5.0
	persona_icon_background.offset_bottom = -5.0
	persona_icon_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_host.add_child(persona_icon_background)
	item_image = TextureRect.new()
	item_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_host.add_child(item_image)
	value_label = Label.new()
	value_label.anchor_left = 1.0
	value_label.anchor_top = 1.0
	value_label.anchor_right = 1.0
	value_label.anchor_bottom = 1.0
	value_label.offset_left = -34.0
	value_label.offset_top = -34.0
	value_label.offset_right = -2.0
	value_label.offset_bottom = -3.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 23)
	value_label.add_theme_color_override("font_color", Color("f4ead1"))
	value_label.add_theme_color_override("font_outline_color", Color("102126"))
	value_label.add_theme_constant_override("outline_size", 4)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_host.add_child(value_label)
	# Keep localized names out of the VBox minimum-width calculation. The
	# fixed host owns layout; the label can ellipsize inside it in either locale.
	title_host = Control.new()
	title_host.custom_minimum_size = Vector2(100, 20)
	title_host.clip_contents = true
	column.add_child(title_host)
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", UiPalette.INK_COLOR)
	title_host.add_child(title_label)
	highlight_outline = Panel.new()
	highlight_outline.name = "CardRuleHighlight"
	highlight_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	highlight_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_outline.z_index = 2
	add_child(highlight_outline)
	_refresh()
	call_deferred("_update_persona_glass_size")


func _get_minimum_size() -> Vector2:
	# Item names must ellipsize inside the card instead of widening every
	# hand wrapper and task slot that contains this reusable component.
	return CARD_SIZE


func _refresh() -> void:
	if title_label == null or definition == null:
		return
	title_label.text = definition.localized_name()
	var is_persona_mask := definition.has_property(CardPropertySet.PROPERTY_PERSONA)
	var persona_id := _persona_id() if is_persona_mask else &""
	item_image.texture = (
		PersonaVisuals.symbol_texture(persona_id)
		if is_persona_mask
		else definition.image
	)
	persona_glass.visible = is_persona_mask
	persona_icon_background.visible = is_persona_mask
	card_background.self_modulate = (
		Color(1.0, 1.0, 1.0, PERSONA_PAPER_ALPHA) if is_persona_mask else Color.WHITE
	)
	item_image.offset_left = -16.0 if is_persona_mask else 0.0
	item_image.offset_right = 16.0 if is_persona_mask else 0.0
	_apply_persona_visuals(persona_id)
	value_label.visible = is_persona_mask
	title_host.custom_minimum_size.y = 32.0 if is_persona_mask else 20.0
	title_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART if is_persona_mask else TextServer.AUTOWRAP_OFF
	)
	title_label.max_lines_visible = 2 if is_persona_mask else 1
	title_label.add_theme_font_size_override("font_size", 11 if is_persona_mask else 13)
	title_label.add_theme_color_override(
		"font_color", Color("f4f7f2") if is_persona_mask else UiPalette.INK_COLOR
	)
	title_label.add_theme_color_override(
		"font_outline_color", Color("07151b", 0.92) if is_persona_mask else Color.TRANSPARENT
	)
	title_label.add_theme_constant_override("outline_size", 2 if is_persona_mask else 0)
	if is_persona_mask:
		var amount := 0
		for value_persona_id in CardPropertySet.PERSONAS:
			amount = maxi(amount, definition.property_value(value_persona_id))
		value_label.text = str(amount)
	_apply_card_style()


func _persona_id() -> StringName:
	if definition == null:
		return &""
	for persona_id in CardPropertySet.PERSONAS:
		if definition.has_property(persona_id):
			return persona_id
	return &""


func _apply_persona_visuals(persona_id: StringName) -> void:
	if persona_icon_background == null or persona_glass == null:
		return
	if persona_id.is_empty():
		return
	var persona_color := PersonaVisuals.color(persona_id)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = persona_color
	icon_style.border_color = Color(1.0, 1.0, 1.0, 0.26)
	icon_style.set_border_width_all(1)
	icon_style.corner_radius_top_left = 7
	icon_style.corner_radius_top_right = 7
	icon_style.corner_radius_bottom_left = 7
	icon_style.corner_radius_bottom_right = 7
	persona_icon_background.add_theme_stylebox_override("panel", icon_style)
	var glass_material := persona_glass.material as ShaderMaterial
	if glass_material != null:
		glass_material.set_shader_parameter(
			"glass_tint", Color("061218").lerp(persona_color, 0.16)
		)


func _update_persona_glass_size() -> void:
	if persona_glass == null or not (persona_glass.material is ShaderMaterial):
		return
	(persona_glass.material as ShaderMaterial).set_shader_parameter(
		"panel_size_px", persona_glass.size
	)


func _border_color() -> Color:
	if definition.has_property(CardPropertySet.PERSONA_NIGHTWALKER):
		return Color("d5b66f")
	if definition.has_property(CardPropertySet.PERSONA_MOURNER):
		return Color("7ca9bd")
	if definition.has_property(CardPropertySet.PERSONA_DREAMWALKER):
		return Color("9a82bb")
	return Color("bd8fa5")


func apply_match_highlight(highlighted: bool) -> void:
	rule_match_highlighted = highlighted
	if highlight_tween != null and highlight_tween.is_valid():
		highlight_tween.kill()
	modulate = Color.WHITE
	_apply_card_style()
	if not rule_match_highlighted:
		return
	highlight_tween = create_tween().set_loops()
	highlight_tween.tween_property(
		self, "modulate", Color(1.24, 1.24, 1.24, 1.0), 0.58
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	highlight_tween.tween_property(
		self, "modulate", Color.WHITE, 0.58
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_card_style() -> void:
	if highlight_outline == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	if rule_match_highlighted:
		style.border_color = _border_color().lerp(Color.WHITE, 0.78)
		style.set_border_width_all(2)
		style.shadow_color = Color(0.9, 1.0, 0.97, 0.32)
		style.shadow_size = 6
	highlight_outline.add_theme_stylebox_override("panel", style)


func _get_drag_data(at_position: Vector2) -> Variant:
	if card == null or definition == null or not drag_enabled:
		return null
	if card.location not in [
		CardItemState.Location.HAND,
		CardItemState.Location.ACTIVITY_SLOT,
		CardItemState.Location.RECYCLE,
	]:
		return null
	click_candidate = false
	var grab_position := at_position if at_position.is_finite() else size * 0.5
	var preview := _build_drag_preview(grab_position)
	set_drag_preview(preview)
	_begin_drag_visual(grab_position)
	return {
		"kind": &"card_item",
		"card": card,
		"source": _drag_source(),
		"grab_offset": grab_position,
	}


func _gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_button.pressed:
		click_candidate = true
	elif click_candidate:
		click_candidate = false
		if definition != null:
			inspect_requested.emit(definition)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and drag_in_progress:
		_end_drag_visual(is_drag_successful())


func _build_drag_preview(grab_position: Vector2) -> Control:
	# Viewport moves the preview root to the pointer on every mouse motion. Keep
	# the grab offset on a child so the rendered card begins exactly over the
	# source card instead of snapping its top-left corner to the pointer.
	var carrier := Control.new()
	carrier.name = "CardDragPreviewCarrier"
	carrier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carrier.z_index = 4096
	carrier.z_as_relative = false
	var preview := CardHandCard.new()
	preview.name = "CardDragPreview"
	preview.setup(card, definition, false)
	preview.custom_minimum_size = custom_minimum_size
	preview.size = size
	preview.position = -grab_position
	preview.modulate = modulate
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carrier.add_child(preview)
	return carrier


func _begin_drag_visual(grab_position: Vector2 = size * 0.5) -> void:
	drag_in_progress = true
	return_animation_active = false
	drag_origin_location = card.location
	drag_origin_activity_id = card.activity_id
	drag_origin_slot_id = card.slot_id
	drag_origin_self_modulate = self_modulate
	drag_origin_mouse_filter = mouse_filter
	drag_origin_visible = visible
	drag_origin_global_position = get_global_rect().position
	drag_grab_position = grab_position
	var transparent := self_modulate
	transparent.a = 0.0
	self_modulate = transparent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	drag_started.emit(card)


func _end_drag_visual(drag_succeeded: bool) -> void:
	drag_in_progress = false
	drag_finished.emit(card, drag_succeeded)
	if drag_succeeded and _card_remained_at_drag_origin():
		# A successful drop can still keep the card in the same container, most
		# notably when the hand reorders it. Keyed UI reconciliation deliberately
		# preserves this node, so it must undo the temporary drag hiding itself.
		_restore_after_drag()
	elif not drag_succeeded:
		_animate_return_to_origin()


func _animate_return_to_origin() -> void:
	if not is_inside_tree() or return_animation_seconds <= 0.0:
		_restore_after_drag()
		return
	return_animation_active = true
	var animation_host := _find_return_animation_host()
	if animation_host == null:
		_restore_after_drag()
		return
	animation_host.call(
		"play_card_return_animation",
		self,
		get_viewport().get_mouse_position() - drag_grab_position,
		drag_origin_global_position,
		return_animation_seconds,
	)


func _find_return_animation_host() -> Node:
	var candidate := get_parent()
	while candidate != null:
		if candidate.has_method("play_card_return_animation"):
			return candidate
		candidate = candidate.get_parent()
	return null


func _restore_after_drag() -> void:
	return_animation_active = false
	self_modulate = drag_origin_self_modulate
	mouse_filter = drag_origin_mouse_filter
	visible = drag_origin_visible


func _card_remained_at_drag_origin() -> bool:
	return (
		card != null
		and card.location == drag_origin_location
		and card.activity_id == drag_origin_activity_id
		and card.slot_id == drag_origin_slot_id
	)


func _drag_source() -> StringName:
	match card.location:
		CardItemState.Location.ACTIVITY_SLOT:
			return &"activity_slot"
		CardItemState.Location.RECYCLE:
			return &"recycle"
	return &"hand"
