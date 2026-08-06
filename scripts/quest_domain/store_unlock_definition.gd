class_name StoreUnlockDefinition
extends Resource

@export var id: StringName
@export var store_id: StringName
@export var prompt_text_key: StringName
@export var result_text_key: StringName
@export var slot_rule: CardSlotRule
@export var consume_item := true


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or store_id.is_empty():
		errors.append("Store unlock needs id and store id.")
	if prompt_text_key.is_empty() or result_text_key.is_empty():
		errors.append("Store unlock %s needs prompt and result text." % id)
	if slot_rule == null:
		errors.append("Store unlock %s needs a slot rule." % id)
	else:
		errors.append_array(slot_rule.validation_errors())
		if slot_rule.accepted_item_ids.is_empty():
			errors.append("Store unlock %s must name accepted item ids." % id)
	if not consume_item:
		errors.append("Store unlock %s must consume its key item." % id)
	return errors
