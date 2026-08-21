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
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var image_path: String
@export var category := Category.CHALLENGE
@export_range(1, 20, 1) var generation_weight := 1
@export var intro_text_keys: Array[StringName] = []
@export var challenge_rounds: Array[Resource] = []
@export var reward_item_id: StringName
@export var allowed_type_ids: Array[StringName] = []
@export var rest_mode := RestMode.NONE
@export var generation_pool := GenerationPool.DEFAULT
@export_range(1, 3, 1) var slot_count := 1


func challenge_round_at(index: int) -> MallChallengeRoundDefinition:
	if index < 0 or index >= challenge_rounds.size():
		return null
	return challenge_rounds[index] as MallChallengeRoundDefinition


func challenge_round_count() -> int:
	return challenge_rounds.size()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Mall room id cannot be empty.")
	if display_name_key.is_empty():
		errors.append("Mall room %s needs a display name key." % id)
	if not image_path.is_empty() and not ResourceLoader.exists(image_path):
		errors.append("Mall room %s image does not exist: %s" % [id, image_path])
	if intro_text_keys.is_empty():
		errors.append("Mall room %s needs introduction text." % id)
	if category in [Category.CHALLENGE, Category.BOSS]:
		var expected_rounds := 2 if category == Category.BOSS else 1
		if challenge_rounds.size() != expected_rounds:
			errors.append("Challenge room %s needs exactly %d challenge rounds." % [
				id, expected_rounds,
			])
		for index in challenge_rounds.size():
			var round := challenge_round_at(index)
			if round == null:
				errors.append("Challenge room %s round %d is invalid." % [id, index])
				continue
			errors.append_array(round.validation_errors("Room %s round %d" % [id, index]))
		if category == Category.CHALLENGE and reward_item_id.is_empty():
			errors.append("Challenge room %s needs a reward item." % id)
		if category == Category.BOSS and not reward_item_id.is_empty():
			errors.append("Boss room %s cannot grant a room reward." % id)
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
	return errors
