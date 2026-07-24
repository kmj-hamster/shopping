class_name TaskPuzzlePopup
extends PanelContainer

signal close_requested(task_id: StringName)
signal focus_requested(popup: TaskPuzzlePopup)
signal interaction_message(message: String)
signal empty_bag_toggle_requested

const CELL_SIZE := 42.0

var task_id: StringName
var task: TaskDefinition
var view_context: StringName = &"map"
var dragging_window := false
var user_moved := false

var title_label: Label
var puzzle_board: PuzzleBoard
var status_label: Label
var result_label: Label
var checkout_notice: PanelContainer
var checkout_notice_label: Label
var submit_button: Button
var empty_bag_toggle_button: Button
var close_button: Button
var header: HBoxContainer


func setup(selected_task_id: StringName, context: StringName) -> void:
	task_id = selected_task_id
	view_context = context
	task = GameState.task_definition(task_id)
	_build_interface()
	refresh()


func default_position() -> Vector2:
	if task_id == DemoCatalog.EMPTY_BAG_TASK_ID:
		return Vector2(24, 120)
	if view_context == &"shop":
		return Vector2(650, 120)
	return Vector2(385, 150)


func refresh() -> void:
	if not is_node_ready() or title_label == null:
		return
	task = GameState.task_definition(task_id)
	if task == null:
		return
	title_label.text = task.localized_name()
	submit_button.text = TranslationServer.translate(&"task.daily.submit")
	puzzle_board.set_context(task, GameState.pieces)
	var locked := _is_locked()
	puzzle_board.interaction_locked = locked
	var evaluation := PuzzleRules.evaluate(task, GameState.pieces)
	status_label.text = TranslationServer.translate(&"task.popup.progress") % [
		evaluation.covered_count,
		evaluation.total_count,
		_dominant_attribute_name(evaluation.attribute_totals),
	]
	if task_id == DemoCatalog.EMPTY_BAG_TASK_ID:
		status_label.visible = false
		result_label.visible = false
		checkout_notice.visible = false
		submit_button.visible = false
	elif task_id == DemoCatalog.DAILY_TASK_ID:
		status_label.visible = true
		submit_button.visible = not GameState.daily_goal.submitted and evaluation.is_complete
		result_label.visible = GameState.daily_goal.submitted
		if GameState.daily_goal.submitted:
			result_label.text = TranslationServer.translate(GameState.daily_goal.result_key)
		else:
			result_label.text = ""
	elif GameState.is_task_completed(task_id):
		status_label.visible = true
		submit_button.visible = false
		result_label.visible = true
		result_label.text = TranslationServer.translate(GameState.event_notice_key(task_id))
	else:
		status_label.visible = true
		submit_button.visible = false
		result_label.visible = true
		result_label.text = TranslationServer.translate(&"task.popup.owner_submit")
	if not GameState.has_pending_purchases(task_id):
		checkout_notice.visible = false
	queue_redraw()


func refresh_drag_state(data: Variant) -> void:
	puzzle_board.refresh_drag_state(data)


func set_empty_bag_open(is_open: bool) -> void:
	if empty_bag_toggle_button == null:
		return
	empty_bag_toggle_button.text = "▣" if is_open else "▦"
	empty_bag_toggle_button.tooltip_text = TranslationServer.translate(
		&"task.empty_bag.close" if is_open else &"task.empty_bag.open"
	)


func _build_interface() -> void:
	name = "TaskPopup_%s" % task_id
	position = default_position()
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("05090d", 0.97), Color("617b78", 0.9))
	)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	add_child(column)
	header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 34)
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	column.add_child(header)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color("d5e4dd"))
	header.add_child(title_label)
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(32, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	puzzle_board = PuzzleBoard.new()
	puzzle_board.cell_size = CELL_SIZE
	puzzle_board.remove_on_failed_external_drop = false
	puzzle_board.state_changed.connect(_on_board_changed)
	puzzle_board.interaction_message.connect(interaction_message.emit)
	column.add_child(puzzle_board)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("91aaa6"))
	column.add_child(status_label)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(0, 38)
	result_label.add_theme_color_override("font_color", Color("d8bd7b"))
	column.add_child(result_label)
	checkout_notice = PanelContainer.new()
	checkout_notice.name = "CheckoutNotice"
	checkout_notice.visible = false
	checkout_notice.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("24170f", 0.98), Color("d7a15d", 0.94))
	)
	column.add_child(checkout_notice)
	checkout_notice_label = Label.new()
	checkout_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkout_notice_label.add_theme_color_override("font_color", Color("f0c982"))
	checkout_notice.add_child(checkout_notice_label)
	submit_button = Button.new()
	submit_button.custom_minimum_size = Vector2(120, 36)
	submit_button.text = TranslationServer.translate(&"task.daily.submit")
	submit_button.pressed.connect(_on_submit_pressed)
	column.add_child(submit_button)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	empty_bag_toggle_button = Button.new()
	empty_bag_toggle_button.name = "EmptyBagToggle"
	empty_bag_toggle_button.visible = task_id != DemoCatalog.EMPTY_BAG_TASK_ID
	empty_bag_toggle_button.custom_minimum_size = Vector2(38, 32)
	empty_bag_toggle_button.pressed.connect(empty_bag_toggle_requested.emit)
	footer.add_child(empty_bag_toggle_button)
	set_empty_bag_open(false)


func _is_locked() -> bool:
	return (
		(task_id == DemoCatalog.DAILY_TASK_ID and GameState.daily_goal.submitted)
		or (
			task_id not in [DemoCatalog.DAILY_TASK_ID, DemoCatalog.EMPTY_BAG_TASK_ID]
			and GameState.is_task_completed(task_id)
		)
	)


func _dominant_attribute_name(totals: Dictionary) -> String:
	var key := PuzzleRules.dominant_attribute_result_key(totals)
	if key == &"daily.result.mixed":
		return TranslationServer.translate(&"attribute.mixed")
	return UiPalette.attribute_name(StringName(String(key).trim_prefix("daily.result.")))


func _on_board_changed() -> void:
	GameState.notify_piece_layout_changed()
	refresh()


func _on_submit_pressed() -> void:
	var result := GameState.submit_daily_goal()
	if not result.ok:
		var message := TranslationServer.translate(
			&"task.checkout_first"
			if result.reason == GameState.RESULT_PENDING_PURCHASE
			else &"task.daily.not_ready"
		)
		if result.reason == GameState.RESULT_PENDING_PURCHASE:
			checkout_notice_label.text = message
			checkout_notice.visible = true
		interaction_message.emit(message)
	refresh()


func _on_close_pressed() -> void:
	close_requested.emit(task_id)


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_window = event.pressed
		if event.pressed:
			focus_requested.emit(self)
			header.accept_event()
	elif event is InputEventMouseMotion and dragging_window:
		user_moved = true
		position += event.relative
		_clamp_to_viewport()
		header.accept_event()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position.x = clampf(position.x, 0.0, maxf(0.0, viewport_size.x - 120.0))
	position.y = clampf(position.y, 0.0, maxf(0.0, viewport_size.y - 50.0))
