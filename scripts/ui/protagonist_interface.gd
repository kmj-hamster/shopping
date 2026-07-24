class_name ProtagonistInterface
extends CanvasLayer

var view_context: StringName = &"map"
var root: Control
var bag_button: TextureButton
var protagonist_popup: PanelContainer
var card_field: Control
var task_popups: Dictionary = {}
var card_buttons: Dictionary = {}
var card_origins: Dictionary = {}
var popup_dragging := false
var elapsed := 0.0
var feedback_label: Label
var protagonist_title: Label


func _ready() -> void:
	layer = 20
	_build_interface()
	GameState.state_changed.connect(refresh)
	LocaleManager.locale_changed.connect(func(_locale: String) -> void: refresh())
	refresh()


func _process(delta: float) -> void:
	elapsed += delta
	var index := 0
	for task_id in card_buttons:
		var card := card_buttons[task_id] as Button
		var origin: Vector2 = card_origins.get(task_id, card.position)
		card.position = origin + Vector2(0, sin(elapsed * 0.72 + index * 1.7) * 3.0)
		index += 1


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	var viewport := get_viewport()
	if not viewport.gui_is_dragging():
		return
	var data: Variant = viewport.gui_get_drag_data()
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return
	var candidate := data.get("candidate") as PuzzlePieceState
	if candidate == null:
		return
	var current_anchor: Vector2i = data.get("grab_offset", Vector2i.ZERO)
	var rotated_anchor := PolyominoGeometry.rotate_anchor_clockwise(
		candidate.local_cells(), current_anchor
	)
	candidate.rotation_steps = posmod(candidate.rotation_steps + 1, 4)
	data["grab_offset"] = rotated_anchor
	var preview := data.get("preview") as PieceDragPreview
	if preview != null:
		preview.refresh_drag_geometry(rotated_anchor)
	for popup in task_popups.values():
		(popup as TaskPuzzlePopup).refresh_drag_state(data)
	viewport.set_input_as_handled()


func set_view_context(context: StringName) -> void:
	view_context = context
	if bag_button != null:
		_position_bag_button()
	var index := 0
	for popup in task_popups.values():
		var task_popup := popup as TaskPuzzlePopup
		task_popup.view_context = context
		if not task_popup.user_moved:
			task_popup.position = task_popup.default_position() + Vector2(index * 26, index * 22)
		index += 1


func refresh() -> void:
	if card_field == null:
		return
	_rebuild_cards()
	for popup in task_popups.values():
		if is_instance_valid(popup):
			(popup as TaskPuzzlePopup).refresh()
	_refresh_empty_bag_toggles()


func open_task(task_id: StringName) -> TaskPuzzlePopup:
	if task_popups.has(task_id) and is_instance_valid(task_popups[task_id]):
		var existing := task_popups[task_id] as TaskPuzzlePopup
		_bring_to_front(existing)
		_refresh_empty_bag_toggles()
		return existing
	var popup := TaskPuzzlePopup.new()
	root.add_child(popup)
	popup.setup(task_id, view_context)
	popup.position += Vector2(task_popups.size() * 26, task_popups.size() * 22)
	popup.close_requested.connect(_on_task_close_requested)
	popup.focus_requested.connect(_bring_to_front)
	popup.interaction_message.connect(_show_feedback)
	popup.empty_bag_toggle_requested.connect(_on_empty_bag_toggle_requested)
	task_popups[task_id] = popup
	_bring_to_front(popup)
	_refresh_empty_bag_toggles()
	return popup


func _build_interface() -> void:
	root = Control.new()
	root.name = "ProtagonistInterface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	protagonist_popup = PanelContainer.new()
	protagonist_popup.name = "BagMindPopup"
	protagonist_popup.position = Vector2(720, 280)
	protagonist_popup.size = Vector2(470, 330)
	protagonist_popup.visible = false
	protagonist_popup.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("010305", 0.985), Color("53615d", 0.74))
	)
	root.add_child(protagonist_popup)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	protagonist_popup.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 36)
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_main_header_input)
	column.add_child(header)
	protagonist_title = Label.new()
	protagonist_title.name = "BagMindTitle"
	protagonist_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	protagonist_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	protagonist_title.text = TranslationServer.translate(&"protagonist.title")
	protagonist_title.add_theme_font_size_override("font_size", 19)
	protagonist_title.add_theme_color_override("font_color", Color("cbd7d1"))
	header.add_child(protagonist_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(32, 30)
	close.pressed.connect(func() -> void: protagonist_popup.visible = false)
	header.add_child(close)
	card_field = Control.new()
	card_field.custom_minimum_size = Vector2(440, 240)
	card_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card_field)
	feedback_label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", Color("849793"))
	column.add_child(feedback_label)

	bag_button = TextureButton.new()
	bag_button.name = "ProtagonistBagButton"
	bag_button.texture_normal = load("res://pic/bag.png") as Texture2D
	bag_button.texture_hover = load("res://pic/bag-light.png") as Texture2D
	bag_button.ignore_texture_size = true
	bag_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_position_bag_button()
	bag_button.tooltip_text = TranslationServer.translate(&"protagonist.open")
	bag_button.pressed.connect(_on_bag_pressed)
	root.add_child(bag_button)


func _rebuild_cards() -> void:
	for child in card_field.get_children():
		child.free()
	card_buttons.clear()
	card_origins.clear()
	var positions := [
		Vector2(28, 8), Vector2(232, 6),
		Vector2(48, 88), Vector2(244, 86),
		Vector2(28, 168), Vector2(232, 166),
	]
	var rotations := [-0.035, 0.028, 0.022, -0.03, 0.018, -0.024]
	var index := 0
	for task_id in GameState.protagonist_task_ids():
		var card := Button.new()
		card.name = "TaskCard_%s" % task_id
		card.position = positions[index % positions.size()]
		card.size = Vector2(165, 62)
		card.rotation = rotations[index % rotations.size()]
		card.pivot_offset = card.size * 0.5
		var task := GameState.task_definition(task_id)
		card.text = task.localized_name()
		if task_id != DemoCatalog.DAILY_TASK_ID and GameState.is_task_completed(task_id):
			card.text += "  ·  " + TranslationServer.translate(&"task.memory")
			card.modulate = Color(0.55, 0.62, 0.6, 0.72)
		card.add_theme_font_size_override("font_size", 15)
		card.add_theme_stylebox_override(
			"normal",
			UiPalette.panel_style(Color("111418", 0.96), Color("596461", 0.78))
		)
		card.add_theme_stylebox_override(
			"hover",
			UiPalette.panel_style(Color("1a2325", 0.98), Color("c0aa70", 0.9))
		)
		card.pressed.connect(open_task.bind(task_id))
		card_field.add_child(card)
		card_buttons[task_id] = card
		card_origins[task_id] = card.position
		index += 1
	protagonist_title.text = TranslationServer.translate(&"protagonist.title")
	bag_button.tooltip_text = TranslationServer.translate(&"protagonist.open")


func _on_bag_pressed() -> void:
	protagonist_popup.visible = not protagonist_popup.visible
	if protagonist_popup.visible:
		root.move_child(protagonist_popup, root.get_child_count() - 1)
		root.move_child(bag_button, root.get_child_count() - 1)


func _position_bag_button() -> void:
	bag_button.offset_left = -126.0
	bag_button.offset_right = -14.0
	if view_context == &"shop":
		bag_button.offset_top = -190.0
		bag_button.offset_bottom = -78.0
	else:
		bag_button.offset_top = -126.0
		bag_button.offset_bottom = -14.0


func _on_task_close_requested(task_id: StringName) -> void:
	var popup := task_popups.get(task_id) as TaskPuzzlePopup
	if popup == null:
		return
	task_popups.erase(task_id)
	popup.queue_free()
	_refresh_empty_bag_toggles()


func _on_empty_bag_toggle_requested() -> void:
	var empty_bag_id := DemoCatalog.EMPTY_BAG_TASK_ID
	if task_popups.has(empty_bag_id) and is_instance_valid(task_popups[empty_bag_id]):
		_on_task_close_requested(empty_bag_id)
	else:
		open_task(empty_bag_id)


func _refresh_empty_bag_toggles() -> void:
	var is_open := (
		task_popups.has(DemoCatalog.EMPTY_BAG_TASK_ID)
		and is_instance_valid(task_popups[DemoCatalog.EMPTY_BAG_TASK_ID])
	)
	for popup in task_popups.values():
		if is_instance_valid(popup):
			(popup as TaskPuzzlePopup).set_empty_bag_open(is_open)


func _bring_to_front(popup: TaskPuzzlePopup) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	root.move_child(popup, root.get_child_count() - 1)
	root.move_child(bag_button, root.get_child_count() - 1)


func _show_feedback(message: String) -> void:
	feedback_label.text = message


func _on_main_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		popup_dragging = event.pressed
		if event.pressed:
			root.move_child(protagonist_popup, root.get_child_count() - 1)
	elif event is InputEventMouseMotion and popup_dragging:
		protagonist_popup.position += event.relative
		var viewport_size := get_viewport().get_visible_rect().size
		protagonist_popup.position.x = clampf(
			protagonist_popup.position.x, 0.0, maxf(0.0, viewport_size.x - 120.0)
		)
		protagonist_popup.position.y = clampf(
			protagonist_popup.position.y, 0.0, maxf(0.0, viewport_size.y - 50.0)
		)
