class_name CardHandCard
extends PanelContainer

var card: CardItemState
var definition: CardItemDefinition
var title_label: Label
var aspect_label: Label


func setup(item_state: CardItemState, item_definition: CardItemDefinition) -> void:
	card = item_state
	definition = item_definition
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


func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null or definition == null:
		return null
	if card.location not in [CardItemState.Location.HAND, CardItemState.Location.RECYCLE]:
		return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(150, 72)
	preview.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("10191d", 0.98), _border_color())
	)
	var label := Label.new()
	label.text = definition.localized_name()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(label)
	set_drag_preview(preview)
	return {
		"kind": &"card_item",
		"card": card,
		"source": &"recycle" if card.location == CardItemState.Location.RECYCLE else &"hand",
	}
