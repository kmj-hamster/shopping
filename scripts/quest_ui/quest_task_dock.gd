class_name QuestTaskDock
extends Control

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

const RECEIPT_WIDTH := 264.0
const RECEIPT_COLLAPSED_HEIGHT := 186.0
const RECEIPT_EXPANDED_HEIGHT := 477.0

var state: QuestGameState
var receipt_host: Control
var receipt_background: TextureRect
var receipt_title: Label
var task_scroll: ScrollContainer
var receipt_toggle: Button
var bookmark_column: VBoxContainer
var popup_host: Control
var task_window: QuestTaskWindow
var open_task_instance_id := 0
var bookmark_buttons: Dictionary = {}
var task_windows: Dictionary = {}
var is_expanded := false


func setup(game_state: QuestGameState, task_popup_host: Control = null) -> void:
	if state != null and state.state_delta.is_connected(_on_state_delta):
		state.state_delta.disconnect(_on_state_delta)
	state = game_state
	popup_host = task_popup_host
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)
	if is_node_ready():
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	receipt_host = Control.new()
	receipt_host.name = "TodoReceipt"
	receipt_host.position = Vector2.ZERO
	receipt_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.clip_contents = false
	add_child(receipt_host)

	receipt_background = TextureRect.new()
	receipt_background.name = "TodoReceiptBackground"
	receipt_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	receipt_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	receipt_background.stretch_mode = TextureRect.STRETCH_SCALE
	receipt_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(receipt_background)

	receipt_title = Label.new()
	receipt_title.name = "TodoReceiptTitle"
	receipt_title.position = Vector2(46, 48)
	receipt_title.size = Vector2(160, 44)
	receipt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	receipt_title.add_theme_font_size_override("font_size", 22)
	receipt_title.add_theme_color_override("font_color", Color("16272a"))
	receipt_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(receipt_title)

	task_scroll = ScrollContainer.new()
	task_scroll.name = "TodoTaskScroll"
	task_scroll.position = Vector2(22, 104)
	task_scroll.size = Vector2(174, 306)
	task_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	task_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	task_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	task_scroll.clip_contents = true
	receipt_host.add_child(task_scroll)
	bookmark_column = VBoxContainer.new()
	bookmark_column.name = "TodoTaskColumn"
	bookmark_column.custom_minimum_size = Vector2(174, 0)
	bookmark_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bookmark_column.add_theme_constant_override("separation", 5)
	bookmark_column.clip_contents = false
	bookmark_column.mouse_filter = Control.MOUSE_FILTER_PASS
	task_scroll.add_child(bookmark_column)

	receipt_toggle = Button.new()
	receipt_toggle.name = "TodoReceiptToggle"
	receipt_toggle.flat = true
	receipt_toggle.focus_mode = Control.FOCUS_NONE
	receipt_toggle.tooltip_text = ""
	receipt_toggle.pressed.connect(_toggle_receipt)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		receipt_toggle.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	receipt_host.add_child(receipt_toggle)

	LocaleManager.locale_changed.connect(_on_locale_changed)
	receipt_title.text = TranslationServer.translate(&"quest.ui.todo.title")
	_set_expanded(false)
	call_deferred("_hide_scrollbar_art")
	refresh()


func refresh() -> void:
	if state == null or bookmark_column == null:
		return
	var active_tasks := state.active_tasks()
	var desired_ids: Array[int] = []
	for task in active_tasks:
		desired_ids.append(task.instance_id)
	for raw_instance_id in bookmark_buttons.keys().duplicate():
		var instance_id := int(raw_instance_id)
		if desired_ids.has(instance_id):
			continue
		var obsolete := bookmark_buttons[instance_id] as Button
		bookmark_buttons.erase(instance_id)
		if obsolete != null:
			obsolete.visible = false
			obsolete.queue_free()
	for index in active_tasks.size():
		var task := active_tasks[index]
		var bookmark := bookmark_buttons.get(task.instance_id) as Button
		if bookmark == null:
			bookmark = _create_bookmark(task.instance_id)
			bookmark_buttons[task.instance_id] = bookmark
		_update_bookmark(bookmark, task)
		if bookmark.get_index() != index:
			bookmark_column.move_child(bookmark, index)
	_reconcile_task_windows(desired_ids)
	if open_task_instance_id > 0:
		var open_task := state.task_instance(open_task_instance_id)
		if open_task == null or open_task.settled:
			_close_task()
		elif task_window != null:
			task_window.refresh()


func _create_bookmark(instance_id: int) -> Button:
	var bookmark := Button.new()
	bookmark.custom_minimum_size = Vector2(0, 43)
	bookmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bookmark.clip_text = true
	bookmark.tooltip_text = ""
	bookmark.focus_mode = Control.FOCUS_NONE
	bookmark.add_theme_font_size_override("font_size", 11)
	bookmark.add_theme_color_override("font_color", Color("243236"))
	bookmark.add_theme_color_override("font_hover_color", Color("071013"))
	bookmark.pressed.connect(_toggle_task.bind(instance_id))
	bookmark_column.add_child(bookmark)
	return bookmark


func _update_bookmark(bookmark: Button, task: TaskInstanceState) -> void:
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	bookmark.text = TranslationServer.translate(definition.display_name_key)
	var border := Color("647a72", 0.84) if task.confirmed else Color("686d68", 0.64)
	bookmark.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("d7d9ce", 0.32), border)
	)
	bookmark.add_theme_stylebox_override(
		"hover", UiPalette.panel_style(Color("e9e8dc", 0.68), Color("405d58", 0.9))
	)
	bookmark.add_theme_stylebox_override(
		"pressed", UiPalette.panel_style(Color("c9cdc3", 0.72), Color("314b47", 0.95))
	)


func _toggle_receipt() -> void:
	_set_expanded(not is_expanded)


func _set_expanded(expanded: bool) -> void:
	is_expanded = expanded
	if receipt_host == null:
		return
	var receipt_height := (
		RECEIPT_EXPANDED_HEIGHT if is_expanded else RECEIPT_COLLAPSED_HEIGHT
	)
	receipt_host.size = Vector2(RECEIPT_WIDTH, receipt_height)
	receipt_background.texture = load(
		"res://resources/ui/shell/todo-expanded.png"
		if is_expanded
		else "res://resources/ui/shell/todo-collapsed.png"
	) as Texture2D
	task_scroll.visible = is_expanded
	receipt_toggle.position = (
		Vector2(62, receipt_height - 65)
		if is_expanded
		else Vector2(32, 42)
	)
	receipt_toggle.size = (
		Vector2(132, 56)
		if is_expanded
		else Vector2(196, 126)
	)
	call_deferred("_hide_scrollbar_art")


func _hide_scrollbar_art() -> void:
	if task_scroll == null:
		return
	var scroll_bar := task_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return
	scroll_bar.self_modulate = Color(1, 1, 1, 0)
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _toggle_task(instance_id: int) -> void:
	if open_task_instance_id == instance_id:
		_close_task()
		return
	_close_task()
	open_task_instance_id = instance_id
	task_window = task_windows.get(instance_id) as QuestTaskWindow
	if task_window == null:
		task_window = QuestTaskWindow.new()
		task_window.setup(state, instance_id)
		task_window.closed.connect(_close_task)
		task_window.rule_focused.connect(rule_focused.emit)
		task_window.item_inspected.connect(item_inspected.emit)
		var host := popup_host if popup_host != null else self
		host.add_child(task_window)
		task_window.set_drag_bounds_control(host)
		task_windows[instance_id] = task_window
	else:
		task_window.refresh()
	task_window.visible = true


func _close_task() -> void:
	var closing_instance_id := open_task_instance_id
	var closing_window := task_window
	open_task_instance_id = 0
	rule_focused.emit(null)
	task_window = null
	if closing_window != null and is_instance_valid(closing_window):
		closing_window.visible = false
	if state != null and closing_instance_id > 0:
		state.dismiss_claimed_gift_task(closing_instance_id)


func close_open_task() -> void:
	if open_task_instance_id > 0 or task_window != null:
		_close_task()


func _reconcile_task_windows(desired_ids: Array[int]) -> void:
	for raw_instance_id in task_windows.keys().duplicate():
		var instance_id := int(raw_instance_id)
		if desired_ids.has(instance_id):
			continue
		var obsolete := task_windows[instance_id] as QuestTaskWindow
		task_windows.erase(instance_id)
		if obsolete != null:
			obsolete.visible = false
			obsolete.queue_free()
		if open_task_instance_id == instance_id:
			open_task_instance_id = 0
			task_window = null
			rule_focused.emit(null)


func _on_state_delta(delta: QuestStateDelta) -> void:
	if delta == null or not delta.affects_tasks():
		return
	if delta.full_reconcile or delta.task_list_changed:
		refresh()
		return
	for instance_id in delta.task_instance_ids:
		var task := state.task_instance(instance_id)
		var bookmark := bookmark_buttons.get(instance_id) as Button
		if task != null and not task.settled and bookmark != null:
			_update_bookmark(bookmark, task)
	if open_task_instance_id in delta.task_instance_ids and task_window != null:
		task_window.refresh()


func _on_locale_changed(_locale: String) -> void:
	if receipt_title != null:
		receipt_title.text = TranslationServer.translate(&"quest.ui.todo.title")
	refresh()
