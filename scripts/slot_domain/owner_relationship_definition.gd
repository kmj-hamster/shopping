class_name OwnerRelationshipDefinition
extends Resource

@export var id: StringName
@export var store_id: StringName
@export var display_name_key: StringName
@export var level_thresholds := PackedInt32Array([0, 3, 7, 14])
@export var level_name_keys: Array[StringName] = []
@export var daily_dialogue_keys: Array[StringName] = []
@export var repeat_dialogue_key: StringName
@export var level_up_text_keys: Dictionary = {}
@export_range(0, 20, 1) var discount_level := 3
@export_range(0.0, 0.9, 0.01) var discount_rate := 0.1


func level_for_experience(experience: int) -> int:
	var result := 0
	for index in range(level_thresholds.size()):
		if experience >= level_thresholds[index]:
			result = index
	return result


func threshold_for_level(level: int) -> int:
	if level_thresholds.is_empty():
		return 0
	return level_thresholds[clampi(level, 0, level_thresholds.size() - 1)]


func next_threshold_for_level(level: int) -> int:
	return threshold_for_level(mini(level + 1, level_thresholds.size() - 1))


func level_name_key(level: int) -> StringName:
	if level >= 0 and level < level_name_keys.size():
		return level_name_keys[level]
	return &""


func dialogue_key_for_day(day: int) -> StringName:
	if daily_dialogue_keys.is_empty():
		return &""
	return daily_dialogue_keys[clampi(day - 1, 0, daily_dialogue_keys.size() - 1)]


func level_up_text_key(level: int) -> StringName:
	if level_up_text_keys.has(level):
		return StringName(level_up_text_keys[level])
	return StringName(level_up_text_keys.get(str(level), ""))


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or store_id.is_empty() or display_name_key.is_empty():
		errors.append("Owner relationship needs id, store, and display name: %s" % id)
	if level_thresholds.size() < 2 or level_thresholds[0] != 0:
		errors.append("Owner %s needs level thresholds beginning at zero." % id)
	for index in range(1, level_thresholds.size()):
		if level_thresholds[index] <= level_thresholds[index - 1]:
			errors.append("Owner %s level thresholds must increase." % id)
	if level_name_keys.size() != level_thresholds.size():
		errors.append("Owner %s needs one name per level." % id)
	return errors
