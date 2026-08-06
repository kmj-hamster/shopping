class_name TaskInstanceState
extends RefCounted

var instance_id: int
var definition_id: StringName
var activation_day: int
var assignments: Dictionary = {}
var confirmed := false
var resolved_outcome_id: StringName
var settled := false


func _init(
	selected_instance_id: int = 0,
	selected_definition_id: StringName = &"",
	selected_activation_day: int = 1,
) -> void:
	instance_id = selected_instance_id
	definition_id = selected_definition_id
	activation_day = maxi(1, selected_activation_day)


func assigned_instance_id(slot_id: StringName) -> int:
	return int(assignments.get(slot_id, 0))


func assigned_instance_ids() -> Array[int]:
	var result: Array[int] = []
	for raw_instance_id in assignments.values():
		result.append(int(raw_instance_id))
	return result


func clear_assignment_for_card(instance_id_to_remove: int) -> bool:
	for slot_id in assignments.keys():
		if int(assignments[slot_id]) == instance_id_to_remove:
			assignments.erase(slot_id)
			return true
	return false
