class_name CardRuleEvaluator
extends RefCounted


static func can_place(rule: CardSlotRule, item: CardItemDefinition) -> bool:
	if rule == null or item == null:
		return false
	if item.id in rule.rejected_item_ids:
		return false
	if item.id in rule.accepted_item_ids:
		return true
	var has_property_route := not (
		rule.required_all.is_empty()
		and rule.allowed_any.is_empty()
		and rule.forbidden_any.is_empty()
	)
	if not rule.accepted_item_ids.is_empty() and not has_property_route:
		return false
	for tag in rule.required_all:
		if not item.has_property(tag):
			return false
	if not rule.allowed_any.is_empty():
		var matched_allowed := false
		for tag in rule.allowed_any:
			if item.has_property(tag):
				matched_allowed = true
				break
		if not matched_allowed:
			return false
	for tag in rule.forbidden_any:
		if item.has_property(tag):
			return false
	return true


static func can_execute(rule: CardSlotRule, item: CardItemDefinition) -> bool:
	if not can_place(rule, item):
		return false
	for raw_requirement in rule.value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement == null or not requirement.is_met(item):
			return false
	return true


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
			"item_id_allowed": false,
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

	var placement_allowed := can_place(rule, item)
	var has_property_route := not (
		rule.required_all.is_empty()
		and rule.allowed_any.is_empty()
		and rule.forbidden_any.is_empty()
	)
	for raw_requirement in rule.value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement == null:
			insufficient_values.append({"actual": 0, "minimum": 1, "tags": []})
			continue
		var actual := requirement.actual_value(item)
		if not requirement.is_met(item):
			insufficient_values.append({
				"mode": requirement.mode,
				"tags": requirement.tags.duplicate(),
				"actual": actual,
				"minimum": requirement.minimum,
			})
	var values_met := insufficient_values.is_empty()
	return {
		"can_place": placement_allowed,
		"value_satisfied": values_met,
		"can_execute": can_execute(rule, item),
		"missing_required": missing_required,
		"allowed_matches": allowed_matches,
		"forbidden_matches": forbidden_matches,
		"insufficient_values": insufficient_values,
		"item_id_allowed": (
			item.id not in rule.rejected_item_ids
			and (
				rule.accepted_item_ids.is_empty()
				or item.id in rule.accepted_item_ids
				or has_property_route
			)
		),
		"item_id_rejected": item.id in rule.rejected_item_ids,
	}
