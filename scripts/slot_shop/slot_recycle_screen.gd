class_name SlotRecycleScreen
extends Control

signal leave_requested

@export var show_embedded_hand_bar := true

var commerce: SlotCommerceState
var money_label: Label
var staged_row: HBoxContainer
var counter_hint: Label
var cart_label: Label
var feedback_label: Label
var checkout_button: Button
var cancel_button: Button
var hand_bar: CardHandBar
var staged_views: Dictionary = {}
var refresh_queued := false


func setup(commerce_state: SlotCommerceState) -> void:
	if commerce != null and commerce.state_changed.is_connected(_queue_refresh):
		commerce.state_changed.disconnect(_queue_refresh)
	commerce = commerce_state
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
	if commerce != null and not commerce.state_changed.is_connected(_queue_refresh):
		commerce.state_changed.connect(_queue_refresh)
	if hand_bar != null:
		hand_bar.setup(commerce)


func _build_interface() -> void:
	var background := TextureRect.new()
	background.texture = load("res://pic/map.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.16, 0.3, 0.31, 0.54)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var night := ColorRect.new()
	night.color = Color(0.006, 0.02, 0.028, 0.88)
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
	column.add_child(top)
	var title := Label.new()
	title.name = "RecycleTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("d3e2da"))
	top.add_child(title)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color("efcf86"))
	top.add_child(money_label)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.pressed.connect(func() -> void:
		commerce.recycle_transaction.cancel()
		leave_requested.emit()
	)
	top.add_child(leave)

	var drop_zone := CardRecycleDropZone.new()
	drop_zone.name = "RecycleDropZone"
	drop_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drop_zone.card_dropped.connect(_on_card_dropped)
	drop_zone.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071419", 0.96), Color("65766e", 0.9))
	)
	column.add_child(drop_zone)
	var drop_column := VBoxContainer.new()
	drop_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_column.add_theme_constant_override("separation", 12)
	drop_zone.add_child(drop_column)
	counter_hint = Label.new()
	counter_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_hint.add_theme_font_size_override("font_size", 16)
	counter_hint.add_theme_color_override("font_color", Color("879c93"))
	drop_column.add_child(counter_hint)
	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drop_column.add_child(scroll)
	staged_row = HBoxContainer.new()
	staged_row.mouse_filter = Control.MOUSE_FILTER_PASS
	staged_row.add_theme_constant_override("separation", 10)
	scroll.add_child(staged_row)
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color("9bb3ad"))
	drop_column.add_child(feedback_label)

	var checkout_dock := PanelContainer.new()
	checkout_dock.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0a2022", 0.96), Color("657d70", 0.9))
	)
	column.add_child(checkout_dock)
	var cart_row := HBoxContainer.new()
	checkout_dock.add_child(cart_row)
	cart_label = Label.new()
	cart_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_row.add_child(cart_label)
	cancel_button = Button.new()
	cancel_button.pressed.connect(_on_cancel_pressed)
	cart_row.add_child(cancel_button)
	checkout_button = Button.new()
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
	if staged_row == null or commerce == null:
		return
	for child in staged_row.get_children():
		child.free()
	staged_views.clear()
	for card in commerce.recycle_transaction.staged_cards():
		var definition := SlotDemoCatalog.item_by_id(card.definition_id)
		var view := CardHandCard.new()
		view.setup(card, definition)
		staged_row.add_child(view)
		staged_views[card.instance_id] = view
	var count := commerce.recycle_transaction.cart_count()
	money_label.text = "¥%d" % commerce.wallet.money
	cart_label.text = TranslationServer.translate(&"slot.recycle.cart") % [
		count, commerce.recycle_transaction.cart_total()
	]
	counter_hint.text = TranslationServer.translate(&"slot.recycle.hint")
	counter_hint.visible = count == 0
	checkout_button.disabled = count == 0
	cancel_button.disabled = count == 0
	checkout_button.text = TranslationServer.translate(&"slot.recycle.checkout")
	cancel_button.text = TranslationServer.translate(&"slot.recycle.cancel")
	var title := find_child("RecycleTitle", true, false) as Label
	if title != null:
		title.text = TranslationServer.translate(&"slot.recycle.title")
	var leave := find_child("LeaveButton", true, false) as Button
	if leave != null:
		leave.text = TranslationServer.translate(&"shop.leave")
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


func set_highlight_rule(_rule: CardSlotRule) -> void:
	pass


func _on_card_dropped(card: CardItemState) -> void:
	var result := commerce.stage_recycle_card(card)
	feedback_label.text = TranslationServer.translate(
		&"slot.recycle.feedback.staged" if result.ok else &"slot.recycle.feedback.invalid"
	)


func _on_cancel_pressed() -> void:
	commerce.recycle_transaction.cancel()
	feedback_label.text = TranslationServer.translate(&"slot.recycle.feedback.returned")


func _on_checkout_pressed() -> void:
	var result := commerce.checkout_recycling()
	var feedback_key := &"slot.recycle.feedback.paid"
	if not result.ok:
		feedback_key = (
			&"slot.recycle.feedback.daily_risk"
			if result.reason == SlotCommerceState.RESULT_DAILY_RISK
			else &"slot.recycle.feedback.invalid"
		)
	feedback_label.text = TranslationServer.translate(feedback_key)


func _on_locale_changed(_locale: String) -> void:
	refresh()
