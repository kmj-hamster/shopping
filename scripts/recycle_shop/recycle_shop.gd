class_name RecycleShopScreen
extends Control

signal leave_requested
signal next_day_requested

var transaction: RecycleTransaction
var refresh_queued := false

var store_name_label: Label
var money_label: Label
var language_button: Button
var next_day_button: Button
var leave_button: Button
var drop_zone: RecycleDropZone
var counter_heading: Label
var counter_hint: Label
var cart_label: Label
var cancel_button: Button
var checkout_button: Button
var owner_title: Label
var feedback_label: Label
var feedback_key: StringName = &"recycle.feedback.ready"
var feedback_value := -1
var feedback_success := false


func _ready() -> void:
	transaction = GameState.recycle_transaction
	_build_interface()
	GameState.state_changed.connect(_queue_refresh)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_apply_locale_texts()
	_show_feedback_key(&"recycle.feedback.ready")
	_refresh_status()


func _build_interface() -> void:
	var mall_background := TextureRect.new()
	mall_background.name = "MallServiceCorridor"
	mall_background.texture = load("res://pic/map.png") as Texture2D
	mall_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mall_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mall_background.modulate = Color(0.18, 0.33, 0.35, 0.58)
	mall_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mall_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mall_background)

	var night_filter := ColorRect.new()
	night_filter.color = Color(0.008, 0.025, 0.036, 0.86)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	var service_light := ColorRect.new()
	service_light.color = Color("b5d5bd", 0.48)
	service_light.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	service_light.offset_bottom = 2.0
	service_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(service_light)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 52)
	top_bar.add_theme_constant_override("separation", 12)
	column.add_child(top_bar)
	var sign_copy := VBoxContainer.new()
	sign_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_copy.add_theme_constant_override("separation", -2)
	top_bar.add_child(sign_copy)
	store_name_label = Label.new()
	store_name_label.add_theme_font_size_override("font_size", 27)
	store_name_label.add_theme_color_override("font_color", Color("d5e3d8"))
	sign_copy.add_child(store_name_label)
	var clock_label := Label.new()
	clock_label.text = "22:03  ·  B1"
	clock_label.add_theme_font_size_override("font_size", 12)
	clock_label.add_theme_color_override("font_color", Color("829b92"))
	sign_copy.add_child(clock_label)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color("efcf86"))
	top_bar.add_child(money_label)
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(56, 38)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	top_bar.add_child(language_button)
	next_day_button = Button.new()
	next_day_button.custom_minimum_size = Vector2(82, 38)
	next_day_button.pressed.connect(_on_next_day_pressed)
	top_bar.add_child(next_day_button)
	leave_button = Button.new()
	leave_button.custom_minimum_size = Vector2(68, 38)
	leave_button.pressed.connect(_on_leave_pressed)
	top_bar.add_child(leave_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	column.add_child(content)
	var counter_column := VBoxContainer.new()
	counter_column.name = "RecycleCounterColumn"
	counter_column.custom_minimum_size = Vector2(430, 0)
	counter_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	counter_column.add_theme_constant_override("separation", 8)
	content.add_child(counter_column)

	drop_zone = RecycleDropZone.new()
	drop_zone.name = "RecycleCounter"
	drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	drop_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drop_zone.recycle_requested.connect(_on_recycle_requested)
	drop_zone.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071419", 0.95), Color("66796f", 0.82))
	)
	counter_column.add_child(drop_zone)
	var drop_column := VBoxContainer.new()
	drop_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_column.alignment = BoxContainer.ALIGNMENT_CENTER
	drop_column.add_theme_constant_override("separation", 18)
	drop_zone.add_child(drop_column)
	counter_heading = Label.new()
	counter_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_heading.add_theme_font_size_override("font_size", 18)
	counter_heading.add_theme_color_override("font_color", Color("a9beb4"))
	drop_column.add_child(counter_heading)
	var aperture := Label.new()
	aperture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aperture.text = "▱"
	aperture.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aperture.add_theme_font_size_override("font_size", 150)
	aperture.add_theme_color_override("font_color", Color("263c39", 0.86))
	drop_column.add_child(aperture)
	counter_hint = Label.new()
	counter_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter_hint.add_theme_font_size_override("font_size", 13)
	counter_hint.add_theme_color_override("font_color", Color("748d84"))
	drop_column.add_child(counter_hint)

	var checkout_dock := PanelContainer.new()
	checkout_dock.name = "RecycleCheckoutDock"
	checkout_dock.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0a2022", 0.96), Color("657d70", 0.9))
	)
	counter_column.add_child(checkout_dock)
	var cart_row := HBoxContainer.new()
	cart_row.add_theme_constant_override("separation", 8)
	checkout_dock.add_child(cart_row)
	cart_label = Label.new()
	cart_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_label.add_theme_font_size_override("font_size", 15)
	cart_row.add_child(cart_label)
	cancel_button = Button.new()
	cancel_button.custom_minimum_size = Vector2(74, 38)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cart_row.add_child(cancel_button)
	checkout_button = Button.new()
	checkout_button.custom_minimum_size = Vector2(92, 38)
	checkout_button.pressed.connect(_on_checkout_pressed)
	cart_row.add_child(checkout_button)

	var owner_frame := PanelContainer.new()
	owner_frame.name = "SilentWindow"
	owner_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("040b0e", 0.93), Color("2f4744", 0.76))
	)
	content.add_child(owner_frame)
	var owner_column := VBoxContainer.new()
	owner_column.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_column.add_theme_constant_override("separation", 16)
	owner_frame.add_child(owner_column)
	owner_title = Label.new()
	owner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_title.add_theme_font_size_override("font_size", 17)
	owner_title.add_theme_color_override("font_color", Color("869b92"))
	owner_column.add_child(owner_title)
	var recycler_mark := Label.new()
	recycler_mark.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recycler_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recycler_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycler_mark.text = "♲"
	recycler_mark.add_theme_font_size_override("font_size", 220)
	recycler_mark.add_theme_color_override("font_color", Color("17302f", 0.82))
	owner_column.add_child(recycler_mark)
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0, 48)
	feedback_label.add_theme_color_override("font_color", Color("91aaa0"))
	owner_column.add_child(feedback_label)


func _on_recycle_requested(piece: PuzzlePieceState) -> void:
	var result := GameState.stage_recycle_piece(piece)
	if result.ok:
		_show_feedback_key(&"recycle.feedback.staged")
	else:
		_show_feedback_key(_failure_key(result.reason))
	_queue_refresh()


func _on_checkout_pressed() -> void:
	var result := GameState.checkout_recycling()
	if result.ok:
		_show_feedback_key(&"recycle.feedback.paid", true, result.total)
	else:
		_show_feedback_key(_failure_key(result.reason))
	_queue_refresh()


func _on_cancel_pressed() -> void:
	if GameState.cancel_recycling() > 0:
		_show_feedback_key(&"recycle.feedback.returned")
	_queue_refresh()


func _on_leave_pressed() -> void:
	GameState.cancel_recycling()
	leave_requested.emit()


func _on_next_day_pressed() -> void:
	if not GameState.daily_goal.submitted:
		_show_feedback_key(&"shop.feedback.daily_required")
		return
	if transaction.cart_count() > 0:
		_show_feedback_key(&"recycle.feedback.pending")
		return
	next_day_requested.emit()


func _failure_key(reason: StringName) -> StringName:
	match reason:
		RecycleTransaction.RESULT_SPECIAL_ITEM:
			return &"recycle.feedback.special"
		RecycleTransaction.RESULT_NOT_OWNED:
			return &"recycle.feedback.not_owned"
		RecycleTransaction.RESULT_EMPTY:
			return &"recycle.feedback.empty"
		_:
			return &"recycle.feedback.invalid"


func _refresh_status() -> void:
	if transaction == null:
		return
	money_label.text = "¥%d" % transaction.wallet.money
	cart_label.text = TranslationServer.translate(&"recycle.summary") % [
		transaction.cart_count(), transaction.cart_total()
	]
	cancel_button.disabled = transaction.cart_count() == 0
	checkout_button.disabled = transaction.cart_count() == 0


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_run_queued_refresh")


func _run_queued_refresh() -> void:
	refresh_queued = false
	transaction = GameState.recycle_transaction
	_refresh_status()


func _show_feedback_key(
	message_key: StringName,
	success: bool = false,
	value: int = -1
) -> void:
	feedback_key = message_key
	feedback_success = success
	feedback_value = value
	_render_feedback()


func _render_feedback() -> void:
	var message := TranslationServer.translate(feedback_key)
	if feedback_value >= 0:
		message = message % feedback_value
	feedback_label.text = message
	feedback_label.add_theme_color_override(
		"font_color", Color("9bd3b8") if feedback_success else Color("91aaa0")
	)


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_texts()
	_refresh_status()
	_render_feedback()


func _apply_locale_texts() -> void:
	store_name_label.text = TranslationServer.translate(&"store.recycling")
	language_button.text = LocaleManager.switch_button_text()
	language_button.tooltip_text = TranslationServer.translate(&"ui.language.tooltip")
	next_day_button.text = TranslationServer.translate(&"map.next_day")
	leave_button.text = TranslationServer.translate(&"shop.leave")
	counter_heading.text = TranslationServer.translate(&"recycle.counter")
	counter_hint.text = TranslationServer.translate(&"recycle.hint")
	cancel_button.text = TranslationServer.translate(&"recycle.cancel")
	checkout_button.text = TranslationServer.translate(&"recycle.checkout")
	owner_title.text = TranslationServer.translate(&"recycle.window")
