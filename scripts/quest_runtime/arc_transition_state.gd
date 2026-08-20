class_name ArcTransitionState
extends RefCounted

var from_day: int
var entries: Array[Dictionary] = []
var effects_applied := false
var applied_entry_count := 0
var next_entry_index := 0


func _init(selected_day: int = 1, selected_entries: Array[Dictionary] = []) -> void:
	from_day = maxi(1, selected_day)
	entries = selected_entries.duplicate(true)


func is_complete() -> bool:
	return (
		applied_entry_count >= entries.size()
		and next_entry_index >= entries.size()
	)
