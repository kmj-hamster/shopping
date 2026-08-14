class_name SynthesisRules
extends RefCounted


static func persona_totals(
	base_item: CardItemDefinition,
	helper_item: CardItemDefinition,
	selected_persona_id: StringName,
	protagonist_counts: Dictionary,
) -> Dictionary:
	var totals: Dictionary = {}
	for persona_id in CardPropertySet.PERSONAS:
		totals[persona_id] = 0
	for item in [base_item, helper_item]:
		if item == null:
			continue
		for persona_id in CardPropertySet.PERSONAS:
			totals[persona_id] = int(totals[persona_id]) + item.property_value(persona_id)
	if selected_persona_id in CardPropertySet.PERSONAS:
		totals[selected_persona_id] = int(totals[selected_persona_id]) + int(
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
	var requirements_met := true
	var missing: Dictionary = {}
	for raw_persona in recipe.required_personas:
		var persona_id := StringName(raw_persona)
		var required := recipe.required_value(persona_id)
		var actual := int(totals.get(persona_id, 0))
		requirements_met = requirements_met and actual >= required
		if actual < required:
			missing[persona_id] = required - actual
	return _result(
		true,
		requirements_met,
		missing,
		recipe.output_id,
	)


static func _result(
	is_visible: bool,
	is_complete: bool,
	missing_personas: Dictionary,
	output_id: StringName,
) -> Dictionary:
	return {
		"is_visible": is_visible,
		"is_complete": is_complete,
		"missing_personas": missing_personas,
		"output_id": output_id,
	}
