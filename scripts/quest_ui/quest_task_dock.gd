class_name QuestTaskDock
extends Control

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
signal owner_result_presented(store_id: StringName, text_key: StringName)

var state: QuestGameState
var current_store_id: StringName
var bookmark_column: VBoxContainer
var task_window: QuestTaskWindow
var open_task_instance_id := 0
var bookmark_buttons: Dictionary = {}


func setup(game_state: QuestGameState) -> void:
	if state != null and state.state_delta.is_connected(_on_state_delta):
		state.state_delta.disconnect(_on_state_delta)
	state = game_state
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)
	if is_node_ready():
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	bookmark_column = VBoxContainer.new()
	bookmark_column.anchor_left = 0.026
	bookmark_column.anchor_top = 0.17
	bookmark_column.anchor_right = 0.172
	bookmark_column.anchor_bottom = 0.68
	bookmark_column.add_theme_constant_override("separation", 7)
	bookmark_column.clip_contents = true
	bookmark_column.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bookmark_column)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func set_store_context(store_id: StringName) -> void:
	current_store_id = store_id
	if task_window != null:
		task_window.current_store_id = store_id
		task_window.refresh()


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
	if open_task_instance_id > 0:
		var open_task := state.task_instance(open_task_instance_id)
		if open_task == null or open_task.settled:
			_close_task()
		elif task_window != null:
			task_window.refresh()


func _create_bookmark(instance_id: int) -> Button:
	var bookmark := Button.new()
	bookmark.custom_minimum_size = Vector2(0, 48)
	bookmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bookmark.clip_text = true
	bookmark.tooltip_text = ""
	bookmark.add_theme_font_size_override("font_size", 12)
	bookmark.pressed.connect(_toggle_task.bind(instance_id))
	bookmark_column.add_child(bookmark)
	return bookmark


func _update_bookmark(bookmark: Button, task: TaskInstanceState) -> void:
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	bookmark.text = TranslationServer.translate(definition.display_name_key)
	var border := Color("83b6a6") if task.confirmed else Color("6d766d")
	bookmark.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("0b2528", 0.92), border)
	)


func _toggle_task(instance_id: int) -> void:
	if open_task_instance_id == instance_id:
		_close_task()
		return
	_close_task()
	open_task_instance_id = instance_id
	task_window = QuestTaskWindow.new()
	task_window.setup(state, instance_id, current_store_id)
	task_window.closed.connect(_close_task)
	task_window.rule_focused.connect(rule_focused.emit)
	task_window.item_inspected.connect(item_inspected.emit)
	task_window.owner_result_presented.connect(owner_result_presented.emit)
	add_child(task_window)


func _close_task() -> void:
	open_task_instance_id = 0
	rule_focused.emit(null)
	if task_window != null and is_instance_valid(task_window):
		task_window.queue_free()
	task_window = null


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
	refresh()
