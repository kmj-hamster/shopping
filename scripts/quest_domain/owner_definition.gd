class_name OwnerDefinition
extends Resource

@export var id: StringName
@export var store_id: StringName
@export var display_name_key: StringName
@export var idle_dialogue_key: StringName
@export var item_comment_key: StringName
@export var request_available_flag: StringName
@export var request_required_value: StringName = &"true"
@export var request_task_id: StringName
@export var request_dialogue_key: StringName
@export var reminder_dialogue_key: StringName
@export var request_recipe_id: StringName
@export var event_item_id: StringName
@export var event_item_store_id: StringName
@export_range(1, 3, 1) var event_item_page := 2
@export var state_dialogue_keys: Dictionary = {}
@export var portrait_hidden_states: Array[StringName] = []


func dialogue_for_state(state_id: StringName) -> StringName:
	if state_dialogue_keys.has(state_id):
		return StringName(state_dialogue_keys[state_id])
	return StringName(state_dialogue_keys.get(String(state_id), idle_dialogue_key))


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or store_id.is_empty() or display_name_key.is_empty():
		errors.append("Owner needs id, store, and display name: %s." % id)
	if idle_dialogue_key.is_empty() or item_comment_key.is_empty():
		errors.append("Owner %s needs idle and item-comment dialogue." % id)
	var request_fields := [
		request_available_flag,
		request_task_id,
		request_dialogue_key,
		reminder_dialogue_key,
		request_recipe_id,
		event_item_id,
		event_item_store_id,
	]
	var populated := request_fields.count(&"") < request_fields.size()
	if populated and request_fields.any(func(value: StringName) -> bool: return value.is_empty()):
		errors.append("Owner %s has an incomplete request definition." % id)
	return errors
