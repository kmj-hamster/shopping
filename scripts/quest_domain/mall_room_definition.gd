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
@export var required_persona_ids: Array[StringName] = []
@export_range(0, 40, 1) var persona_total_required := 0
@export var allowed_type_ids: Array[StringName] = []
@export var rest_mode := RestMode.NONE
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
		if required_persona_ids.is_empty() and persona_total_required > 0:
			errors.append("Challenge room %s has a threshold without Personas." % id)
		for persona_id in required_persona_ids:
			if persona_id not in CardPropertySet.PERSONAS:
				errors.append("Challenge room %s uses unknown Persona %s." % [id, persona_id])
	elif category == Category.REST and rest_mode == RestMode.NONE:
		errors.append("Rest room %s needs a rest mode." % id)
	elif category == Category.WORK and rest_mode != RestMode.NONE:
		errors.append("Work room %s cannot have a rest mode." % id)
	if rest_mode == RestMode.SALVAGE and slot_count != 3:
		errors.append("Salvage room %s must expose three slots." % id)
	if category != Category.BOSS and boss_round_count != 1:
		errors.append("Only a Boss room may contain multiple challenge rounds.")
	return errors
