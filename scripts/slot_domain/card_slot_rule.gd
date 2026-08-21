class_name CardSlotRule
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var detail_title_key: StringName
@export var required_label_key: StringName
@export var allowed_label_key: StringName
@export var forbidden_label_key: StringName
@export var required_all: Array[StringName] = []
@export var allowed_any: Array[StringName] = []
@export var forbidden_any: Array[StringName] = []
@export var accepted_item_ids: Array[StringName] = []
@export var rejected_item_ids: Array[StringName] = []
@export var value_requirements: Array[Resource] = []
# Presentation-only omissions for rules whose exceptional cases should remain
# discoverable through play instead of being exposed by the detail popup.
var hidden_detail_item_ids: Array[StringName] = []


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
	var seen_rejected_item_ids: Dictionary = {}
	for item_id in rejected_item_ids:
		if item_id.is_empty():
			errors.append("Slot %s contains an empty rejected item id." % id)
		elif seen_rejected_item_ids.has(item_id):
			errors.append("Slot %s repeats rejected item %s." % [id, item_id])
		elif item_id in accepted_item_ids:
			errors.append("Slot %s both accepts and rejects item %s." % [id, item_id])
		seen_rejected_item_ids[item_id] = true
	for raw_requirement in value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement == null:
			errors.append("Slot %s contains an invalid value requirement." % id)
		else:
			errors.append_array(requirement.validation_errors())
	return errors
