extends Control

var tasks: Array[TaskDefinition] = []
var current_task: TaskDefinition
var pieces: Array[PuzzlePieceState] = []
var palette_items: Array[ItemDefinition] = []
var undo_stack: Array[Array] = []

var task_selector: OptionButton
var title_label: Label
var language_button: Button
var reset_button: Button
var task_description: Label
var inventory_title: Label
var inventory_hint: Label
var inventory_panel: InventoryPanel
var puzzle_board: PuzzleBoard
var coverage_label: Label
var requirement_label: Label
var feedback_label: Label
var attribute_labels: Dictionary = {}
var undo_button: Button
var return_button: Button
var validate_button: Button
var footer_label: Label


func _ready() -> void:
	_build_interface()
	tasks = DemoCatalog.all_tasks()
	for task in tasks:
		task_selector.add_item(task.localized_name())
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_apply_locale_texts()
	_load_task(0)


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
	var rotated_anchor := PolyominoGeometry.rotate_anchor_clockwise(candidate.local_cells(), current_anchor)
	candidate.rotation_steps = posmod(candidate.rotation_steps + 1, 4)
	data["grab_offset"] = rotated_anchor
	var preview := data.get("preview") as PieceDragPreview
	if preview != null:
		preview.refresh_drag_geometry(rotated_anchor)
	if puzzle_board != null:
		puzzle_board.refresh_drag_state(data)
	return true


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1119")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 12)
	margin.add_child(root_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root_column.add_child(header)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	task_selector = OptionButton.new()
	task_selector.custom_minimum_size = Vector2(230, 42)
	task_selector.item_selected.connect(_on_task_selected)
	header.add_child(task_selector)

	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(58, 42)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	header.add_child(language_button)

	reset_button = Button.new()
	reset_button.pressed.connect(_reset_current_task)
	header.add_child(reset_button)

	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.split_offset = 360
	root_column.add_child(content)

	var inventory_frame := PanelContainer.new()
	inventory_frame.custom_minimum_size = Vector2(340, 0)
	inventory_frame.add_theme_stylebox_override("panel", UiPalette.panel_style())
	content.add_child(inventory_frame)

	var inventory_column := VBoxContainer.new()
	inventory_column.add_theme_constant_override("separation", 8)
	inventory_frame.add_child(inventory_column)

	inventory_title = Label.new()
	inventory_title.add_theme_font_size_override("font_size", 20)
	inventory_column.add_child(inventory_title)

	inventory_hint = Label.new()
	inventory_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_hint.add_theme_color_override("font_color", Color("9babbc"))
	inventory_column.add_child(inventory_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory_column.add_child(scroll)

	inventory_panel = InventoryPanel.new()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.will_change.connect(_push_undo_snapshot)
	inventory_panel.state_changed.connect(_on_piece_state_changed)
	scroll.add_child(inventory_panel)

	var workspace_frame := PanelContainer.new()
	workspace_frame.add_theme_stylebox_override("panel", UiPalette.panel_style(Color("121b27"), Color("2d4053")))
	content.add_child(workspace_frame)

	var workspace := VBoxContainer.new()
	workspace.add_theme_constant_override("separation", 9)
	workspace_frame.add_child(workspace)

	task_description = Label.new()
	task_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_description.add_theme_font_size_override("font_size", 17)
	workspace.add_child(task_description)

	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(board_center)

	puzzle_board = PuzzleBoard.new()
	puzzle_board.will_change.connect(_push_undo_snapshot)
	puzzle_board.state_changed.connect(_on_piece_state_changed)
	puzzle_board.interaction_message.connect(_show_feedback)
	board_center.add_child(puzzle_board)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 16)
	workspace.add_child(stats)

	coverage_label = Label.new()
	coverage_label.add_theme_font_size_override("font_size", 17)
	stats.add_child(coverage_label)
	for attribute in [
		ItemDefinition.ATTRIBUTE_LAMP,
		ItemDefinition.ATTRIBUTE_MIRROR,
		ItemDefinition.ATTRIBUTE_FLOWER,
		ItemDefinition.ATTRIBUTE_FOG,
	]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", UiPalette.attribute_color(attribute))
		attribute_labels[attribute] = label
		stats.add_child(label)

	requirement_label = Label.new()
	requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	requirement_label.add_theme_font_size_override("font_size", 16)
	workspace.add_child(requirement_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	workspace.add_child(actions)

	undo_button = Button.new()
	undo_button.pressed.connect(_undo)
	actions.add_child(undo_button)

	return_button = Button.new()
	return_button.pressed.connect(_return_all_to_inventory)
	actions.add_child(return_button)

	validate_button = Button.new()
	validate_button.pressed.connect(_validate_current_board)
	actions.add_child(validate_button)

	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("b9c5d1"))
	workspace.add_child(feedback_label)

	footer_label = Label.new()
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_color_override("font_color", Color("75869a"))
	root_column.add_child(footer_label)


func _load_task(index: int) -> void:
	if index < 0 or index >= tasks.size():
		return
	current_task = tasks[index]
	pieces = []
	palette_items = DemoCatalog.lab_palette_items(current_task.id)
	undo_stack.clear()
	task_description.text = "%s\n%s" % [current_task.localized_name(), current_task.localized_description()]
	puzzle_board.set_context(current_task, pieces)
	inventory_panel.set_context(palette_items, pieces, puzzle_board.cell_size)
	_show_feedback(TranslationServer.translate(&"feedback.choose_item"))
	_update_status()


func _on_task_selected(index: int) -> void:
	_load_task(index)


func _reset_current_task() -> void:
	_load_task(task_selector.selected)


func _on_piece_state_changed() -> void:
	call_deferred("_refresh_piece_views")


func _refresh_piece_views() -> void:
	inventory_panel.refresh()
	puzzle_board.queue_redraw()
	_update_status()


func _update_status() -> void:
	var result := PuzzleRules.evaluate(current_task, pieces)
	coverage_label.text = TranslationServer.translate(&"ui.coverage") % [result.covered_count, result.total_count]
	var totals: Dictionary = result.attribute_totals
	for attribute in attribute_labels:
		var label: Label = attribute_labels[attribute]
		label.text = "%s %d" % [UiPalette.attribute_name(attribute), totals[attribute]]
	requirement_label.text = _requirement_text(current_task.attribute_rule, result.attribute_ok)
	requirement_label.add_theme_color_override(
		"font_color",
		Color("78d6a8") if result.attribute_ok else Color("e6a267")
	)
	undo_button.disabled = undo_stack.is_empty()


func _requirement_text(rule: TaskDefinition.AttributeRule, is_satisfied: bool) -> String:
	match rule:
		TaskDefinition.AttributeRule.MIRROR_STRICT:
			return TranslationServer.translate(&"ui.requirement.mirror_met" if is_satisfied else &"ui.requirement.mirror_unmet")
		TaskDefinition.AttributeRule.LAMP_OR_FLOWER:
			return TranslationServer.translate(&"ui.requirement.warm_met" if is_satisfied else &"ui.requirement.warm_unmet")
		_:
			return TranslationServer.translate(&"ui.requirement.none")


func _validate_current_board() -> void:
	var result := PuzzleRules.evaluate(current_task, pieces)
	if result.is_complete:
		_show_feedback(TranslationServer.translate(&"feedback.complete"), true)
	else:
		var separator := TranslationServer.translate(&"ui.reason_separator")
		_show_feedback(TranslationServer.translate(&"feedback.incomplete") % separator.join(result.reasons), false)


func _return_all_to_inventory() -> void:
	if pieces.is_empty():
		_show_feedback(TranslationServer.translate(&"feedback.board_empty"))
		return
	_push_undo_snapshot()
	pieces.clear()
	_on_piece_state_changed()


func _push_undo_snapshot() -> void:
	var snapshot: Array = []
	for piece in pieces:
		snapshot.append({
			"uid": piece.piece_uid,
			"item_id": piece.definition.id,
			"position": piece.grid_position,
			"rotation": piece.rotation_steps,
		})
	undo_stack.append(snapshot)
	if undo_stack.size() > 50:
		undo_stack.pop_front()


func _undo() -> void:
	if undo_stack.is_empty():
		return
	var snapshot: Array = undo_stack.pop_back()
	pieces.clear()
	for saved in snapshot:
		var piece := PuzzlePieceState.new(saved.uid, DemoCatalog.item_by_id(saved.item_id))
		piece.location = PuzzlePieceState.Location.BOARD
		piece.grid_position = saved.position
		piece.rotation_steps = saved.rotation
		pieces.append(piece)
	puzzle_board.set_context(current_task, pieces)
	inventory_panel.set_context(palette_items, pieces, puzzle_board.cell_size)
	_show_feedback(TranslationServer.translate(&"feedback.undone"))
	_on_piece_state_changed()


func _show_feedback(message: String, success: bool = false) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color("78d6a8") if success else Color("b9c5d1"))


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_texts()
	for index in range(tasks.size()):
		task_selector.set_item_text(index, tasks[index].localized_name())
	if current_task != null:
		task_description.text = "%s\n%s" % [current_task.localized_name(), current_task.localized_description()]
		inventory_panel.refresh()
		_update_status()
	_show_feedback(TranslationServer.translate(&"feedback.choose_item"))


func _apply_locale_texts() -> void:
	title_label.text = TranslationServer.translate(&"app.title")
	language_button.text = LocaleManager.switch_button_text()
	language_button.tooltip_text = TranslationServer.translate(&"ui.language.tooltip")
	reset_button.text = TranslationServer.translate(&"ui.reset_task")
	inventory_title.text = TranslationServer.translate(&"ui.inventory.title")
	inventory_hint.text = TranslationServer.translate(&"ui.inventory.hint")
	undo_button.text = TranslationServer.translate(&"ui.undo")
	return_button.text = TranslationServer.translate(&"ui.return_all")
	validate_button.text = TranslationServer.translate(&"ui.validate")
	footer_label.text = TranslationServer.translate(&"ui.footer")
