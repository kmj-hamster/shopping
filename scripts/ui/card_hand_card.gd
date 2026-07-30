class_name CardHandCard
extends PanelContainer

signal inspect_requested(definition: CardItemDefinition)
signal drag_started(card: CardItemState)
signal drag_finished(card: CardItemState, succeeded: bool)

var card: CardItemState
var definition: CardItemDefinition
var title_label: Label
var aspect_label: Label
var drag_enabled := true
var drag_in_progress := false
var drag_origin_location: CardItemState.Location = CardItemState.Location.HAND
var drag_origin_activity_id: StringName
var drag_origin_slot_id: StringName
var drag_origin_self_modulate := Color.WHITE
var drag_origin_mouse_filter := Control.MOUSE_FILTER_PASS
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
	custom_minimum_size = Vector2(150, 92)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color("d9e7df"))
	column.add_child(title_label)
	aspect_label = Label.new()
	aspect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect_label.add_theme_font_size_override("font_size", 12)
	aspect_label.add_theme_color_override("font_color", Color("a7b9b3"))
	column.add_child(aspect_label)
	_refresh()


func _refresh() -> void:
	if title_label == null or definition == null:
		return
	title_label.text = definition.localized_name()
	var aspects := PackedStringArray()
	for aspect in CardPropertySet.ASPECTS:
		var value := definition.property_value(aspect)
		if value > 0:
			aspects.append("%s %d" % [
				TranslationServer.translate(StringName("slot.aspect.%s" % aspect)),
				value,
			])
	aspect_label.text = " · ".join(aspects)
	_apply_card_style()


func _border_color() -> Color:
	if definition.has_property(CardPropertySet.ASPECT_LAMP):
		return Color("d5b66f")
	if definition.has_property(CardPropertySet.ASPECT_MIRROR):
		return Color("7ca9bd")
	if definition.has_property(CardPropertySet.ASPECT_CANDLE):
		return Color("9a82bb")
	return Color("bd8fa5")


func apply_rule_highlight(rule: CardSlotRule) -> void:
	rule_match_highlighted = (
		rule != null
		and definition != null
		and CardRuleEvaluator.evaluate(rule, definition).can_place
	)
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
	var style := UiPalette.panel_style(Color("10191d", 0.98), _border_color())
	if rule_match_highlighted:
		style.border_color = _border_color().lerp(Color.WHITE, 0.78)
		style.set_border_width_all(2)
		style.shadow_color = Color(0.9, 1.0, 0.97, 0.32)
		style.shadow_size = 6
	add_theme_stylebox_override("panel", style)


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
	var preview := _build_drag_preview(at_position)
	set_drag_preview(preview)
	_begin_drag_visual(at_position)
	return {
		"kind": &"card_item",
		"card": card,
		"source": _drag_source(),
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


func _build_drag_preview(grab_position: Vector2) -> CardHandCard:
	var preview := CardHandCard.new()
	preview.setup(card, definition, false)
	preview.custom_minimum_size = custom_minimum_size
	preview.size = size
	preview.position = -grab_position
	preview.modulate = modulate
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview


func _begin_drag_visual(grab_position: Vector2 = size * 0.5) -> void:
	drag_in_progress = true
	return_animation_active = false
	drag_origin_location = card.location
	drag_origin_activity_id = card.activity_id
	drag_origin_slot_id = card.slot_id
	drag_origin_self_modulate = self_modulate
	drag_origin_mouse_filter = mouse_filter
	drag_origin_global_position = get_global_rect().position
	drag_grab_position = grab_position
	var transparent := self_modulate
	transparent.a = 0.0
	self_modulate = transparent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_started.emit(card)


func _end_drag_visual(drag_succeeded: bool) -> void:
	drag_in_progress = false
	drag_finished.emit(card, drag_succeeded)
	if not drag_succeeded:
		_animate_return_to_origin()
	elif _card_remained_at_drag_origin():
		self_modulate = drag_origin_self_modulate
		mouse_filter = drag_origin_mouse_filter


func _animate_return_to_origin() -> void:
	if not is_inside_tree() or return_animation_seconds <= 0.0:
		_restore_after_drag()
		return
	return_animation_active = true
	var overlay := CanvasLayer.new()
	overlay.layer = 200
	get_tree().root.add_child(overlay)
	var returning_card := _build_drag_preview(Vector2.ZERO)
	returning_card.position = get_viewport().get_mouse_position() - drag_grab_position
	returning_card.modulate = Color.WHITE
	overlay.add_child(returning_card)
	var tween := returning_card.create_tween()
	tween.tween_property(
		returning_card,
		"position",
		drag_origin_global_position,
		return_animation_seconds,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish_return_animation.bind(overlay))


func _finish_return_animation(overlay: CanvasLayer) -> void:
	_restore_after_drag()
	if is_instance_valid(overlay):
		overlay.queue_free()


func _restore_after_drag() -> void:
	return_animation_active = false
	self_modulate = drag_origin_self_modulate
	mouse_filter = drag_origin_mouse_filter


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
