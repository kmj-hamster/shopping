class_name QuestShopScreen
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var store_id: StringName
var transaction: CardShopTransaction
var shelf_popup: PanelContainer
var shelf_grid: GridContainer
var title_label: Label
var owner_portrait: TextureRect
var navigation_column: VBoxContainer
var dialogue_panel: PanelContainer
var checkout_button: Button
var feedback_label: Label
var owner_name_label: Label
var owner_dialogue_label: Label
var shelf_nav_button: Button
var talk_nav_button: Button
var leave_nav_button: Button
var shelf_caption: Label
var page_row: HBoxContainer
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
	transaction = state.transaction_for_store(store_id)
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


func _build_interface() -> void:
	var background := TextureRect.new()
	background.texture = _store_background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var night_filter := ColorRect.new()
	night_filter.color = Color("031014", 0.28)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	owner_portrait = TextureRect.new()
	owner_portrait.name = "StoreOwnerPortrait"
	owner_portrait.texture = _owner_texture()
	owner_portrait.anchor_left = 0.46
	owner_portrait.anchor_top = 0.035
	owner_portrait.anchor_right = 0.80
	owner_portrait.anchor_bottom = 0.80
	owner_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(owner_portrait)

	navigation_column = VBoxContainer.new()
	navigation_column.name = "ShopNavigation"
	navigation_column.anchor_left = 0.835
	navigation_column.anchor_top = 0.34
	navigation_column.anchor_right = 0.975
	navigation_column.anchor_bottom = 0.76
	navigation_column.add_theme_constant_override("separation", 10)
	add_child(navigation_column)
	shelf_nav_button = Button.new()
	shelf_nav_button.name = "ShelfButton"
	shelf_nav_button.custom_minimum_size = Vector2(0, 54)
	shelf_nav_button.pressed.connect(_toggle_shelf_popup)
	navigation_column.add_child(shelf_nav_button)
	talk_nav_button = Button.new()
	talk_nav_button.name = "TalkButton"
	talk_nav_button.custom_minimum_size = Vector2(0, 54)
	talk_nav_button.pressed.connect(_on_owner_pressed)
	navigation_column.add_child(talk_nav_button)
	leave_nav_button = Button.new()
	leave_nav_button.name = "LeaveButton"
	leave_nav_button.custom_minimum_size = Vector2(0, 54)
	leave_nav_button.pressed.connect(leave_requested.emit)
	navigation_column.add_child(leave_nav_button)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "OwnerDialoguePanel"
	dialogue_panel.anchor_left = 0.405
	dialogue_panel.anchor_top = 0.735
	dialogue_panel.anchor_right = 0.815
	dialogue_panel.anchor_bottom = 0.97
	dialogue_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("050b0e", 0.92), Color("837659", 0.86))
	)
	add_child(dialogue_panel)
	var dialogue_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		dialogue_margin.add_theme_constant_override("margin_%s" % side, 10)
	dialogue_panel.add_child(dialogue_margin)
	var dialogue_row := HBoxContainer.new()
	dialogue_row.add_theme_constant_override("separation", 12)
	dialogue_margin.add_child(dialogue_row)
	var dialogue_text := VBoxContainer.new()
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_text.add_theme_constant_override("separation", 2)
	dialogue_row.add_child(dialogue_text)
	owner_name_label = Label.new()
	owner_name_label.add_theme_font_size_override("font_size", 14)
	owner_name_label.add_theme_color_override("font_color", Color("d9c582"))
	dialogue_text.add_child(owner_name_label)
	owner_dialogue_label = Label.new()
	owner_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owner_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_dialogue_label.add_theme_color_override("font_color", Color("c8d0ca"))
	dialogue_text.add_child(owner_dialogue_label)
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", Color("e0bd72"))
	dialogue_text.add_child(feedback_label)
	checkout_button = Button.new()
	checkout_button.custom_minimum_size = Vector2(120, 48)
	checkout_button.pressed.connect(_on_checkout_pressed)
	dialogue_row.add_child(checkout_button)

	_build_shelf_popup()


func _build_shelf_popup() -> void:
	shelf_popup = PanelContainer.new()
	shelf_popup.name = "ShelfPopup"
	shelf_popup.anchor_left = 0.035
	shelf_popup.anchor_top = 0.16
	shelf_popup.anchor_right = 0.39
	shelf_popup.anchor_bottom = 0.755
	shelf_popup.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071217", 0.98), Color("8c805d", 0.92))
	)
	add_child(shelf_popup)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	shelf_popup.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	shelf_caption = Label.new()
	shelf_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_caption.add_theme_font_size_override("font_size", 15)
	shelf_caption.add_theme_color_override("font_color", Color("d9c582"))
	header.add_child(shelf_caption)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(_toggle_shelf_popup)
	header.add_child(close_button)
	page_row = HBoxContainer.new()
	page_row.add_theme_constant_override("separation", 5)
	column.add_child(page_row)
	for page_index in range(1, CardShopTransaction.MAX_PAGE_COUNT + 1):
		var page_button := Button.new()
		page_button.custom_minimum_size = Vector2(44, 24)
		page_button.toggle_mode = true
		page_button.pressed.connect(_on_page_pressed.bind(page_index))
		page_row.add_child(page_button)
		page_buttons[page_index] = page_button
	shelf_grid = GridContainer.new()
	shelf_grid.columns = 2
	shelf_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_grid.add_theme_constant_override("h_separation", 7)
	shelf_grid.add_theme_constant_override("v_separation", 5)
	column.add_child(shelf_grid)
	shelf_popup.visible = false


func refresh() -> void:
	if state == null or shelf_grid == null or transaction == null:
		return
	var owner := QuestArcCatalog.owner_for_store(store_id)
	owner_name_label.text = TranslationServer.translate(owner.display_name_key) if owner != null else ""
	shelf_nav_button.text = TranslationServer.translate(&"quest.ui.shop.shelf")
	talk_nav_button.text = TranslationServer.translate(&"quest.ui.owner.talk")
	leave_nav_button.text = TranslationServer.translate(&"quest.ui.back")
	shelf_caption.text = TranslationServer.translate(&"quest.ui.shop.shelf")
	_refresh_owner_dialogue()
	_refresh_shelf()
	checkout_button.visible = transaction.cart_count() > 0
	checkout_button.text = TranslationServer.translate(&"quest.ui.shop.checkout") % transaction.cart_total()
	checkout_button.disabled = transaction.cart_count() == 0


func _refresh_shelf() -> void:
	current_page = clampi(current_page, 1, transaction.unlocked_page_count)
	for page_index in page_buttons:
		var page_button := page_buttons[page_index] as Button
		page_button.text = str(page_index)
		page_button.disabled = not transaction.is_page_unlocked(page_index)
		page_button.button_pressed = page_index == current_page
		page_button.tooltip_text = (
			"" if transaction.is_page_unlocked(page_index)
			else TranslationServer.translate(&"quest.ui.shop.page_locked")
		)
	for child in shelf_grid.get_children():
		child.free()
	shelf_buttons.clear()
	for slot in transaction.shelf_slots_for_page(current_page):
		var holder := VBoxContainer.new()
		holder.custom_minimum_size = Vector2(104, 70)
		holder.add_theme_constant_override("separation", 3)
		shelf_grid.add_child(holder)
		var button := Button.new()
		button.custom_minimum_size = Vector2(104, 52)
		if slot.is_empty():
			button.text = TranslationServer.translate(&"quest.ui.shop.sold")
			button.disabled = true
		else:
			var definition := QuestArcCatalog.item_by_id(slot.item_id)
			button.text = definition.localized_name()
			button.icon = definition.image
			button.expand_icon = true
			button.tooltip_text = definition.localized_description()
			button.button_pressed = transaction.is_selected(slot.slot_id)
			button.toggle_mode = true
			button.pressed.connect(_on_shelf_pressed.bind(slot.slot_id))
		holder.add_child(button)
		var price := Label.new()
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_color_override("font_color", Color("e1c373"))
		price.text = (
			"—" if slot.is_empty()
			else TranslationServer.translate(&"demo.ui.price") % transaction.price_for(
				QuestArcCatalog.item_by_id(slot.item_id)
			)
		)
		holder.add_child(price)
		shelf_buttons[slot.slot_id] = button
		_apply_shelf_highlight(button, slot)


func _toggle_shelf_popup() -> void:
	shelf_popup.visible = not shelf_popup.visible


func _on_shelf_pressed(slot_id: StringName) -> void:
	var slot := transaction.shelf_slot(slot_id)
	if slot != null and not slot.is_empty():
		var definition := QuestArcCatalog.item_by_id(slot.item_id)
		item_inspected.emit(definition)
		var owner := QuestArcCatalog.owner_for_store(store_id)
		if owner != null:
			owner_dialogue_override_key = owner.item_comment_key
			owner_dialogue_item_name = definition.localized_name()
	transaction.toggle_shelf_slot(slot_id)
	refresh()


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
	if transaction == null:
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
		),
	)


func _on_checkout_pressed() -> void:
	var result := state.checkout_store(store_id)
	feedback_label.text = TranslationServer.translate(
		&"quest.ui.shop.done" if result.ok
		else &"quest.ui.shop.no_money" if result.reason == CardShopTransaction.RESULT_INSUFFICIENT_FUNDS
		else &"quest.ui.shop.empty"
	)
	if result.ok:
		shelf_popup.visible = false
	refresh()


func _owner_texture() -> Texture2D:
	var paths := {
		&"flower": "res://resources/character/flower-head.png",
		&"record": "res://resources/character/phonograph-head.png",
	}
	var path := String(paths.get(store_id, ""))
	return load(path) as Texture2D if not path.is_empty() else null


func _store_background_texture() -> Texture2D:
	var paths := {
		&"flower": "res://resources/background/flowerstore.png",
		&"record": "res://resources/background/musicstore.png",
	}
	var path := String(paths.get(store_id, ""))
	return load(path) as Texture2D if not path.is_empty() else null


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
