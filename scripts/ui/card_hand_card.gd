class_name CardHandCard
extends PanelContainer

var card: CardItemState
var definition: CardItemDefinition
var title_label: Label
var aspect_label: Label
var drag_enabled := true
var drag_in_progress := false
var drag_origin_location: CardItemState.Location = CardItemState.Location.HAND
var drag_origin_activity_id: StringName
var drag_origin_slot_id: StringName


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
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var margin := MarginContainer.new()
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
	add_theme_stylebox_override(
		"panel",
		UiPalette.panel_style(Color("10191d", 0.98), _border_color()),
	)


func _border_color() -> Color:
	if definition.has_property(CardPropertySet.ASPECT_LAMP):
		return Color("d5b66f")
	if definition.has_property(CardPropertySet.ASPECT_MIRROR):
		return Color("7ca9bd")
	if definition.has_property(CardPropertySet.ASPECT_CANDLE):
		return Color("9a82bb")
	return Color("bd8fa5")


func apply_rule_highlight(rule: CardSlotRule) -> void:
	if rule == null or definition == null:
		modulate = Color.WHITE
		return
	var evaluation := CardRuleEvaluator.evaluate(rule, definition)
	if evaluation.can_execute:
		modulate = Color.WHITE
	elif evaluation.can_place:
		modulate = Color(0.72, 0.78, 0.78, 0.9)
	else:
		modulate = Color(0.32, 0.38, 0.4, 0.62)


func _get_drag_data(at_position: Vector2) -> Variant:
	if card == null or definition == null or not drag_enabled:
		return null
	if card.location not in [
		CardItemState.Location.HAND,
		CardItemState.Location.ACTIVITY_SLOT,
		CardItemState.Location.RECYCLE,
	]:
		return null
	var preview := _build_drag_preview(at_position)
	set_drag_preview(preview)
	_begin_drag_visual()
	return {
		"kind": &"card_item",
		"card": card,
		"source": _drag_source(),
	}


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


func _begin_drag_visual() -> void:
	drag_in_progress = true
	drag_origin_location = card.location
	drag_origin_activity_id = card.activity_id
	drag_origin_slot_id = card.slot_id
	visible = false


func _end_drag_visual(drag_succeeded: bool) -> void:
	drag_in_progress = false
	if not drag_succeeded or _card_remained_at_drag_origin():
		visible = true


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
