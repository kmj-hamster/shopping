class_name DailyWishDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var slot_rule: CardSlotRule
@export var result_text_keys: Dictionary = {}


func localized_name() -> String:
	return TranslationServer.translate(display_name_key)


func result_key_for(item_id: StringName) -> StringName:
	if result_text_keys.has(item_id):
		return StringName(result_text_keys[item_id])
	return StringName(result_text_keys.get(String(item_id), ""))


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Wish id cannot be empty.")
	if display_name_key.is_empty():
		errors.append("Wish %s needs a display name key." % id)
	if slot_rule == null:
		errors.append("Wish %s needs a slot rule." % id)
	else:
		errors.append_array(slot_rule.validation_errors())
	if result_text_keys.is_empty():
		errors.append("Wish %s needs at least one result text." % id)
	return errors
