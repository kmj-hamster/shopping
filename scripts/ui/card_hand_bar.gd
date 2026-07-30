class_name CardHandBar
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

var commerce: SlotCommerceState
var activity_state: SlotActivityState
var highlight_rule: CardSlotRule
var scroll: ScrollContainer
var card_row: HBoxContainer
var title_label: Label
var empty_label: Label
var card_views: Dictionary = {}
var refresh_queued := false


func setup(
	commerce_state: SlotCommerceState,
	selected_activity_state: SlotActivityState = null,
) -> void:
	if commerce != null and commerce.state_changed.is_connected(_queue_refresh):
		commerce.state_changed.disconnect(_queue_refresh)
	commerce = commerce_state
	activity_state = (
		selected_activity_state
		if selected_activity_state != null
		else commerce.activity_state if commerce != null else null
	)
	if commerce != null and not commerce.state_changed.is_connected(_queue_refresh):
		commerce.state_changed.connect(_queue_refresh)
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
		view.inspect_requested.connect(item_inspected.emit)
		card_row.add_child(view)
		view.apply_rule_highlight(highlight_rule)
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
	return (
		data.get("kind") == &"card_item"
		and card != null
		and card.location in [
			CardItemState.Location.HAND,
			CardItemState.Location.ACTIVITY_SLOT,
			CardItemState.Location.RECYCLE,
		]
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card == null:
		return
	var target_index := _hand_insertion_index(at_position, card)
	if card.location == CardItemState.Location.ACTIVITY_SLOT and activity_state != null:
		if activity_state.return_card_to_hand(card):
			commerce.reorder_hand_card(card, target_index)
	elif card.location == CardItemState.Location.RECYCLE:
		if commerce.unstage_recycle_card(card):
			commerce.reorder_hand_card(card, target_index)
	elif card.location == CardItemState.Location.HAND:
		commerce.reorder_hand_card(card, target_index)


func _hand_insertion_index(at_position: Vector2, dragged_card: CardItemState) -> int:
	var pointer_x := get_global_rect().position.x + at_position.x
	var insertion_index := 0
	for child in card_row.get_children():
		var view := child as CardHandCard
		if view == null or view.card == dragged_card:
			continue
		if pointer_x < view.get_global_rect().get_center().x:
			return insertion_index
		insertion_index += 1
	return insertion_index


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	for view in card_views.values():
		(view as CardHandCard).apply_rule_highlight(rule)


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh_locale()
	refresh()


func _refresh_locale() -> void:
	if title_label != null:
		title_label.text = TranslationServer.translate(&"slot.hand.title")
