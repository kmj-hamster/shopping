class_name SynthesisRecipeDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var unlock_owner_id: StringName
@export_range(0, 20, 1) var unlock_level := 0
@export var unlock_story_flag: StringName
@export var base_rule: CardSlotRule
@export var required_shapes: Dictionary = {}
@export var possibility_hint_key: StringName = &"quest.ui.synthesis.possibility.default"
@export var output_id: StringName
@export var consumes_without_output := false
@export var escalating_shape_requirement := false
@export var process_text_keys: Array[StringName] = []


func required_value(shape_id: StringName) -> int:
	if required_shapes.has(shape_id):
		return int(required_shapes[shape_id])
	return int(required_shapes.get(String(shape_id), 0))


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
	if required_shapes.is_empty() or required_shapes.size() > 2:
		errors.append("Recipe %s needs one or two shape thresholds." % id)
	for raw_shape in required_shapes:
		var shape_id := StringName(raw_shape)
		var amount := int(required_shapes[raw_shape])
		if shape_id not in CardPropertySet.SHAPES or amount < 1 or amount > 20:
			errors.append("Recipe %s has an invalid threshold for %s." % [id, shape_id])
	var has_output := not output_id.is_empty()
	if has_output == consumes_without_output:
		errors.append(
			"Recipe %s must have exactly one completion mode: output or consumption." % id
		)
	if escalating_shape_requirement and required_shapes.size() != 1:
		errors.append("Escalating recipe %s needs exactly one shape threshold." % id)
	if process_text_keys.is_empty():
		errors.append("Recipe %s needs synthesis narration." % id)
	return errors
