extends Control

var transaction: ShopTransaction
var pieces: Array[PuzzlePieceState] = []
var task: TaskDefinition
var refresh_queued := false

var store_name_label: Label
var clock_label: Label
var money_label: Label
var language_button: Button
var leave_button: Button
var shelf_tabs: TabBar
var shelf_list: VBoxContainer
var task_title_label: Label
var requirement_label: Label
var puzzle_board: PuzzleBoard
var coverage_label: Label
var attribute_labels: Dictionary = {}
var feedback_label: Label
var cart_label: Label
var cancel_button: Button
var checkout_button: Button


func _ready() -> void:
	_create_model()
	_build_interface()
	puzzle_board.set_context(task, pieces)
	puzzle_board.return_removed_to_inventory = true
	puzzle_board.state_changed.connect(_queue_refresh)
	puzzle_board.interaction_message.connect(_show_feedback)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_apply_locale_texts()
	_show_feedback(TranslationServer.translate(&"shop.feedback.ready"))
	_refresh_all()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	var viewport := get_viewport()
	if not viewport.gui_is_dragging():
		return
	var data: Variant = viewport.gui_get_drag_data()
	if not _rotate_drag_data(data):
		return
	viewport.set_input_as_handled()


func _rotate_drag_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return false
	var candidate := data.get("candidate") as PuzzlePieceState
	if candidate == null:
		return false
	var current_anchor: Vector2i = data.get("grab_offset", Vector2i.ZERO)
	var rotated_anchor := PolyominoGeometry.rotate_anchor_clockwise(
		candidate.local_cells(), current_anchor
	)
	candidate.rotation_steps = posmod(candidate.rotation_steps + 1, 4)
	data["grab_offset"] = rotated_anchor
	var preview := data.get("preview") as PieceDragPreview
	if preview != null:
		preview.refresh_drag_geometry(rotated_anchor)
	if puzzle_board != null:
		puzzle_board.refresh_drag_state(data)
	return true


func _create_model() -> void:
	task = DemoCatalog.task_by_id(&"teddy")
	var uid := 1
	for item_id in [&"book_bookmark", &"fast_straw"]:
		var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))
		pieces.append(piece)
		uid += 1
	transaction = ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		100,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY),
		pieces
	)


func _build_interface() -> void:
	var mall_background := TextureRect.new()
	mall_background.name = "MallAfterHours"
	mall_background.texture = load("res://pic/map.png") as Texture2D
	mall_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mall_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mall_background.modulate = Color(0.26, 0.46, 0.48, 0.68)
	mall_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mall_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mall_background)

	var night_filter := ColorRect.new()
	night_filter.name = "NightFilter"
	night_filter.color = Color(0.015, 0.055, 0.075, 0.76)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	var fluorescent_line := ColorRect.new()
	fluorescent_line.color = Color("7dd7ca", 0.72)
	fluorescent_line.position = Vector2(0, 0)
	fluorescent_line.custom_minimum_size = Vector2(1280, 2)
	fluorescent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fluorescent_line)

	var margin := MarginContainer.new()
	margin.name = "ShopLayout"
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
	top_bar.name = "StoreSign"
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
	clock_label = Label.new()
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
	leave_button = Button.new()
	leave_button.custom_minimum_size = Vector2(68, 38)
	leave_button.pressed.connect(_on_leave_pressed)
	top_bar.add_child(leave_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	column.add_child(content)

	var shelf_frame := PanelContainer.new()
	shelf_frame.name = "CounterShelf"
	shelf_frame.custom_minimum_size = Vector2(340, 0)
	shelf_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("081b21", 0.91), Color("41696c", 0.82))
	)
	content.add_child(shelf_frame)
	var shelf_column := VBoxContainer.new()
	shelf_column.add_theme_constant_override("separation", 8)
	shelf_frame.add_child(shelf_column)
	shelf_tabs = TabBar.new()
	shelf_tabs.name = "ShelfTabs"
	shelf_tabs.add_tab("")
	shelf_tabs.add_tab("")
	shelf_tabs.tab_changed.connect(func(_tab: int) -> void: _queue_refresh())
	shelf_column.add_child(shelf_tabs)
	var shelf_scroll := ScrollContainer.new()
	shelf_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf_column.add_child(shelf_scroll)
	shelf_list = VBoxContainer.new()
	shelf_list.name = "ShelfItems"
	shelf_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_list.add_theme_constant_override("separation", 8)
	shelf_scroll.add_child(shelf_list)

	var work_frame := PanelContainer.new()
	work_frame.name = "QuietCounter"
	work_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071820", 0.9), Color("355a62", 0.84))
	)
	content.add_child(work_frame)
	var workspace := VBoxContainer.new()
	workspace.add_theme_constant_override("separation", 9)
	work_frame.add_child(workspace)
	var task_header := HBoxContainer.new()
	workspace.add_child(task_header)
	task_title_label = Label.new()
	task_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_title_label.add_theme_font_size_override("font_size", 20)
	task_header.add_child(task_title_label)
	requirement_label = Label.new()
	requirement_label.add_theme_font_size_override("font_size", 14)
	requirement_label.add_theme_color_override("font_color", UiPalette.attribute_color(ItemDefinition.ATTRIBUTE_MIRROR))
	task_header.add_child(requirement_label)

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(board_center)
	puzzle_board = PuzzleBoard.new()
	puzzle_board.name = "PuzzleBoard"
	board_center.add_child(puzzle_board)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 14)
	workspace.add_child(stats)
	coverage_label = Label.new()
	coverage_label.add_theme_color_override("font_color", Color("aec7c7"))
	stats.add_child(coverage_label)
	for attribute in [
		ItemDefinition.ATTRIBUTE_LAMP,
		ItemDefinition.ATTRIBUTE_MIRROR,
		ItemDefinition.ATTRIBUTE_FLOWER,
		ItemDefinition.ATTRIBUTE_FOG,
	]:
		var label := Label.new()
		label.add_theme_color_override("font_color", UiPalette.attribute_color(attribute))
		attribute_labels[attribute] = label
		stats.add_child(label)
	feedback_label = Label.new()
	feedback_label.name = "Whisper"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color("91aaa9"))
	workspace.add_child(feedback_label)

	var cart_frame := PanelContainer.new()
	cart_frame.name = "CheckoutCounter"
	cart_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0b2227", 0.94), Color("557d76", 0.88))
	)
	column.add_child(cart_frame)
	var cart_row := HBoxContainer.new()
	cart_row.add_theme_constant_override("separation", 10)
	cart_frame.add_child(cart_row)
	cart_label = Label.new()
	cart_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cart_label.add_theme_font_size_override("font_size", 18)
	cart_row.add_child(cart_label)
	cancel_button = Button.new()
	cancel_button.custom_minimum_size = Vector2(84, 38)
	cancel_button.pressed.connect(_on_cancel_pressed)
	cart_row.add_child(cancel_button)
	checkout_button = Button.new()
	checkout_button.custom_minimum_size = Vector2(108, 38)
	checkout_button.pressed.connect(_on_checkout_pressed)
	cart_row.add_child(checkout_button)


func _refresh_all() -> void:
	_refresh_shelf()
	_refresh_status()
	puzzle_board.queue_redraw()


func _refresh_shelf() -> void:
	for child in shelf_list.get_children():
		child.free()
	if shelf_tabs.current_tab == 0:
		for definition in DemoCatalog.items_for_store(DemoCatalog.STORE_TOY):
			var card := ShopProductCard.new()
			card.setup(definition, transaction.available_stock(definition.id), puzzle_board.cell_size)
			card.add_requested.connect(_on_product_add_requested)
			shelf_list.add_child(card)
	else:
		var inventory_count := 0
		for piece in pieces:
			if piece.location != PuzzlePieceState.Location.INVENTORY:
				continue
			var card := PieceInstanceCard.new()
			card.setup(piece, puzzle_board.cell_size)
			card.remove_requested.connect(_on_remove_requested)
			shelf_list.add_child(card)
			inventory_count += 1
		if inventory_count == 0:
			var empty := Label.new()
			empty.text = TranslationServer.translate(&"shop.bag.empty")
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.add_theme_color_override("font_color", Color("718d8d"))
			shelf_list.add_child(empty)


func _refresh_status() -> void:
	money_label.text = "¥%d" % transaction.money
	cart_label.text = TranslationServer.translate(&"shop.cart.summary") % [
		transaction.cart_count(), transaction.cart_total()
	]
	cancel_button.disabled = transaction.cart_count() == 0
	checkout_button.disabled = transaction.cart_count() == 0
	var result := PuzzleRules.evaluate(task, pieces)
	coverage_label.text = "%d / %d" % [result.covered_count, result.total_count]
	for attribute in attribute_labels:
		var label: Label = attribute_labels[attribute]
		label.text = "%s %d" % [UiPalette.attribute_name(attribute), result.attribute_totals[attribute]]


func _on_product_add_requested(item_id: StringName) -> void:
	var result := transaction.add_to_cart(item_id)
	if result.ok:
		_show_feedback(TranslationServer.translate(&"shop.feedback.added"))
	else:
		_show_feedback(_failure_text(result.reason))
	_queue_refresh()


func _on_remove_requested(piece: PuzzlePieceState) -> void:
	if transaction.remove_from_cart(piece):
		_show_feedback(TranslationServer.translate(&"shop.feedback.removed"))
	_queue_refresh()


func _on_checkout_pressed() -> void:
	var result := transaction.checkout()
	if result.ok:
		_show_feedback(TranslationServer.translate(&"shop.feedback.paid"), true)
	else:
		_show_feedback(_failure_text(result.reason))
	_queue_refresh()


func _on_cancel_pressed() -> void:
	if transaction.cancel_cart() > 0:
		_show_feedback(TranslationServer.translate(&"shop.feedback.cancelled"))
	_queue_refresh()


func _on_leave_pressed() -> void:
	transaction.cancel_cart()
	_show_feedback(TranslationServer.translate(&"shop.feedback.left"))
	_queue_refresh()


func _failure_text(reason: StringName) -> String:
	match reason:
		ShopTransaction.RESULT_INSUFFICIENT_FUNDS:
			return TranslationServer.translate(&"shop.feedback.no_money")
		ShopTransaction.RESULT_OUT_OF_STOCK:
			return TranslationServer.translate(&"shop.feedback.no_stock")
		ShopTransaction.RESULT_EMPTY:
			return TranslationServer.translate(&"shop.feedback.empty_cart")
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
	_show_feedback(TranslationServer.translate(&"shop.feedback.ready"))


func _apply_locale_texts() -> void:
	store_name_label.text = TranslationServer.translate(&"store.toy")
	language_button.text = LocaleManager.switch_button_text()
	language_button.tooltip_text = TranslationServer.translate(&"ui.language.tooltip")
	leave_button.text = TranslationServer.translate(&"shop.leave")
	shelf_tabs.set_tab_title(0, TranslationServer.translate(&"shop.tab.goods"))
	shelf_tabs.set_tab_title(1, TranslationServer.translate(&"shop.tab.bag"))
	task_title_label.text = TranslationServer.translate(&"task.teddy.title")
	requirement_label.text = "◆ " + TranslationServer.translate(&"shop.requirement.mirror")
	requirement_label.tooltip_text = TranslationServer.translate(&"ui.requirement.mirror_unmet")
	cancel_button.text = TranslationServer.translate(&"shop.cancel")
	checkout_button.text = TranslationServer.translate(&"shop.checkout")
