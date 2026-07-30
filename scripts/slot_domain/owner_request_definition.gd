class_name OwnerRequestDefinition
extends Resource

@export var id: StringName
@export var owner_id: StringName
@export var display_name_key: StringName
@export_range(0, 20, 1) var unlock_level := 0
@export var slot_rule: CardSlotRule
@export_range(0, 99, 1) var base_experience := 0
@export_range(0, 99, 1) var preferred_bonus := 0
@export var preferred_item_ids: Array[StringName] = []
@export var result_text_by_item: Dictionary = {}
@export var story_flag_key: StringName
@export var story_flag_value_by_item: Dictionary = {}


func experience_for_item(item_id: StringName) -> int:
	return base_experience + (preferred_bonus if item_id in preferred_item_ids else 0)


func result_text_key_for_item(item_id: StringName) -> StringName:
	if result_text_by_item.has(item_id):
		return StringName(result_text_by_item[item_id])
	return StringName(result_text_by_item.get(String(item_id), ""))


func story_flag_value_for_item(item_id: StringName) -> StringName:
	if story_flag_value_by_item.has(item_id):
		return StringName(story_flag_value_by_item[item_id])
	return StringName(story_flag_value_by_item.get(String(item_id), ""))


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or owner_id.is_empty() or display_name_key.is_empty():
		errors.append("Owner request needs id, owner, and display name: %s" % id)
	if slot_rule == null:
		errors.append("Owner request %s needs a slot rule." % id)
	if base_experience <= 0:
		errors.append("Owner request %s needs a positive experience reward." % id)
	return errors
