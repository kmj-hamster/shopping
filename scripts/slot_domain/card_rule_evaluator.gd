class_name CardRuleEvaluator
extends RefCounted


static func evaluate(rule: CardSlotRule, item: CardItemDefinition) -> Dictionary:
	var missing_required: Array[StringName] = []
	var allowed_matches: Array[StringName] = []
	var forbidden_matches: Array[StringName] = []
	var insufficient_values: Array[Dictionary] = []
	if rule == null or item == null:
		return {
			"can_place": false,
			"value_satisfied": false,
			"can_execute": false,
			"missing_required": missing_required,
			"allowed_matches": allowed_matches,
			"forbidden_matches": forbidden_matches,
			"insufficient_values": insufficient_values,
		}

	for tag in rule.required_all:
		if not item.has_property(tag):
			missing_required.append(tag)
	for tag in rule.allowed_any:
		if item.has_property(tag):
			allowed_matches.append(tag)
	for tag in rule.forbidden_any:
		if item.has_property(tag):
			forbidden_matches.append(tag)

	var can_place := (
		missing_required.is_empty()
		and (rule.allowed_any.is_empty() or not allowed_matches.is_empty())
		and forbidden_matches.is_empty()
	)
	for raw_requirement in rule.value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement == null:
			insufficient_values.append({"actual": 0, "minimum": 1, "tags": []})
			continue
		var actual := requirement.actual_value(item)
		if actual < requirement.minimum:
			insufficient_values.append({
				"mode": requirement.mode,
				"tags": requirement.tags.duplicate(),
				"actual": actual,
				"minimum": requirement.minimum,
			})
	var values_met := insufficient_values.is_empty()
	return {
		"can_place": can_place,
		"value_satisfied": values_met,
		"can_execute": can_place and values_met,
		"missing_required": missing_required,
		"allowed_matches": allowed_matches,
		"forbidden_matches": forbidden_matches,
		"insufficient_values": insufficient_values,
	}
