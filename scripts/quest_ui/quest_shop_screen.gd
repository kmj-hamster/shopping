class_name QuestShopScreen
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var store_id: StringName
var transaction: CardShopTransaction
var shelf_grid: GridContainer
var title_label: Label
var money_label: Label
var checkout_button: Button
var feedback_label: Label
var owner_name_label: Label
var owner_button: Button
var owner_dialogue_label: Label
var talk_button: Button
var page_row: HBoxContainer
var recycle_zone: QuestRecycleDropZone
var recycle_row: HBoxContainer
var shelf_buttons: Dictionary = {}
var page_buttons: Dictionary = {}
var highlight_rule: CardSlotRule
var refresh_queued := false
var current_page := 1
var owner_dialogue_override_key: StringName
var owner_dialogue_item_name := ""


func setup(game_state: QuestGameState, selected_store_id: StringName) -> void:
	state = game_state
	store_id = selected_store_id
	transaction = state.transaction_for_store(store_id) if store_id != &"recycling" else null
	if is_node_ready():
		_bind_state()
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_bind_state()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func _bind_state() -> void:
	if state != null and not state.state_changed.is_connected(_queue_refresh):
		state.state_changed.connect(_queue_refresh)
	if transaction != null and not transaction.state_changed.is_connected(_queue_refresh):
		transaction.state_changed.connect(_queue_refresh)
	if state != null and state.recycle_transaction != null:
		if not state.recycle_transaction.state_changed.is_connected(_queue_refresh):
			state.recycle_transaction.state_changed.connect(_queue_refresh)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("071218")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var glow := ColorRect.new()
	glow.color = Color("24413d", 0.28)
	glow.position = Vector2(0, 88)
	glow.size = Vector2(820, 450)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var top := HBoxContainer.new()
	top.position = Vector2(26, 20)
	top.size = Vector2(1228, 52)
	top.add_theme_constant_override("separation", 16)
	add_child(top)
	var leave_button := Button.new()
	leave_button.custom_minimum_size = Vector2(86, 40)
	leave_button.text = TranslationServer.translate(&"quest.ui.back")
	leave_button.pressed.connect(leave_requested.emit)
	top.add_child(leave_button)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color("d8e7df"))
	top.add_child(title_label)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 20)
	money_label.add_theme_color_override("font_color", Color("e3c879"))
	top.add_child(money_label)

	var shelf_panel := PanelContainer.new()
	shelf_panel.position = Vector2(30, 92)
	shelf_panel.size = Vector2(760, 470)
	shelf_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("08171c", 0.94), Color("527774", 0.82))
	)
	add_child(shelf_panel)
	var shelf_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		shelf_margin.add_theme_constant_override("margin_%s" % side, 18)
	shelf_panel.add_child(shelf_margin)
	var shelf_column := VBoxContainer.new()
	shelf_column.add_theme_constant_override("separation", 14)
	shelf_margin.add_child(shelf_column)
	var shelf_header := HBoxContainer.new()
	shelf_column.add_child(shelf_header)
	var shelf_caption := Label.new()
	shelf_caption.text = TranslationServer.translate(&"quest.ui.shop.shelf")
	shelf_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_caption.add_theme_font_size_override("font_size", 16)
	shelf_caption.add_theme_color_override("font_color", Color("8eaaa5"))
	shelf_header.add_child(shelf_caption)
	checkout_button = Button.new()
	checkout_button.custom_minimum_size = Vector2(150, 42)
	checkout_button.pressed.connect(_on_checkout_pressed)
	shelf_header.add_child(checkout_button)
	page_row = HBoxContainer.new()
	page_row.add_theme_constant_override("separation", 8)
	shelf_column.add_child(page_row)
	for page_index in range(1, CardShopTransaction.MAX_PAGE_COUNT + 1):
		var page_button := Button.new()
		page_button.custom_minimum_size = Vector2(44, 32)
		page_button.toggle_mode = true
		page_button.pressed.connect(_on_page_pressed.bind(page_index))
		page_row.add_child(page_button)
		page_buttons[page_index] = page_button
	shelf_grid = GridContainer.new()
	shelf_grid.columns = 3
	shelf_grid.add_theme_constant_override("h_separation", 12)
	shelf_grid.add_theme_constant_override("v_separation", 12)
	shelf_column.add_child(shelf_grid)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(0, 44)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("d8bf7d"))
	shelf_column.add_child(feedback_label)

	var owner_panel := PanelContainer.new()
	owner_panel.position = Vector2(820, 92)
	owner_panel.size = Vector2(430, 470)
	owner_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071015", 0.95), Color("6c6250", 0.78))
	)
	add_child(owner_panel)
	var owner_column := VBoxContainer.new()
	owner_column.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_column.add_theme_constant_override("separation", 16)
	owner_panel.add_child(owner_column)
	owner_button = Button.new()
	owner_button.custom_minimum_size = Vector2(360, 225)
	owner_button.icon = _owner_texture()
	owner_button.expand_icon = true
	owner_button.pressed.connect(_on_owner_pressed)
	owner_column.add_child(owner_button)
	owner_name_label = Label.new()
	owner_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_name_label.add_theme_font_size_override("font_size", 19)
	owner_name_label.add_theme_color_override("font_color", Color("d7c99e"))
	owner_column.add_child(owner_name_label)
	owner_dialogue_label = Label.new()
	owner_dialogue_label.custom_minimum_size = Vector2(360, 82)
	owner_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_dialogue_label.add_theme_color_override("font_color", Color("aebbb4"))
	owner_column.add_child(owner_dialogue_label)
	talk_button = Button.new()
	talk_button.custom_minimum_size = Vector2(150, 38)
	talk_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	talk_button.pressed.connect(_on_owner_pressed)
	owner_column.add_child(talk_button)


func refresh() -> void:
	if state == null or shelf_grid == null:
		return
	var store := QuestArcCatalog.store_by_id(store_id)
	var owner := QuestArcCatalog.owner_for_store(store_id)
	title_label.text = str(TranslationServer.translate(store.display_name_key)) if store != null else ""
	owner_name_label.text = (
		TranslationServer.translate(owner.display_name_key)
		if owner != null
		else TranslationServer.translate(&"quest.ui.owner.none")
	)
	owner_button.visible = owner != null and state.owner_is_visible(store_id)
	owner_button.disabled = not owner_button.visible
	talk_button.visible = owner != null and owner_button.visible
	talk_button.text = TranslationServer.translate(&"quest.ui.owner.talk")
	_refresh_owner_dialogue()
	money_label.text = TranslationServer.translate(&"quest.ui.money") % state.wallet.money
	for child in shelf_grid.get_children():
		child.free()
	shelf_buttons.clear()
	if store_id == &"recycling":
		_build_recycle_contents()
	else:
		_build_retail_contents()


func _build_retail_contents() -> void:
	page_row.visible = true
	current_page = clampi(current_page, 1, transaction.unlocked_page_count)
	for page_index in page_buttons:
		var page_button := page_buttons[page_index] as Button
		page_button.text = str(page_index)
		page_button.disabled = not transaction.is_page_unlocked(page_index)
		page_button.button_pressed = page_index == current_page
		page_button.tooltip_text = (
			""
			if transaction.is_page_unlocked(page_index)
			else TranslationServer.translate(&"quest.ui.shop.page_locked")
		)
	for slot in transaction.shelf_slots_for_page(current_page):
		var button := Button.new()
		button.custom_minimum_size = Vector2(225, 150)
		if slot.is_empty():
			button.text = TranslationServer.translate(&"quest.ui.shop.sold")
			button.disabled = true
		else:
			var definition := QuestArcCatalog.item_by_id(slot.item_id)
			button.text = "%s\n◇ %d" % [definition.localized_name(), transaction.price_for(definition)]
			button.tooltip_text = definition.localized_description()
			button.button_pressed = transaction.is_selected(slot.slot_id)
			button.toggle_mode = true
			button.pressed.connect(_on_shelf_pressed.bind(slot.slot_id))
		shelf_grid.add_child(button)
		shelf_buttons[slot.slot_id] = button
		_apply_shelf_highlight(button, slot)
	checkout_button.text = TranslationServer.translate(&"quest.ui.shop.checkout") % [
		transaction.cart_count(), transaction.cart_total()
	]
	checkout_button.disabled = transaction.cart_count() == 0


func _build_recycle_contents() -> void:
	page_row.visible = false
	checkout_button.text = TranslationServer.translate(&"quest.ui.recycle.checkout") % [
		state.recycle_transaction.cart_count(), state.recycle_transaction.cart_total()
	]
	checkout_button.disabled = state.recycle_transaction.cart_count() == 0
	recycle_zone = QuestRecycleDropZone.new()
	recycle_zone.state = state
	recycle_zone.custom_minimum_size = Vector2(700, 260)
	recycle_zone.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0a1113", 0.9), Color("887d5d", 0.82))
	)
	shelf_grid.add_child(recycle_zone)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	recycle_zone.add_child(column)
	var hint := Label.new()
	hint.text = TranslationServer.translate(&"quest.ui.recycle.hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("9daaa4"))
	column.add_child(hint)
	recycle_row = HBoxContainer.new()
	recycle_row.add_theme_constant_override("separation", 8)
	column.add_child(recycle_row)
	for card in state.recycle_transaction.staged_cards():
		var definition := QuestArcCatalog.item_by_id(card.definition_id)
		var view := CardHandCard.new()
		view.setup(card, definition)
		view.inspect_requested.connect(item_inspected.emit)
		recycle_row.add_child(view)


func _on_shelf_pressed(slot_id: StringName) -> void:
	var slot := transaction.shelf_slot(slot_id)
	if slot != null and not slot.is_empty():
		var definition := QuestArcCatalog.item_by_id(slot.item_id)
		item_inspected.emit(definition)
		var owner := QuestArcCatalog.owner_for_store(store_id)
		if owner != null:
			owner_dialogue_override_key = owner.item_comment_key
			owner_dialogue_item_name = definition.localized_name()
			_refresh_owner_dialogue()
	transaction.toggle_shelf_slot(slot_id)


func _on_page_pressed(page_index: int) -> void:
	if transaction == null or not transaction.is_page_unlocked(page_index):
		return
	current_page = page_index
	refresh()


func _on_owner_pressed() -> void:
	var result := state.interact_with_store_owner(store_id)
	if not result.ok:
		return
	owner_dialogue_override_key = StringName(result.text_key)
	owner_dialogue_item_name = ""
	refresh()


func show_owner_result(text_key: StringName) -> void:
	owner_dialogue_override_key = text_key
	owner_dialogue_item_name = ""
	refresh()


func _refresh_owner_dialogue() -> void:
	if owner_dialogue_label == null:
		return
	var key := owner_dialogue_override_key
	if key.is_empty():
		key = state.owner_dialogue_key(store_id)
	if key.is_empty():
		owner_dialogue_label.text = ""
	elif owner_dialogue_item_name.is_empty():
		owner_dialogue_label.text = TranslationServer.translate(key)
	else:
		owner_dialogue_label.text = TranslationServer.translate(key) % owner_dialogue_item_name


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	if store_id == &"recycling" or transaction == null:
		return
	for slot_id in shelf_buttons:
		_apply_shelf_highlight(shelf_buttons[slot_id] as Button, transaction.shelf_slot(slot_id))


func _apply_shelf_highlight(button: Button, slot: ShelfSlotState) -> void:
	if button == null or slot == null or slot.is_empty():
		return
	var definition := QuestArcCatalog.item_by_id(slot.item_id)
	var matches: bool = (
		highlight_rule != null
		and definition != null
		and CardRuleEvaluator.evaluate(highlight_rule, definition).can_place
	)
	button.add_theme_stylebox_override(
		"normal",
		UiPalette.panel_style(
			Color("122326", 0.98) if matches else Color("0b1519", 0.96),
			Color("e4eee7") if matches else Color("627a76", 0.78),
		)
	)


func _on_checkout_pressed() -> void:
	var result := (
		state.checkout_recycle()
		if store_id == &"recycling"
		else state.checkout_store(store_id)
	)
	feedback_label.text = TranslationServer.translate(
		&"quest.ui.recycle.done" if result.ok and store_id == &"recycling"
		else &"quest.ui.shop.done" if result.ok
		else &"quest.ui.shop.no_money" if result.reason == CardShopTransaction.RESULT_INSUFFICIENT_FUNDS
		else &"quest.ui.shop.empty"
	)
	refresh()


func _owner_texture() -> Texture2D:
	if store_id == &"toy":
		return load("res://pic/balloon-head.png") as Texture2D
	if store_id == &"flower":
		return load("res://pic/flower-head.png") as Texture2D
	return null


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
