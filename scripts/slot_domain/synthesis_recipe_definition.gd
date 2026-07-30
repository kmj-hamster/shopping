class_name SynthesisRecipeDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var known_at_start := false
@export var unlock_owner_id: StringName
@export_range(0, 20, 1) var unlock_level := 0
@export_range(0.1, 30.0, 0.1) var duration_seconds := 2.5
@export var slot_rules: Array[Resource] = []
@export var compared_aspects: Array[StringName] = []
@export var tie_winner: StringName
@export var output_by_aspect: Dictionary = {}
@export var preview_text_by_output: Dictionary = {}
@export var first_reward_aspect_by_output: Dictionary = {}


func output_for_aspect(aspect: StringName) -> StringName:
	if output_by_aspect.has(aspect):
		return StringName(output_by_aspect[aspect])
	return StringName(output_by_aspect.get(String(aspect), ""))


func preview_key_for_output(output_id: StringName) -> StringName:
	if preview_text_by_output.has(output_id):
		return StringName(preview_text_by_output[output_id])
	return StringName(preview_text_by_output.get(String(output_id), ""))


func first_reward_aspect_for_output(output_id: StringName) -> StringName:
	if first_reward_aspect_by_output.has(output_id):
		return StringName(first_reward_aspect_by_output[output_id])
	return StringName(first_reward_aspect_by_output.get(String(output_id), ""))


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Recipe id cannot be empty.")
	if display_name_key.is_empty():
		errors.append("Recipe %s needs a display name key." % id)
	if slot_rules.size() < 2:
		errors.append("Recipe %s needs at least two slots." % id)
	for raw_rule in slot_rules:
		var rule := raw_rule as CardSlotRule
		if rule == null:
			errors.append("Recipe %s contains an invalid slot rule." % id)
		else:
			errors.append_array(rule.validation_errors())
	if compared_aspects.size() != 2:
		errors.append("Recipe %s must compare exactly two aspects." % id)
	elif tie_winner not in compared_aspects:
		errors.append("Recipe %s tie winner must be a compared aspect." % id)
	for aspect in compared_aspects:
		if output_for_aspect(aspect).is_empty():
			errors.append("Recipe %s needs an output for %s." % [id, aspect])
	return errors
