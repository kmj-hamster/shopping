class_name DemoGameState
extends Node

signal state_changed

const SAVE_PATH := "user://save_slot_demo_v2.json"
const SYNTHESIS_SAVE_INTERVAL_MSEC := 500

var slot_commerce: SlotCommerceState
var save_repository := SlotSaveRepository.new(SAVE_PATH)
var autosave_enabled := true
var autosave_queued := false
var last_synthesis_save_msec := 0


func _ready() -> void:
	autosave_enabled = not _is_test_run()
	if autosave_enabled:
		load_or_reset_demo()
	else:
		reset_demo()


func load_or_reset_demo() -> bool:
	var candidate := SlotCommerceState.new(PlayerWallet.new(120))
	var loaded := save_repository.load_into(candidate)
	if not loaded.ok:
		candidate = SlotCommerceState.new(PlayerWallet.new(120))
	_set_commerce(candidate)
	state_changed.emit()
	return loaded.ok


func reset_demo() -> void:
	_set_commerce(SlotCommerceState.new(PlayerWallet.new(120)))
	state_changed.emit()


func start_new_demo() -> void:
	save_repository.erase()
	reset_demo()
	_save_now()


func save_demo_now() -> bool:
	return _save_now()


func reload_demo_from_disk() -> bool:
	return load_or_reset_demo()


func _set_commerce(next_commerce: SlotCommerceState) -> void:
	if slot_commerce != null:
		if slot_commerce.state_changed.is_connected(_on_commerce_state_changed):
			slot_commerce.state_changed.disconnect(_on_commerce_state_changed)
		if slot_commerce.synthesis_progressed.is_connected(_on_synthesis_progressed):
			slot_commerce.synthesis_progressed.disconnect(_on_synthesis_progressed)
	slot_commerce = next_commerce
	slot_commerce.state_changed.connect(_on_commerce_state_changed)
	slot_commerce.synthesis_progressed.connect(_on_synthesis_progressed)
	autosave_queued = false
	last_synthesis_save_msec = Time.get_ticks_msec()


func _on_commerce_state_changed() -> void:
	state_changed.emit()
	_queue_autosave()


func _on_synthesis_progressed(_active: ActiveSynthesisState) -> void:
	var now := Time.get_ticks_msec()
	if now - last_synthesis_save_msec < SYNTHESIS_SAVE_INTERVAL_MSEC:
		return
	last_synthesis_save_msec = now
	_queue_autosave()


func _queue_autosave() -> void:
	if not autosave_enabled or autosave_queued:
		return
	autosave_queued = true
	call_deferred("_flush_autosave")


func _flush_autosave() -> void:
	autosave_queued = false
	_save_now()


func _save_now() -> bool:
	if not autosave_enabled or slot_commerce == null:
		return false
	return save_repository.save(slot_commerce)


func _exit_tree() -> void:
	if autosave_enabled and slot_commerce != null:
		save_repository.save(slot_commerce)


func _is_test_run() -> bool:
	for argument in OS.get_cmdline_args():
		if "gut" in argument.to_lower():
			return true
	return false
