class_name SynthesisRecipeDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var known_at_start := false
@export var unlock_owner_id: StringName
@export_range(0, 20, 1) var unlock_level := 0
@export var unlock_story_flag: StringName
@export var base_rule: CardSlotRule
@export var required_aspects: Dictionary = {}
@export var output_id: StringName
@export var process_text_keys: Array[StringName] = []


func required_value(aspect_id: StringName) -> int:
	if required_aspects.has(aspect_id):
		return int(required_aspects[aspect_id])
	return int(required_aspects.get(String(aspect_id), 0))


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Recipe id cannot be empty.")
	if display_name_key.is_empty():
		errors.append("Recipe %s needs a display name key." % id)
	if not unlock_owner_id.is_empty() and not unlock_story_flag.is_empty():
		errors.append("Recipe %s cannot use owner and story-flag unlocks together." % id)
	if base_rule == null:
		errors.append("Recipe %s needs a base material rule." % id)
	else:
		errors.append_array(base_rule.validation_errors())
	if required_aspects.is_empty():
		errors.append("Recipe %s needs at least one aspect threshold." % id)
	for raw_aspect in required_aspects:
		var aspect := StringName(raw_aspect)
		var amount := int(required_aspects[raw_aspect])
		if aspect not in CardPropertySet.ASPECTS or amount < 1 or amount > 20:
			errors.append("Recipe %s has an invalid threshold for %s." % [id, aspect])
	if output_id.is_empty():
		errors.append("Recipe %s needs an output item." % id)
	if process_text_keys.is_empty():
		errors.append("Recipe %s needs synthesis narration." % id)
	return errors
