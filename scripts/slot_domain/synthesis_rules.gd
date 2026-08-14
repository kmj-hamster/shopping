class_name SynthesisRules
extends RefCounted


static func aspect_totals(
	base_item: CardItemDefinition,
	fuel_item: CardItemDefinition,
	selected_persona_id: StringName,
	protagonist_counts: Dictionary,
) -> Dictionary:
	var totals: Dictionary = {}
	for aspect in CardPropertySet.ASPECTS:
		totals[aspect] = 0
	for item in [base_item, fuel_item]:
		if item == null:
			continue
		for aspect in CardPropertySet.ASPECTS:
			totals[aspect] = int(totals[aspect]) + item.property_value(aspect)
	var persona_aspect := CardPropertySet.aspect_for_persona(selected_persona_id)
	if not persona_aspect.is_empty():
		totals[persona_aspect] = int(totals[persona_aspect]) + int(
			protagonist_counts.get(selected_persona_id, 0)
		)
	return totals


static func evaluate_candidate(
	recipe: SynthesisRecipeDefinition,
	base_item: CardItemDefinition,
	totals: Dictionary,
) -> Dictionary:
	if recipe == null or base_item == null or not base_item.can_be_synthesis_base:
		return _result(false, false, {}, &"")
	var base_evaluation := CardRuleEvaluator.evaluate(recipe.base_rule, base_item)
	if not base_evaluation.can_execute:
		return _result(false, false, {}, &"")
	var has_corresponding_aspects := true
	var requirements_met := true
	var missing: Dictionary = {}
	for raw_aspect in recipe.required_aspects:
		var aspect := StringName(raw_aspect)
		var required := recipe.required_value(aspect)
		var actual := int(totals.get(aspect, 0))
		has_corresponding_aspects = has_corresponding_aspects and actual > 0
		requirements_met = requirements_met and actual >= required
		if actual < required:
			missing[aspect] = required - actual
	return _result(
		has_corresponding_aspects,
		has_corresponding_aspects and requirements_met,
		missing,
		recipe.output_id,
	)


static func _result(
	is_visible: bool,
	is_complete: bool,
	missing_aspects: Dictionary,
	output_id: StringName,
) -> Dictionary:
	return {
		"is_visible": is_visible,
		"is_complete": is_complete,
		"missing_aspects": missing_aspects,
		"output_id": output_id,
	}
