class_name SynthesisRules
extends RefCounted


static func evaluate(
	recipe: SynthesisRecipeDefinition,
	inputs: Array[CardItemDefinition],
) -> Dictionary:
	var slot_results: Array[Dictionary] = []
	if recipe == null:
		return _result(false, slot_results, {}, &"", &"")
	for index in range(recipe.slot_rules.size()):
		var rule := recipe.slot_rules[index] as CardSlotRule
		var item := inputs[index] if index < inputs.size() else null
		slot_results.append(CardRuleEvaluator.evaluate(rule, item))
	var slots_satisfied := (
		inputs.size() == recipe.slot_rules.size()
		and slot_results.all(func(result: Dictionary) -> bool: return result.can_execute)
	)
	var aspect_totals: Dictionary = {}
	for aspect in recipe.compared_aspects:
		aspect_totals[aspect] = 0
	for item in inputs:
		if item == null:
			continue
		for aspect in recipe.compared_aspects:
			aspect_totals[aspect] = int(aspect_totals[aspect]) + item.property_value(aspect)
	var winner := _winner(recipe, aspect_totals)
	var output_id := recipe.output_for_aspect(winner) if not winner.is_empty() else &""
	return _result(
		slots_satisfied,
		slot_results,
		aspect_totals,
		output_id,
		recipe.preview_key_for_output(output_id),
	)


static func _winner(
	recipe: SynthesisRecipeDefinition,
	aspect_totals: Dictionary,
) -> StringName:
	if recipe.compared_aspects.size() != 2:
		return &""
	var first := recipe.compared_aspects[0]
	var second := recipe.compared_aspects[1]
	var first_value := int(aspect_totals.get(first, 0))
	var second_value := int(aspect_totals.get(second, 0))
	if first_value == second_value:
		return recipe.tie_winner
	return first if first_value > second_value else second


static func _result(
	is_complete: bool,
	slot_results: Array[Dictionary],
	aspect_totals: Dictionary,
	output_id: StringName,
	preview_key: StringName,
) -> Dictionary:
	return {
		"is_complete": is_complete,
		"slot_results": slot_results,
		"aspect_totals": aspect_totals,
		"output_id": output_id,
		"preview_key": preview_key,
	}
