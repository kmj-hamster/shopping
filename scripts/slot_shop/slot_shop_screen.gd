class_name SlotShopScreen
extends Control

signal leave_requested

@export var store_id: StringName = SlotDemoCatalog.STORE_TOY
@export var show_embedded_hand_bar := true

var commerce: SlotCommerceState
var transaction: CardShopTransaction
var store_name_label: Label
var money_label: Label
var shelf_grid: GridContainer
var cart_label: Label
var feedback_label: Label
var cancel_button: Button
var checkout_button: Button
var language_button: Button
var hand_bar: CardHandBar
var shelf_buttons: Dictionary = {}
var highlight_rule: CardSlotRule


func setup(commerce_state: SlotCommerceState, selected_store_id: StringName) -> void:
	commerce = commerce_state
	store_id = selected_store_id
	if is_node_ready():
		_bind_state()
		refresh()


func _ready() -> void:
	if commerce == null:
		commerce = SlotCommerceState.new(PlayerWallet.new(120))
	_build_interface()
	_bind_state()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func _bind_state() -> void:
	transaction = commerce.transaction_for_store(store_id) if commerce != null else null
	if commerce != null and not commerce.state_changed.is_connected(refresh):
		commerce.state_changed.connect(refresh)
	if hand_bar != null:
		hand_bar.setup(commerce)


func _build_interface() -> void:
	var background := TextureRect.new()
	background.texture = load("res://pic/map.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.2, 0.35, 0.37, 0.58)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var night := ColorRect.new()
	night.color = Color(0.008, 0.025, 0.036, 0.86)
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 158)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 46)
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	store_name_label = Label.new()
	store_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store_name_label.add_theme_font_size_override("font_size", 26)
	store_name_label.add_theme_color_override("font_color", Color("d8eee7"))
	top.add_child(store_name_label)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color("efcf86"))
	top.add_child(money_label)
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(56, 38)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	top.add_child(language_button)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.custom_minimum_size = Vector2(72, 38)
	leave.pressed.connect(_on_leave_pressed)
	top.add_child(leave)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var shelf_panel := PanelContainer.new()
	shelf_panel.custom_minimum_size = Vector2(720, 0)
	shelf_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("07181e", 0.95), Color("4e7474", 0.86))
	)
	body.add_child(shelf_panel)
	var shelf_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		shelf_margin.add_theme_constant_override("margin_%s" % side, 12)
	shelf_panel.add_child(shelf_margin)
	shelf_grid = GridContainer.new()
	shelf_grid.columns = 2
	shelf_grid.add_theme_constant_override("h_separation", 10)
	shelf_grid.add_theme_constant_override("v_separation", 10)
	shelf_margin.add_child(shelf_grid)

	var owner_panel := PanelContainer.new()
	owner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("030b0f", 0.94), Color("2d494e", 0.78))
	)
	body.add_child(owner_panel)
	var owner_column := VBoxContainer.new()
	owner_column.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_column.add_theme_constant_override("separation", 12)
	owner_panel.add_child(owner_column)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(320, 330)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _owner_texture()
	owner_column.add_child(portrait)
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("9bb3ad"))
	owner_column.add_child(feedback_label)

	var checkout_dock := PanelContainer.new()
	checkout_dock.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0a2022", 0.96), Color("657d70", 0.9))
	)
	column.add_child(checkout_dock)
	var cart_row := HBoxContainer.new()
	cart_row.add_theme_constant_override("separation", 8)
	checkout_dock.add_child(cart_row)
	cart_label = Label.new()
	cart_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_label.add_theme_font_size_override("font_size", 15)
	cart_row.add_child(cart_label)
	cancel_button = Button.new()
	cancel_button.custom_minimum_size = Vector2(82, 38)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cart_row.add_child(cancel_button)
	checkout_button = Button.new()
	checkout_button.custom_minimum_size = Vector2(100, 38)
	checkout_button.pressed.connect(_on_checkout_pressed)
	cart_row.add_child(checkout_button)

	if show_embedded_hand_bar:
		hand_bar = CardHandBar.new()
		hand_bar.name = "CardHandBar"
		hand_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		hand_bar.offset_left = 18
		hand_bar.offset_top = -146
		hand_bar.offset_right = -18
		hand_bar.offset_bottom = -10
		add_child(hand_bar)


func refresh() -> void:
	if shelf_grid == null or commerce == null:
		return
	transaction = commerce.transaction_for_store(store_id)
	for child in shelf_grid.get_children():
		child.free()
	shelf_buttons.clear()
	if transaction == null:
		return
	for slot in transaction.shelf_slots:
		var button := Button.new()
		button.custom_minimum_size = Vector2(330, 112)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_shelf_pressed.bind(slot.slot_id))
		var selected := transaction.is_selected(slot.slot_id)
		if slot.is_empty():
			button.text = TranslationServer.translate(&"slot.shop.empty_shelf")
			button.disabled = true
			button.modulate = Color(0.55, 0.62, 0.62, 0.58)
		else:
			var definition := SlotDemoCatalog.item_by_id(slot.item_id)
			button.text = "%s%s\n¥%d" % [
				"✓  " if selected else "",
				definition.localized_name(),
				definition.base_price,
			]
			button.add_theme_stylebox_override(
				"normal",
				UiPalette.panel_style(
					Color("18302e", 0.96) if selected else Color("0d2529", 0.92),
					Color("d3b66e") if selected else Color("4b7474"),
				),
			)
			_apply_product_highlight(button, definition)
		shelf_grid.add_child(button)
		shelf_buttons[slot.slot_id] = button
	money_label.text = "¥%d" % commerce.wallet.money
	cart_label.text = TranslationServer.translate(&"slot.shop.cart") % [
		transaction.cart_count(), transaction.cart_total()
	]
	cancel_button.disabled = transaction.cart_count() == 0
	checkout_button.disabled = transaction.cart_count() == 0
	store_name_label.text = TranslationServer.translate(SlotDemoCatalog.store_name_key(store_id))
	language_button.text = LocaleManager.switch_button_text()
	var leave := find_child("LeaveButton", true, false) as Button
	if leave != null:
		leave.text = TranslationServer.translate(&"shop.leave")
	cancel_button.text = TranslationServer.translate(&"slot.shop.cancel")
	checkout_button.text = TranslationServer.translate(&"slot.shop.checkout")
	if feedback_label.text.is_empty():
		feedback_label.text = TranslationServer.translate(&"slot.shop.feedback.ready")
	if hand_bar != null:
		hand_bar.setup(commerce)


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	refresh()


func _apply_product_highlight(button: Button, definition: CardItemDefinition) -> void:
	if highlight_rule == null:
		button.modulate = Color.WHITE
		return
	var evaluation := CardRuleEvaluator.evaluate(highlight_rule, definition)
	if evaluation.can_execute:
		button.modulate = Color.WHITE
	elif evaluation.can_place:
		button.modulate = Color(0.72, 0.78, 0.78, 0.9)
	else:
		button.modulate = Color(0.3, 0.36, 0.38, 0.58)


func _on_shelf_pressed(slot_id: StringName) -> void:
	transaction.toggle_shelf_slot(slot_id)
	feedback_label.text = TranslationServer.translate(&"slot.shop.feedback.selected")


func _on_checkout_pressed() -> void:
	var result := commerce.checkout_store(store_id)
	feedback_label.text = TranslationServer.translate(
		&"slot.shop.feedback.paid" if result.ok else _failure_key(result.reason)
	)
	refresh()


func _on_cancel_pressed() -> void:
	transaction.cancel_cart()
	feedback_label.text = TranslationServer.translate(&"slot.shop.feedback.cancelled")


func _on_leave_pressed() -> void:
	transaction.cancel_cart()
	leave_requested.emit()


func _failure_key(reason: StringName) -> StringName:
	if reason == CardShopTransaction.RESULT_INSUFFICIENT_FUNDS:
		return &"slot.shop.feedback.no_money"
	return &"slot.shop.feedback.empty"


func _on_locale_changed(_locale: String) -> void:
	feedback_label.text = ""
	refresh()


func _owner_texture() -> Texture2D:
	match store_id:
		SlotDemoCatalog.STORE_TOY:
			return load("res://pic/balloon-head.png") as Texture2D
		SlotDemoCatalog.STORE_FLOWER:
			return load("res://pic/flower-head.png") as Texture2D
	return null
