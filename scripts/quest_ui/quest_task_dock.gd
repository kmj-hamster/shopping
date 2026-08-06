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
var refresh_queued := false


func setup(game_state: QuestGameState) -> void:
	state = game_state
	if state != null and not state.state_changed.is_connected(_queue_refresh):
		state.state_changed.connect(_queue_refresh)
	if is_node_ready():
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	bookmark_column = VBoxContainer.new()
	bookmark_column.position = Vector2(0, 118)
	bookmark_column.size = Vector2(164, 430)
	bookmark_column.add_theme_constant_override("separation", 7)
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
	for child in bookmark_column.get_children():
		child.free()
	for task in state.active_tasks():
		var definition := QuestArcCatalog.task_by_id(task.definition_id)
		var bookmark := Button.new()
		bookmark.custom_minimum_size = Vector2(154, 52)
		bookmark.text = TranslationServer.translate(definition.display_name_key)
		bookmark.tooltip_text = TranslationServer.translate(definition.body_text_key)
		bookmark.pressed.connect(_toggle_task.bind(task.instance_id))
		var border := Color("83b6a6") if task.confirmed else Color("6d766d")
		bookmark.add_theme_stylebox_override(
			"normal", UiPalette.panel_style(Color("071317", 0.95), border)
		)
		bookmark_column.add_child(bookmark)
	if open_task_instance_id > 0:
		var open_task := state.task_instance(open_task_instance_id)
		if open_task == null or open_task.settled:
			_close_task()
		elif task_window != null:
			task_window.refresh()


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


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
