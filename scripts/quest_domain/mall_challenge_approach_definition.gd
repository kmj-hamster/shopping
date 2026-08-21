class_name MallChallengeApproachDefinition
extends Resource

@export var title_text_key: StringName
@export var prompt_text_key: StringName
@export var success_text_key: StringName
@export var failure_text_key: StringName
@export var required_all_type_ids: Array[StringName] = []
@export var required_any_type_ids: Array[StringName] = []
@export var required_persona_shape_id: StringName
@export var required_shape_ids: Array[StringName] = []
@export_range(0, 40, 1) var shape_total_required := 0
@export var feedback_primary_shape_id: StringName


func validation_errors(context: String = "challenge approach") -> PackedStringArray:
	var errors := PackedStringArray()
	for key in [title_text_key, prompt_text_key, success_text_key, failure_text_key]:
		if key.is_empty():
			errors.append("%s needs all player-facing text keys." % context)
			break
	if not required_persona_shape_id.is_empty() and (
		required_persona_shape_id not in CardPropertySet.SHAPES
	):
		errors.append("%s requires unknown Persona Shape %s." % [
			context, required_persona_shape_id,
		])
	for shape_id in required_shape_ids:
		if shape_id not in CardPropertySet.SHAPES:
			errors.append("%s requires unknown Shape %s." % [context, shape_id])
	if required_shape_ids.is_empty() and shape_total_required > 0:
		errors.append("%s has a Shape threshold without required Shapes." % context)
	if not feedback_primary_shape_id.is_empty() and (
		feedback_primary_shape_id not in required_shape_ids
	):
		errors.append("%s primary feedback Shape must be one of its required Shapes." % context)
	return errors
