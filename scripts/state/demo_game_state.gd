class_name DemoGameState
extends Node

signal state_changed

const SAVE_PATH := "user://save_shopping0807_v1.json"
const AUTOSAVE_DEBOUNCE_SECONDS := 0.4

var quest_state: QuestGameState
var save_repository := QuestSaveRepository.new(SAVE_PATH)
var autosave_enabled := true
var autosave_queued := false
var autosave_timer: Timer


func _ready() -> void:
	autosave_timer = Timer.new()
	autosave_timer.one_shot = true
	autosave_timer.wait_time = AUTOSAVE_DEBOUNCE_SECONDS
	autosave_timer.timeout.connect(_flush_autosave)
	add_child(autosave_timer)
	autosave_enabled = not _is_test_run()
	if autosave_enabled:
		load_or_reset_game()
	else:
		reset_game()


func load_or_reset_game() -> bool:
	var candidate := QuestGameState.new()
	var loaded := save_repository.load_into(candidate)
	if not loaded.ok:
		candidate = QuestGameState.new()
	_set_state(candidate)
	state_changed.emit()
	return loaded.ok


func reset_game() -> void:
	_set_state(QuestGameState.new())
	state_changed.emit()


func start_new_game() -> void:
	save_repository.erase()
	reset_game()
	_save_now()


func save_game_now() -> bool:
	return _save_now()


func _set_state(next_state: QuestGameState) -> void:
	if quest_state != null and quest_state.state_changed.is_connected(_on_state_changed):
		quest_state.state_changed.disconnect(_on_state_changed)
	quest_state = next_state
	quest_state.state_changed.connect(_on_state_changed)
	autosave_queued = false
	if autosave_timer != null:
		autosave_timer.stop()


func _on_state_changed() -> void:
	state_changed.emit()
	_queue_autosave()


func _queue_autosave() -> void:
	if not autosave_enabled:
		return
	autosave_queued = true
	# Restarting the timer coalesces bursts and keeps JSON serialization plus
	# file rotation out of the interaction frame.
	if autosave_timer != null:
		autosave_timer.start()


func _flush_autosave() -> void:
	if not autosave_queued:
		return
	autosave_queued = false
	_save_now()


func _save_now() -> bool:
	if not autosave_enabled or quest_state == null:
		return false
	return save_repository.save(quest_state)


func _exit_tree() -> void:
	if autosave_enabled and quest_state != null:
		save_repository.save(quest_state)


func _is_test_run() -> bool:
	for argument in OS.get_cmdline_args():
		if "gut" in argument.to_lower():
			return true
	return false
