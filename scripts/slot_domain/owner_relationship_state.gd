class_name OwnerRelationshipState
extends RefCounted

var owner_id: StringName
var experience := 0
var level := 0
var lifetime_spend := 0
var awarded_spend_experience := 0
var last_talk_day := 0
var completed_request_ids: Dictionary = {}
var flags: Dictionary = {}


func _init(selected_owner_id: StringName = &"") -> void:
	owner_id = selected_owner_id


func has_talked_today(day: int) -> bool:
	return last_talk_day == day


func record_daily_talk(
	day: int,
	definition: OwnerRelationshipDefinition,
) -> Dictionary:
	if has_talked_today(day):
		return _result(0, [])
	last_talk_day = day
	return add_experience(2, definition)


func record_spend(
	paid_amount: int,
	definition: OwnerRelationshipDefinition,
) -> Dictionary:
	lifetime_spend += maxi(0, paid_amount)
	var total_spend_experience := floori(lifetime_spend / 10.0)
	var gained := maxi(0, total_spend_experience - awarded_spend_experience)
	awarded_spend_experience = total_spend_experience
	return add_experience(gained, definition)


func complete_request(
	request_id: StringName,
	experience_reward: int,
	definition: OwnerRelationshipDefinition,
) -> Dictionary:
	if completed_request_ids.has(request_id):
		return _result(0, [])
	completed_request_ids[request_id] = true
	return add_experience(experience_reward, definition)


func add_experience(
	amount: int,
	definition: OwnerRelationshipDefinition,
) -> Dictionary:
	if amount <= 0 or definition == null:
		return _result(0, [])
	var previous_level := level
	experience += amount
	level = definition.level_for_experience(experience)
	var gained_levels: Array[int] = []
	for gained_level in range(previous_level + 1, level + 1):
		gained_levels.append(gained_level)
	return _result(amount, gained_levels)


func force_level(
	target_level: int,
	definition: OwnerRelationshipDefinition,
) -> Array[int]:
	if definition == null or target_level <= level:
		return []
	var previous_level := level
	level = clampi(target_level, 0, definition.level_thresholds.size() - 1)
	experience = maxi(experience, definition.threshold_for_level(level))
	var gained_levels: Array[int] = []
	for gained_level in range(previous_level + 1, level + 1):
		gained_levels.append(gained_level)
	return gained_levels


func _result(gained: int, gained_levels: Array[int]) -> Dictionary:
	return {
		"experience_gained": gained,
		"level": level,
		"level_ups": gained_levels,
	}
