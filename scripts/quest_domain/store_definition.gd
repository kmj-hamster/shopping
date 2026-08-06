class_name StoreDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var initially_unlocked := false
@export var unlock_definition_id: StringName
@export_range(1, 6, 1) var initial_capacity := 6
@export var initial_shelf_item_ids: Array[StringName] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or display_name_key.is_empty():
		errors.append("Store needs id and display name.")
	if initially_unlocked and not unlock_definition_id.is_empty():
		errors.append("Initially open store %s cannot require a map unlock." % id)
	if not initially_unlocked and unlock_definition_id.is_empty():
		errors.append("Locked store %s needs a map unlock definition." % id)
	if initial_shelf_item_ids.size() > initial_capacity:
		errors.append("Store %s has more initial items than shelf positions." % id)
	return errors
