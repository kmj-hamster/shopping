class_name MallChallengeRoundDefinition
extends Resource

@export var challenge_text_keys: Array[StringName] = []
@export var approaches: Array[Resource] = []


func approach_at(index: int) -> MallChallengeApproachDefinition:
	if index < 0 or index >= approaches.size():
		return null
	return approaches[index] as MallChallengeApproachDefinition


func validation_errors(context: String = "challenge round") -> PackedStringArray:
	var errors := PackedStringArray()
	if challenge_text_keys.is_empty():
		errors.append("%s needs challenge text." % context)
	if approaches.size() != 2:
		errors.append("%s needs exactly two approaches." % context)
	for index in approaches.size():
		var approach := approach_at(index)
		if approach == null:
			errors.append("%s approach %d is invalid." % [context, index])
			continue
		errors.append_array(approach.validation_errors("%s approach %d" % [context, index]))
	return errors
