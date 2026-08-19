class_name MallChallengeRules
extends RefCounted

const FEEDBACK_ENOUGH := &"enough"
const FEEDBACK_MAYBE := &"maybe"
const FEEDBACK_HOPELESS := &"hopeless"


static func evaluate(
	room: MallRoomDefinition,
	inputs: Array[CardItemDefinition],
) -> Dictionary:
	if room == null or room.category not in [
		MallRoomDefinition.Category.CHALLENGE,
		MallRoomDefinition.Category.BOSS,
	]:
		return _result(FEEDBACK_HOPELESS, 0, 0, false, false)
	var persona_totals: Dictionary = {}
	for persona_id in CardPropertySet.PERSONAS:
		persona_totals[persona_id] = 0
	for definition in inputs:
		if definition == null:
			continue
		for persona_id in CardPropertySet.PERSONAS:
			persona_totals[persona_id] = int(persona_totals[persona_id]) + (
				definition.property_value(persona_id)
			)
	var types_met := true
	for type_id in room.required_type_ids:
		if not inputs.any(func(definition: CardItemDefinition) -> bool:
			return definition != null and definition.has_property(type_id)
		):
			types_met = false
			break
	var personas_met := true
	for persona_id in room.required_persona_ids:
		if int(persona_totals.get(persona_id, 0)) <= 0:
			personas_met = false
			break
	var actual_total := 0
	for persona_id in room.required_persona_ids:
		actual_total += int(persona_totals.get(persona_id, 0))
	var categories_met := types_met and personas_met
	var deficit := maxi(0, room.persona_total_required - actual_total)
	if not categories_met or deficit >= 3:
		return _result(
			FEEDBACK_HOPELESS, 0, deficit, types_met, personas_met, persona_totals
		)
	if deficit == 2:
		return _result(FEEDBACK_MAYBE, 20, deficit, true, true, persona_totals)
	if deficit == 1:
		return _result(FEEDBACK_MAYBE, 50, deficit, true, true, persona_totals)
	return _result(FEEDBACK_ENOUGH, 100, deficit, true, true, persona_totals)


static func succeeds(evaluation: Dictionary, roll_percent: int) -> bool:
	return clampi(roll_percent, 0, 99) < int(evaluation.get("success_probability", 0))


static func is_protected(definition: CardItemDefinition) -> bool:
	if definition == null:
		return true
	if definition.has_property(CardPropertySet.PROPERTY_PERSONA):
		return false
	var item := definition as QuestItemDefinition
	return item == null or item.is_map_key or item.is_story_item


static func can_use_in_challenge(definition: CardItemDefinition) -> bool:
	return definition != null and not is_protected(definition)


static func _result(
	tier: StringName,
	probability: int,
	deficit: int,
	types_met: bool,
	personas_met: bool,
	persona_totals: Dictionary = {},
) -> Dictionary:
	return {
		"feedback_tier": tier,
		"success_probability": probability,
		"deficit": deficit,
		"types_met": types_met,
		"personas_met": personas_met,
		"persona_totals": persona_totals,
	}
