extends Control

signal leave_requested
signal event_completed(task_id: StringName)
signal next_day_requested

var store_id: StringName = DemoCatalog.STORE_TOY
var transaction: ShopTransaction
var refresh_queued := false

var store_name_label: Label
var money_label: Label
var language_button: Button
var next_day_button: Button
var leave_button: Button
var shelf_drop_zone: ShopShelfDropZone
var shelf_list: VBoxContainer
var owner_title: Label
var owner_portrait: TextureRect
var owner_placeholder: Label
var feedback_label: Label
var cart_label: Label
var talk_button: Button
var cancel_button: Button
var checkout_button: Button
var next_day_scrim: ColorRect
var next_day_confirmation: PanelContainer
var next_day_confirmation_title: Label
var next_day_confirmation_body: Label
var next_day_confirm_button: Button
var next_day_cancel_button: Button


func _ready() -> void:
	transaction = GameState.transaction_for_store(store_id)
	_build_interface()
	GameState.state_changed.connect(_queue_refresh)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_apply_locale_texts()
	_show_feedback(TranslationServer.translate(&"shop.feedback.ready"))
	_refresh_all()


func _build_interface() -> void:
	var mall_background := TextureRect.new()
	mall_background.name = "MallAfterHours"
	mall_background.texture = load("res://pic/map.png") as Texture2D
	mall_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mall_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mall_background.modulate = Color(0.24, 0.42, 0.44, 0.68)
	mall_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mall_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mall_background)

	var night_filter := ColorRect.new()
	night_filter.color = Color(0.01, 0.035, 0.05, 0.79)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	var fluorescent_line := ColorRect.new()
	fluorescent_line.color = Color("7dd7ca", 0.72)
	fluorescent_line.custom_minimum_size = Vector2(1280, 2)
	fluorescent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fluorescent_line)

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
	store_name_label.add_theme_color_override("font_color", Color("d8eee7"))
	sign_copy.add_child(store_name_label)
	var clock_label := Label.new()
	clock_label.text = "21:47  ·  2F"
	clock_label.add_theme_font_size_override("font_size", 12)
	clock_label.add_theme_color_override("font_color", Color("7fa7a7"))
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
	var goods_column := VBoxContainer.new()
	goods_column.name = "GoodsColumn"
	goods_column.custom_minimum_size = Vector2(380, 0)
	goods_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	goods_column.add_theme_constant_override("separation", 8)
	content.add_child(goods_column)

	shelf_drop_zone = ShopShelfDropZone.new()
	shelf_drop_zone.name = "CounterShelf"
	shelf_drop_zone.setup(transaction)
	shelf_drop_zone.pending_purchase_return_requested.connect(_on_pending_purchase_return_requested)
	shelf_drop_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_drop_zone.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("081b21", 0.92), Color("41696c", 0.82))
	)
	goods_column.add_child(shelf_drop_zone)
	var shelf_column := VBoxContainer.new()
	shelf_column.mouse_filter = Control.MOUSE_FILTER_PASS
	shelf_column.add_theme_constant_override("separation", 8)
	shelf_drop_zone.add_child(shelf_column)
	var shelf_heading := Label.new()
	shelf_heading.name = "ShelfHeading"
	shelf_heading.add_theme_font_size_override("font_size", 17)
	shelf_heading.add_theme_color_override("font_color", Color("b8ceca"))
	shelf_column.add_child(shelf_heading)
	var shelf_scroll := ScrollContainer.new()
	shelf_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	shelf_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf_column.add_child(shelf_scroll)
	shelf_list = VBoxContainer.new()
	shelf_list.mouse_filter = Control.MOUSE_FILTER_PASS
	shelf_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_list.add_theme_constant_override("separation", 8)
	shelf_scroll.add_child(shelf_list)

	var cart_frame := PanelContainer.new()
	cart_frame.name = "CheckoutDock"
	cart_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0b2227", 0.94), Color("557d76", 0.88))
	)
	goods_column.add_child(cart_frame)
	var cart_row := HBoxContainer.new()
	cart_row.add_theme_constant_override("separation", 8)
	cart_frame.add_child(cart_row)
	cart_label = Label.new()
	cart_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_label.add_theme_font_size_override("font_size", 15)
	cart_row.add_child(cart_label)
	cancel_button = Button.new()
	cancel_button.custom_minimum_size = Vector2(68, 38)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cart_row.add_child(cancel_button)
	checkout_button = Button.new()
	checkout_button.custom_minimum_size = Vector2(92, 38)
	checkout_button.pressed.connect(_on_checkout_pressed)
	cart_row.add_child(checkout_button)

	var owner_frame := PanelContainer.new()
	owner_frame.name = "OwnerSide"
	owner_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("050e14", 0.91), Color("304e55", 0.8))
	)
	content.add_child(owner_frame)
	var owner_column := VBoxContainer.new()
	owner_column.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_column.add_theme_constant_override("separation", 12)
	owner_frame.add_child(owner_column)
	owner_title = Label.new()
	owner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_title.add_theme_font_size_override("font_size", 17)
	owner_title.add_theme_color_override("font_color", Color("91aaa6"))
	owner_column.add_child(owner_title)
	var portrait_center := CenterContainer.new()
	portrait_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owner_column.add_child(portrait_center)
	owner_portrait = TextureRect.new()
	owner_portrait.custom_minimum_size = Vector2(350, 420)
	owner_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_center.add_child(owner_portrait)
	owner_placeholder = Label.new()
	owner_placeholder.text = "◯"
	owner_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner_placeholder.add_theme_font_size_override("font_size", 180)
	owner_placeholder.add_theme_color_override("font_color", Color("20363a", 0.88))
	portrait_center.add_child(owner_placeholder)
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(0, 42)
	feedback_label.add_theme_color_override("font_color", Color("91aaa9"))
	owner_column.add_child(feedback_label)
	talk_button = Button.new()
	talk_button.custom_minimum_size = Vector2(120, 38)
	talk_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	talk_button.pressed.connect(_on_talk_pressed)
	owner_column.add_child(talk_button)

	_build_next_day_confirmation()


func _build_next_day_confirmation() -> void:
	next_day_scrim = ColorRect.new()
	next_day_scrim.color = Color(0.005, 0.02, 0.028, 0.72)
	next_day_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	next_day_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	next_day_scrim.visible = false
	add_child(next_day_scrim)
	next_day_confirmation = PanelContainer.new()
	next_day_confirmation.position = Vector2(472, 235)
	next_day_confirmation.size = Vector2(336, 210)
	next_day_confirmation.visible = false
	next_day_confirmation.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071a20", 0.99), Color("d4b66f", 0.94))
	)
	add_child(next_day_confirmation)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	next_day_confirmation.add_child(column)
	next_day_confirmation_title = Label.new()
	next_day_confirmation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_day_confirmation_title.add_theme_font_size_override("font_size", 22)
	next_day_confirmation_title.add_theme_color_override("font_color", Color("efd18a"))
	column.add_child(next_day_confirmation_title)
	next_day_confirmation_body = Label.new()
	next_day_confirmation_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_day_confirmation_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_day_confirmation_body.add_theme_color_override("font_color", Color("b8ceca"))
	column.add_child(next_day_confirmation_body)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	next_day_cancel_button = Button.new()
	next_day_cancel_button.custom_minimum_size = Vector2(112, 38)
	next_day_cancel_button.pressed.connect(_on_next_day_cancelled)
	actions.add_child(next_day_cancel_button)
	next_day_confirm_button = Button.new()
	next_day_confirm_button.custom_minimum_size = Vector2(112, 38)
	next_day_confirm_button.pressed.connect(_on_next_day_confirmed)
	actions.add_child(next_day_confirm_button)


func _refresh_all() -> void:
	transaction = GameState.transaction_for_store(store_id)
	shelf_drop_zone.setup(transaction)
	_refresh_shelf()
	_refresh_status()
	_refresh_owner_art()


func _refresh_shelf() -> void:
	for child in shelf_list.get_children():
		child.free()
	for definition in DemoCatalog.items_for_store(store_id):
		if not GameState.should_show_item(definition):
			continue
		var card := ShopProductCard.new()
		card.setup(
			definition,
			transaction.available_stock(definition.id),
			TaskPuzzlePopup.CELL_SIZE,
			shelf_drop_zone
		)
		shelf_list.add_child(card)


func _on_pending_purchase_return_requested(piece: PuzzlePieceState) -> void:
	if not transaction.remove_from_cart(piece):
		return
	GameState.notify_piece_layout_changed()
	_show_feedback(TranslationServer.translate(&"shop.feedback.returned"))


func _refresh_status() -> void:
	money_label.text = "¥%d" % transaction.money
	cart_label.text = TranslationServer.translate(&"shop.cart.summary") % [
		transaction.cart_count(), transaction.cart_total()
	]
	cancel_button.disabled = transaction.cart_count() == 0
	checkout_button.disabled = transaction.cart_count() == 0
	owner_title.text = TranslationServer.translate(DemoCatalog.store_name_key(store_id))


func _refresh_owner_art() -> void:
	var texture_path := ""
	match store_id:
		DemoCatalog.STORE_TOY:
			texture_path = "res://pic/balloon-head.png"
		DemoCatalog.STORE_FLOWER:
			texture_path = "res://pic/flower-head.png"
	owner_portrait.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	owner_portrait.visible = owner_portrait.texture != null
	owner_placeholder.visible = owner_portrait.texture == null


func _on_checkout_pressed() -> void:
	var result := GameState.checkout_store(store_id)
	if result.ok:
		_show_feedback(TranslationServer.translate(&"shop.feedback.paid"), true)
	else:
		_show_feedback(_failure_text(result.reason))
	_queue_refresh()


func _on_cancel_pressed() -> void:
	if GameState.cancel_store_cart(store_id) > 0:
		_show_feedback(TranslationServer.translate(&"shop.feedback.cancelled"))
	_queue_refresh()


func _on_leave_pressed() -> void:
	GameState.cancel_store_cart(store_id)
	leave_requested.emit()


func _on_next_day_pressed() -> void:
	if not GameState.daily_goal.submitted:
		_show_feedback(TranslationServer.translate(&"shop.feedback.daily_required"))
		return
	if GameState.has_organizer_pieces():
		_show_feedback(TranslationServer.translate(&"task.organizer.must_empty"))
		return
	if transaction.cart_count() > 0:
		next_day_scrim.visible = true
		next_day_confirmation.visible = true
	else:
		next_day_requested.emit()


func _on_next_day_confirmed() -> void:
	next_day_scrim.visible = false
	next_day_confirmation.visible = false
	GameState.cancel_all_carts()
	next_day_requested.emit()


func _on_next_day_cancelled() -> void:
	next_day_scrim.visible = false
	next_day_confirmation.visible = false


func _on_talk_pressed() -> void:
	if GameState.world_stage >= GameState.TASK_ORDER.size():
		_show_feedback(TranslationServer.translate(&"shop.feedback.owner_after"), true)
		return
	var task_id: StringName = GameState.TASK_ORDER[GameState.world_stage]
	var task := DemoCatalog.task_by_id(task_id)
	if task == null or task.submit_store_id != store_id:
		_show_feedback(TranslationServer.translate(&"shop.feedback.owner_quiet"))
		return
	if not GameState.is_task_unlocked(task_id):
		var unlock_result := GameState.talk_to_owner(store_id)
		if unlock_result.ok:
			_show_feedback(
				TranslationServer.translate(StringName("shop.feedback.unlocked_%s" % task_id)),
				true
			)
		else:
			_show_feedback(TranslationServer.translate(&"shop.feedback.owner_quiet"))
		_queue_refresh()
		return
	var result := GameState.submit_task(task_id)
	if result.ok:
		_show_feedback(
			TranslationServer.translate(StringName("shop.feedback.submitted_%s" % task_id)), true
		)
		event_completed.emit(task_id)
	else:
		_show_feedback(TranslationServer.translate(
			&"task.checkout_first"
			if result.reason == GameState.RESULT_PENDING_PURCHASE
			else &"shop.feedback.not_ready"
		))
	_queue_refresh()


func _failure_text(reason: StringName) -> String:
	match reason:
		ShopTransaction.RESULT_INSUFFICIENT_FUNDS:
			return TranslationServer.translate(&"shop.feedback.no_money")
		ShopTransaction.RESULT_OUT_OF_STOCK:
			return TranslationServer.translate(&"shop.feedback.no_stock")
		ShopTransaction.RESULT_EMPTY:
			return TranslationServer.translate(&"shop.feedback.empty_cart")
		ShopTransaction.RESULT_UNPLACED:
			return TranslationServer.translate(&"shop.feedback.unplaced")
		ShopTransaction.RESULT_ORGANIZER_NOT_EMPTY:
			return TranslationServer.translate(&"task.organizer.must_empty")
		GameState.RESULT_INVALID_SPECIAL_TASK:
			return TranslationServer.translate(&"shop.feedback.special_task")
		&"store_closed":
			return TranslationServer.translate(&"shop.feedback.closed")
		_:
			return TranslationServer.translate(&"shop.feedback.failed")


func _show_feedback(message: String, success: bool = false) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override(
		"font_color", Color("9bd3c3") if success else Color("91aaa9")
	)


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_run_queued_refresh")


func _run_queued_refresh() -> void:
	refresh_queued = false
	_refresh_all()


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_texts()
	_refresh_all()


func _apply_locale_texts() -> void:
	store_name_label.text = TranslationServer.translate(DemoCatalog.store_name_key(store_id))
	language_button.text = LocaleManager.switch_button_text()
	language_button.tooltip_text = TranslationServer.translate(&"ui.language.tooltip")
	leave_button.text = TranslationServer.translate(&"shop.leave")
	next_day_button.text = TranslationServer.translate(&"map.next_day")
	var shelf_heading := find_child("ShelfHeading", true, false) as Label
	if shelf_heading != null:
		shelf_heading.text = TranslationServer.translate(&"shop.tab.goods")
	talk_button.text = TranslationServer.translate(&"shop.talk")
	cancel_button.text = TranslationServer.translate(&"shop.cancel")
	checkout_button.text = TranslationServer.translate(&"shop.checkout")
	next_day_confirmation_title.text = TranslationServer.translate(&"shop.next_day.title")
	next_day_confirmation_body.text = TranslationServer.translate(&"shop.next_day.confirm")
	next_day_confirm_button.text = TranslationServer.translate(&"shop.next_day.ok")
	next_day_cancel_button.text = TranslationServer.translate(&"shop.next_day.cancel")
