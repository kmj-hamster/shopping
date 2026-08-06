class_name TaskOutcomeDefinition
extends Resource

@export var id: StringName
@export var result_text_key: StringName
@export var priority := 0
@export var is_fallback := false
@export var conditions: Array[Resource] = []
@export var effects: Array[Resource] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or result_text_key.is_empty():
		errors.append("Task outcome needs an id and result text key.")
	for raw_condition in conditions:
		var condition := raw_condition as StoryCondition
		if condition == null:
			errors.append("Outcome %s contains an invalid condition." % id)
		else:
			errors.append_array(condition.validation_errors())
	for raw_effect in effects:
		var effect := raw_effect as StoryEffect
		if effect == null:
			errors.append("Outcome %s contains an invalid effect." % id)
		else:
			errors.append_array(effect.validation_errors())
	return errors
