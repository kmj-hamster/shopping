class_name DemoGameState
extends Node

signal state_changed

const SAVE_PATH := "user://save_shopping0807_v1.json"
const LEGACY_SAVE_PATH := "user://save_shopping0807_legacy.json"
const PREVIOUS_NIGHT_SAVE_PATH := "user://save_shopping0807_previous_night_v1.json"
const LEGACY_PREVIOUS_NIGHT_SAVE_PATH := "user://save_shopping0807_legacy_previous_night.json"
const AUTOSAVE_DEBOUNCE_SECONDS := 0.4

var quest_state: QuestGameState
var save_repository := QuestSaveRepository.new(SAVE_PATH)
var previous_night_repository := QuestSaveRepository.new(PREVIOUS_NIGHT_SAVE_PATH)
var autosave_enabled := true
var autosave_queued := false
var autosave_timer: Timer


func _ready() -> void:
	if QuestArcCatalog.using_legacy_demo():
		save_repository = QuestSaveRepository.new(LEGACY_SAVE_PATH)
		previous_night_repository = QuestSaveRepository.new(LEGACY_PREVIOUS_NIGHT_SAVE_PATH)
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
	if not previous_night_repository.has_save() and candidate.lethal_disease_id().is_empty():
		previous_night_repository.save(candidate)
	state_changed.emit()
	return loaded.ok


func reset_game() -> void:
	_set_state(QuestGameState.new())
	state_changed.emit()


func start_new_game() -> void:
	save_repository.erase()
	previous_night_repository.erase()
	reset_game()
	_save_now()
	previous_night_repository.save(quest_state)


func save_game_now() -> bool:
	return _save_now()


func capture_previous_night_checkpoint() -> bool:
	if quest_state == null or not quest_state.lethal_disease_id().is_empty():
		return false
	return previous_night_repository.save(quest_state)


func has_previous_night_checkpoint() -> bool:
	return previous_night_repository.has_save()


func restore_previous_night_checkpoint() -> bool:
	var candidate := QuestGameState.new()
	var loaded := previous_night_repository.load_into(candidate)
	if not bool(loaded.get("ok", false)):
		return false
	_set_state(candidate)
	state_changed.emit()
	if autosave_enabled:
		_save_now()
	return true


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
