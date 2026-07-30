class_name SlotNightTransition
extends RefCounted

var from_day: int
var entries: Array[Dictionary] = []
var consumption_applied := false
var next_result_index := 0


func _init(selected_day: int = 1, selected_entries: Array[Dictionary] = []) -> void:
	from_day = selected_day
	entries = selected_entries.duplicate(true)


func result_keys() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries:
		result.append(StringName(entry.result_key))
	return result
