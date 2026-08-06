class_name CardSlotRule
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var required_all: Array[StringName] = []
@export var allowed_any: Array[StringName] = []
@export var forbidden_any: Array[StringName] = []
@export var accepted_item_ids: Array[StringName] = []
@export var value_requirements: Array[Resource] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Slot id cannot be empty.")
	var seen_item_ids: Dictionary = {}
	for item_id in accepted_item_ids:
		if item_id.is_empty():
			errors.append("Slot %s contains an empty accepted item id." % id)
		elif seen_item_ids.has(item_id):
			errors.append("Slot %s repeats accepted item %s." % [id, item_id])
		seen_item_ids[item_id] = true
	for raw_requirement in value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement == null:
			errors.append("Slot %s contains an invalid value requirement." % id)
		else:
			errors.append_array(requirement.validation_errors())
	return errors
