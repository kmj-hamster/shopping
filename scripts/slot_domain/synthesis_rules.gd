class_name SynthesisRules
extends RefCounted


static func shape_totals(
	base_item: CardItemDefinition,
	helper_item: CardItemDefinition,
	selected_shape_id: StringName,
	protagonist_shape_levels: Dictionary,
) -> Dictionary:
	var totals: Dictionary = {}
	for shape_id in CardPropertySet.SHAPES:
		totals[shape_id] = 0
	for item in [base_item, helper_item]:
		if item == null:
			continue
		for shape_id in CardPropertySet.SHAPES:
			totals[shape_id] = int(totals[shape_id]) + item.property_value(shape_id)
	if selected_shape_id in CardPropertySet.SHAPES:
		totals[selected_shape_id] = int(totals[selected_shape_id]) + int(
			protagonist_shape_levels.get(selected_shape_id, 0)
		)
	return totals


static func evaluate_candidate(
	recipe: SynthesisRecipeDefinition,
	base_item: CardItemDefinition,
	totals: Dictionary,
	required_shapes: Dictionary = {},
) -> Dictionary:
	if recipe == null or base_item == null or not base_item.can_be_synthesis_base:
		return _result(false, false, {}, &"")
	var base_evaluation := CardRuleEvaluator.evaluate(recipe.base_rule, base_item)
	if not base_evaluation.can_execute:
		return _result(false, false, {}, &"")
	var requirements_met := true
	var missing: Dictionary = {}
	var effective_requirements := (
		required_shapes if not required_shapes.is_empty() else recipe.required_shapes
	)
	for raw_shape in effective_requirements:
		var shape_id := StringName(raw_shape)
		var required := int(effective_requirements[raw_shape])
		var actual := int(totals.get(shape_id, 0))
		requirements_met = requirements_met and actual >= required
		if actual < required:
			missing[shape_id] = required - actual
	return _result(
		true,
		requirements_met,
		missing,
		recipe.output_id,
	)


static func _result(
	is_visible: bool,
	is_complete: bool,
	missing_shapes: Dictionary,
	output_id: StringName,
) -> Dictionary:
	return {
		"is_visible": is_visible,
		"is_complete": is_complete,
		"missing_shapes": missing_shapes,
		"output_id": output_id,
	}
