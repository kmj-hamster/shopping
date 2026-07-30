class_name CardHandBar
extends PanelContainer

var commerce: SlotCommerceState
var scroll: ScrollContainer
var card_row: HBoxContainer
var title_label: Label
var empty_label: Label
var card_views: Dictionary = {}


func setup(commerce_state: SlotCommerceState) -> void:
	if commerce != null and commerce.state_changed.is_connected(refresh):
		commerce.state_changed.disconnect(refresh)
	commerce = commerce_state
	if commerce != null and not commerce.state_changed.is_connected(refresh):
		commerce.state_changed.connect(refresh)
	if is_node_ready():
		refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("03070a", 0.96), Color("526a68", 0.88))
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("8ea7a2"))
	column.add_child(title_label)
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 98)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	scroll.add_child(card_row)
	empty_label = Label.new()
	empty_label.custom_minimum_size = Vector2(240, 82)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.add_theme_color_override("font_color", Color("60736f"))
	card_row.add_child(empty_label)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_refresh_locale()
	refresh()


func refresh() -> void:
	if card_row == null:
		return
	for child in card_row.get_children():
		child.free()
	card_views.clear()
	if commerce == null:
		return
	for card in commerce.inventory:
		if card.location != CardItemState.Location.HAND:
			continue
		var definition := SlotDemoCatalog.item_by_id(card.definition_id)
		if definition == null:
			continue
		var view := CardHandCard.new()
		view.setup(card, definition)
		card_row.add_child(view)
		card_views[card.instance_id] = view
	if card_views.is_empty():
		empty_label = Label.new()
		empty_label.custom_minimum_size = Vector2(240, 82)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("60736f"))
		empty_label.text = TranslationServer.translate(&"slot.hand.empty")
		card_row.add_child(empty_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if commerce == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	return data.get("kind") == &"card_item" and card != null \
		and card.location == CardItemState.Location.RECYCLE


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null:
		commerce.unstage_recycle_card(card)


func _on_locale_changed(_locale: String) -> void:
	_refresh_locale()
	refresh()


func _refresh_locale() -> void:
	if title_label != null:
		title_label.text = TranslationServer.translate(&"slot.hand.title")
