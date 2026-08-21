class_name MallChallengeRules
extends RefCounted

const FEEDBACK_ENOUGH := &"enough"
const FEEDBACK_MAYBE := &"maybe"
const FEEDBACK_HOPELESS := &"hopeless"


static func evaluate(
	approach: MallChallengeApproachDefinition,
	inputs: Array[CardItemDefinition],
	persona_shape_ids: Array[StringName] = [],
) -> Dictionary:
	if approach == null:
		return _result(FEEDBACK_HOPELESS, 0, 0, false, false, false)
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
	for type_id in approach.required_all_type_ids:
		if not inputs.any(func(definition: CardItemDefinition) -> bool:
			return definition != null and definition.has_property(type_id)
		):
			types_met = false
			break
	if types_met and not approach.required_any_type_ids.is_empty():
		types_met = approach.required_any_type_ids.any(
			func(type_id: StringName) -> bool:
				return inputs.any(func(definition: CardItemDefinition) -> bool:
					return definition != null and definition.has_property(type_id)
				)
		)
	var persona_met := (
		approach.required_persona_shape_id.is_empty()
		or approach.required_persona_shape_id in persona_shape_ids
	)
	var shapes_met := true
	for shape_id in approach.required_shape_ids:
		if int(shape_totals.get(shape_id, 0)) <= 0:
			shapes_met = false
			break
	var actual_total := 0
	for shape_id in approach.required_shape_ids:
		actual_total += int(shape_totals.get(shape_id, 0))
	var categories_met := types_met and persona_met and shapes_met
	var deficit := maxi(0, approach.shape_total_required - actual_total)
	var feedback_shape_id := _feedback_shape(approach, shape_totals, deficit)
	if not categories_met or deficit >= 3:
		return _result(
			FEEDBACK_HOPELESS,
			0,
			deficit,
			types_met,
			shapes_met,
			persona_met,
			shape_totals,
			feedback_shape_id,
		)
	if deficit == 2:
		return _result(
			FEEDBACK_MAYBE, 20, deficit, true, true, true, shape_totals, feedback_shape_id
		)
	if deficit == 1:
		return _result(
			FEEDBACK_MAYBE, 50, deficit, true, true, true, shape_totals, feedback_shape_id
		)
	return _result(
		FEEDBACK_ENOUGH, 100, deficit, true, true, true, shape_totals, feedback_shape_id
	)


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


static func _feedback_shape(
	approach: MallChallengeApproachDefinition,
	shape_totals: Dictionary,
	deficit: int,
) -> StringName:
	for shape_id in approach.required_shape_ids:
		if int(shape_totals.get(shape_id, 0)) <= 0:
			return shape_id
	if deficit > 0 and not approach.required_shape_ids.is_empty():
		var lowest_shape := approach.required_shape_ids[0]
		for shape_id in approach.required_shape_ids:
			if int(shape_totals.get(shape_id, 0)) < int(shape_totals.get(lowest_shape, 0)):
				lowest_shape = shape_id
		return lowest_shape
	if not approach.feedback_primary_shape_id.is_empty():
		return approach.feedback_primary_shape_id
	return approach.required_shape_ids[0] if not approach.required_shape_ids.is_empty() else &"light"


static func _result(
	tier: StringName,
	probability: int,
	deficit: int,
	types_met: bool,
	shapes_met: bool,
	persona_met: bool,
	shape_totals: Dictionary = {},
	feedback_shape_id: StringName = &"light",
) -> Dictionary:
	return {
		"feedback_tier": tier,
		"success_probability": probability,
		"deficit": deficit,
		"types_met": types_met,
		"shapes_met": shapes_met,
		"persona_met": persona_met,
		"required_inputs_met": types_met and persona_met,
		"shape_totals": shape_totals,
		"feedback_shape_id": feedback_shape_id,
	}
