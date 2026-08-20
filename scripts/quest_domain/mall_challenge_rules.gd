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
	var shape_totals: Dictionary = {}
	for shape_id in CardPropertySet.SHAPES:
		shape_totals[shape_id] = 0
	for definition in inputs:
		if definition == null:
			continue
		for shape_id in CardPropertySet.SHAPES:
			shape_totals[shape_id] = int(shape_totals[shape_id]) + (
				definition.property_value(shape_id)
			)
	var types_met := true
	for type_id in room.required_type_ids:
		if not inputs.any(func(definition: CardItemDefinition) -> bool:
			return definition != null and definition.has_property(type_id)
		):
			types_met = false
			break
	var shapes_met := true
	for shape_id in room.required_shape_ids:
		if int(shape_totals.get(shape_id, 0)) <= 0:
			shapes_met = false
			break
	var actual_total := 0
	for shape_id in room.required_shape_ids:
		actual_total += int(shape_totals.get(shape_id, 0))
	var categories_met := types_met and shapes_met
	var deficit := maxi(0, room.shape_total_required - actual_total)
	if not categories_met or deficit >= 3:
		return _result(
			FEEDBACK_HOPELESS, 0, deficit, types_met, shapes_met, shape_totals
		)
	if deficit == 2:
		return _result(FEEDBACK_MAYBE, 20, deficit, true, true, shape_totals)
	if deficit == 1:
		return _result(FEEDBACK_MAYBE, 50, deficit, true, true, shape_totals)
	return _result(FEEDBACK_ENOUGH, 100, deficit, true, true, shape_totals)


static func succeeds(evaluation: Dictionary, roll_percent: int) -> bool:
	return clampi(roll_percent, 0, 99) < int(evaluation.get("success_probability", 0))


static func is_protected(definition: CardItemDefinition) -> bool:
	if definition == null:
		return true
	if definition.has_property(CardPropertySet.PROPERTY_DISEASE):
		return true
	if definition.has_property(CardPropertySet.PROPERTY_KEEPSAKE):
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
	shapes_met: bool,
	shape_totals: Dictionary = {},
) -> Dictionary:
	return {
		"feedback_tier": tier,
		"success_probability": probability,
		"deficit": deficit,
		"types_met": types_met,
		"shapes_met": shapes_met,
		"shape_totals": shape_totals,
	}
