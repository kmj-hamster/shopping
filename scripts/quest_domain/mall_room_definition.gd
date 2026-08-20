class_name MallRoomDefinition
extends Resource

enum Category {
	CHALLENGE,
	REST,
	WORK,
	BOSS,
}

enum RestMode {
	NONE,
	ITEM_GROWTH,
	PERSONA_GROWTH,
	SALVAGE,
}

enum GenerationPool {
	DEFAULT,
	ECONOMY,
}

@export var id: StringName
@export var display_name_key: StringName
@export var category := Category.CHALLENGE
@export_range(1, 20, 1) var generation_weight := 1
@export var intro_text_keys: Array[StringName] = []
@export var challenge_text_keys: Array[StringName] = []
@export var approach_title_keys: Array[StringName] = []
@export var approach_text_keys: Array[StringName] = []
@export var post_choice_text_key: StringName
@export var success_text_key: StringName
@export var failure_text_key: StringName
@export var required_type_ids: Array[StringName] = []
@export var required_shape_ids: Array[StringName] = []
@export_range(0, 40, 1) var shape_total_required := 0
@export var allowed_type_ids: Array[StringName] = []
@export var rest_mode := RestMode.NONE
@export var generation_pool := GenerationPool.DEFAULT
@export_range(1, 3, 1) var slot_count := 1
@export_range(1, 5, 1) var boss_round_count := 1


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Mall room id cannot be empty.")
	if display_name_key.is_empty():
		errors.append("Mall room %s needs a display name key." % id)
	if intro_text_keys.is_empty():
		errors.append("Mall room %s needs introduction text." % id)
	if category in [Category.CHALLENGE, Category.BOSS]:
		if challenge_text_keys.is_empty():
			errors.append("Challenge room %s needs challenge text." % id)
		if approach_title_keys.size() != 2 or approach_text_keys.size() != 2:
			errors.append("Challenge room %s needs exactly two approaches." % id)
		if required_shape_ids.is_empty() and shape_total_required > 0:
			errors.append("Challenge room %s has a threshold without Shapes." % id)
		for shape_id in required_shape_ids:
			if shape_id not in CardPropertySet.SHAPES:
				errors.append("Challenge room %s uses unknown Shape %s." % [id, shape_id])
	elif category == Category.REST and rest_mode == RestMode.NONE:
		errors.append("Rest room %s needs a rest mode." % id)
	elif category == Category.WORK and rest_mode != RestMode.NONE:
		errors.append("Work room %s cannot have a rest mode." % id)
	if generation_pool == GenerationPool.ECONOMY and not (
		category == Category.WORK or rest_mode == RestMode.SALVAGE
	):
		errors.append("Economy room %s must be work or salvage." % id)
	if category == Category.WORK and generation_pool != GenerationPool.ECONOMY:
		errors.append("Work room %s must use the economy generation pool." % id)
	if rest_mode == RestMode.SALVAGE and generation_pool != GenerationPool.ECONOMY:
		errors.append("Salvage room %s must use the economy generation pool." % id)
	if rest_mode == RestMode.SALVAGE and slot_count != 3:
		errors.append("Salvage room %s must expose three slots." % id)
	if category != Category.BOSS and boss_round_count != 1:
		errors.append("Only a Boss room may contain multiple challenge rounds.")
	return errors
