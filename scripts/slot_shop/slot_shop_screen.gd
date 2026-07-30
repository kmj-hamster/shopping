class_name SlotShopScreen
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)

@export var store_id: StringName = SlotDemoCatalog.STORE_TOY
@export var show_embedded_hand_bar := true

var commerce: SlotCommerceState
var transaction: CardShopTransaction
var store_name_label: Label
var money_label: Label
var shelf_grid: GridContainer
var owner_name_label: Label
var relation_label: Label
var talk_button: Button
var cart_label: Label
var feedback_label: Label
var checkout_button: Button
var language_button: Button
var hand_bar: CardHandBar
var shelf_buttons: Dictionary = {}
var highlight_rule: CardSlotRule
var refresh_queued := false


func setup(commerce_state: SlotCommerceState, selected_store_id: StringName) -> void:
	if commerce != null and commerce.state_changed.is_connected(_queue_refresh):
		commerce.state_changed.disconnect(_queue_refresh)
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
	if commerce != null and not commerce.state_changed.is_connected(_queue_refresh):
		commerce.state_changed.connect(_queue_refresh)
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
	shelf_panel.name = "ShelfPanel"
	shelf_panel.custom_minimum_size = Vector2(720, 0)
	shelf_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("07181e", 0.95), Color("4e7474", 0.86))
	)
	body.add_child(shelf_panel)
	var shelf_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		shelf_margin.add_theme_constant_override("margin_%s" % side, 12)
	shelf_panel.add_child(shelf_margin)
	var shelf_column := VBoxContainer.new()
	shelf_column.add_theme_constant_override("separation", 10)
	shelf_margin.add_child(shelf_column)
	var checkout_row := HBoxContainer.new()
	checkout_row.name = "ShelfCheckoutRow"
	checkout_row.custom_minimum_size = Vector2(0, 40)
	checkout_row.add_theme_constant_override("separation", 8)
	shelf_column.add_child(checkout_row)
	cart_label = Label.new()
	cart_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_label.add_theme_font_size_override("font_size", 15)
	checkout_row.add_child(cart_label)
	checkout_button = Button.new()
	checkout_button.name = "ShelfCheckoutButton"
	checkout_button.custom_minimum_size = Vector2(112, 38)
	checkout_button.pressed.connect(_on_checkout_pressed)
	checkout_row.add_child(checkout_button)
	shelf_grid = GridContainer.new()
	shelf_grid.columns = 2
	shelf_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_grid.add_theme_constant_override("h_separation", 10)
	shelf_grid.add_theme_constant_override("v_separation", 10)
	shelf_column.add_child(shelf_grid)

	var owner_panel := PanelContainer.new()
	owner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("030b0f", 0.94), Color("2d494e", 0.78))
	)
	body.add_child(owner_panel)
	var owner_column := VBoxContainer.new()
	owner_column.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_column.add_theme_constant_override("separation", 9)
	owner_panel.add_child(owner_column)
	owner_name_label = Label.new()
	owner_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_name_label.add_theme_font_size_override("font_size", 20)
	owner_name_label.add_theme_color_override("font_color", Color("d6bd77"))
	owner_column.add_child(owner_name_label)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(300, 255)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _owner_texture()
	owner_column.add_child(portrait)
	relation_label = Label.new()
	relation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relation_label.add_theme_font_size_override("font_size", 13)
	relation_label.add_theme_color_override("font_color", Color("738d89"))
	owner_column.add_child(relation_label)
	talk_button = Button.new()
	talk_button.custom_minimum_size = Vector2(160, 36)
	talk_button.pressed.connect(_on_talk_pressed)
	owner_column.add_child(talk_button)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(0, 62)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("9bb3ad"))
	owner_column.add_child(feedback_label)

	if show_embedded_hand_bar:
		hand_bar = CardHandBar.new()
		hand_bar.name = "CardHandBar"
		hand_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		hand_bar.offset_left = 18
		hand_bar.offset_top = -146
		hand_bar.offset_right = -18
		hand_bar.offset_bottom = -10
		hand_bar.item_inspected.connect(item_inspected.emit)
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
				transaction.price_for(definition),
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
	checkout_button.disabled = transaction.cart_count() == 0
	store_name_label.text = TranslationServer.translate(SlotDemoCatalog.store_name_key(store_id))
	_refresh_owner_panel()
	language_button.text = LocaleManager.switch_button_text()
	var leave := find_child("LeaveButton", true, false) as Button
	if leave != null:
		leave.text = TranslationServer.translate(&"shop.leave")
	checkout_button.text = TranslationServer.translate(&"slot.shop.checkout")
	if feedback_label.text.is_empty():
		feedback_label.text = TranslationServer.translate(&"slot.shop.feedback.ready")
	if hand_bar != null:
		hand_bar.setup(commerce)


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	if is_inside_tree():
		refresh()


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	refresh()


func _apply_product_highlight(button: Button, definition: CardItemDefinition) -> void:
	button.modulate = Color.WHITE
	var matches: bool = (
		highlight_rule != null
		and CardRuleEvaluator.evaluate(highlight_rule, definition).can_place
	)
	button.set_meta(&"rule_match_highlighted", matches)
	if not matches:
		return
	var normal_style := button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	normal_style.border_color = Color("edf9f5")
	normal_style.set_border_width_all(2)
	normal_style.shadow_color = Color(0.9, 1.0, 0.97, 0.3)
	normal_style.shadow_size = 6
	button.add_theme_stylebox_override("normal", normal_style)
	var pulse := button.create_tween().set_loops()
	pulse.tween_property(
		button, "modulate", Color(1.24, 1.24, 1.24, 1.0), 0.58
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(
		button, "modulate", Color.WHITE, 0.58
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_shelf_pressed(slot_id: StringName) -> void:
	var slot := transaction.shelf_slot(slot_id)
	if slot != null and not slot.is_empty():
		var definition := SlotDemoCatalog.item_by_id(slot.item_id)
		if definition != null:
			item_inspected.emit(definition)
	transaction.toggle_shelf_slot(slot_id)
	feedback_label.text = TranslationServer.translate(&"slot.shop.feedback.selected")


func _on_checkout_pressed() -> void:
	var result := commerce.checkout_store(store_id)
	if result.ok:
		feedback_label.text = _feedback_with_unlocks(
			&"slot.shop.feedback.paid", result.get("owner_level_up_keys", [])
		)
	else:
		feedback_label.text = TranslationServer.translate(_failure_key(result.reason))
	refresh()


func _on_leave_pressed() -> void:
	transaction.cancel_cart()
	leave_requested.emit()


func _on_talk_pressed() -> void:
	var result := commerce.talk_to_store_owner(store_id)
	if not result.ok:
		feedback_label.text = TranslationServer.translate(&"slot.owner.talk.unavailable")
		return
	feedback_label.text = _feedback_with_unlocks(
		StringName(result.dialogue_key), result.level_up_keys
	)
	refresh()


func _refresh_owner_panel() -> void:
	var owner_id := SlotDemoCatalog.owner_id_for_store(store_id)
	var relationship: OwnerRelationshipState = commerce.relationship_state_for_owner(owner_id)
	var definition: OwnerRelationshipDefinition = SlotDemoCatalog.owner_by_id(owner_id)
	owner_name_label.text = TranslationServer.translate(
		SlotDemoCatalog.owner_name_key(owner_id)
	)
	if relationship != null and definition != null:
		relation_label.text = TranslationServer.translate(&"slot.owner.relation") % [
			TranslationServer.translate(definition.level_name_key(relationship.level)),
			relationship.experience,
			definition.next_threshold_for_level(relationship.level),
		]
	else:
		relation_label.text = ""
	var talked: bool = relationship != null and relationship.has_talked_today(commerce.day)
	talk_button.disabled = talked
	talk_button.text = TranslationServer.translate(
		&"slot.owner.talk.done" if talked else &"slot.owner.talk"
	)


func _feedback_with_unlocks(base_key: StringName, unlock_keys: Array) -> String:
	var lines := PackedStringArray([TranslationServer.translate(base_key)])
	for raw_key in unlock_keys:
		var key := StringName(raw_key)
		if not key.is_empty():
			lines.append(TranslationServer.translate(key))
	return "\n".join(lines)


func _failure_key(reason: StringName) -> StringName:
	if reason == CardShopTransaction.RESULT_INSUFFICIENT_FUNDS:
		return &"slot.shop.feedback.no_money"
	if reason == SlotCommerceState.RESULT_DAILY_RISK:
		return &"slot.shop.feedback.daily_risk"
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
