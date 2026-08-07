class_name QuestHandBar
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var highlight_rule: CardSlotRule
var card_row: HBoxContainer
var empty_label: Label
var title_label: Label
var card_views: Dictionary = {}
var temporarily_hidden_card_ids: Dictionary = {}
var refresh_queued := false


func setup(game_state: QuestGameState) -> void:
	if state != null and state.state_changed.is_connected(_queue_refresh):
		state.state_changed.disconnect(_queue_refresh)
	state = game_state
	if state != null and not state.state_changed.is_connected(_queue_refresh):
		state.state_changed.connect(_queue_refresh)
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("020609", 0.94), Color("4f6968", 0.76))
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color("8ca49f"))
	title_label.visible = false
	column.add_child(title_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 132)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	scroll.add_child(card_row)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_refresh_locale()
	refresh()


func refresh() -> void:
	if card_row == null:
		return
	for child in card_row.get_children():
		child.free()
	card_views.clear()
	if state == null:
		return
	for card in state.inventory:
		if card.location != CardItemState.Location.HAND:
			continue
		if temporarily_hidden_card_ids.has(card.instance_id):
			continue
		var definition := QuestArcCatalog.item_by_id(card.definition_id)
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
		empty_label.custom_minimum_size = Vector2(260, 126)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("60736f"))
		empty_label.text = TranslationServer.translate(&"quest.ui.hand.empty")
		card_row.add_child(empty_label)


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	for view in card_views.values():
		(view as CardHandCard).apply_rule_highlight(rule)


func set_card_temporarily_hidden(card: CardItemState, hidden: bool) -> void:
	if card == null:
		return
	if hidden:
		temporarily_hidden_card_ids[card.instance_id] = true
	else:
		temporarily_hidden_card_ids.erase(card.instance_id)
	refresh()


func clear_temporarily_hidden_cards() -> void:
	if temporarily_hidden_card_ids.is_empty():
		return
	temporarily_hidden_card_ids.clear()
	refresh()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	return data.get("kind") == &"card_item" and card != null and card in state.inventory


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card == null:
		return
	var target_index := _hand_insertion_index(at_position, card)
	if card.location == CardItemState.Location.ACTIVITY_SLOT:
		state.return_card_to_hand(card)
	elif card.location == CardItemState.Location.RECYCLE:
		state.unstage_recycle_card(card)
	state.reorder_hand_card(card, target_index)


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
		title_label.text = TranslationServer.translate(&"quest.ui.hand.title")
