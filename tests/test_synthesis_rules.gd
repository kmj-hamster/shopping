extends GutTest


func test_one_selected_persona_and_both_items_contribute_all_personas() -> void:
	var base := _item(&"flower", [&"flower"], {
		&"nightwalker": 1,
		&"dreamwalker": 1,
	})
	var helper := _item(&"ribbon", [], {
		&"dreamwalker": 2,
		&"mourner": 3,
	})
	var totals := SynthesisRules.persona_totals(base, helper, &"dreamwalker", {
		&"dreamwalker": 2,
		&"nightwalker": 20,
	})
	assert_eq(totals[&"dreamwalker"], 5)
	assert_eq(totals[&"mourner"], 3)
	assert_eq(totals[&"nightwalker"], 1)
	assert_eq(totals[&"homecomer"], 0)


func test_matching_candidate_is_gray_below_threshold_and_named_when_ready() -> void:
	var recipe := _recipe(&"rose", &"flower", &"dreamwalker", 5)
	var flower := _item(&"flower", [&"flower"], {})
	var gray := SynthesisRules.evaluate_candidate(recipe, flower, {&"dreamwalker": 1})
	assert_true(gray.is_visible)
	assert_false(gray.is_complete)
	assert_eq(gray.missing_personas[&"dreamwalker"], 4)
	var ready := SynthesisRules.evaluate_candidate(recipe, flower, {
		&"dreamwalker": 5,
		&"nightwalker": 20,
	})
	assert_true(ready.is_complete)
	assert_eq(ready.output_id, &"rose")


func test_type_match_stays_visible_with_zero_persona_but_disabled_base_is_hidden() -> void:
	var recipe := _recipe(&"rose", &"flower", &"dreamwalker", 5)
	var flower := _item(&"flower", [&"flower"], {})
	assert_true(SynthesisRules.evaluate_candidate(recipe, flower, {&"dreamwalker": 0}).is_visible)
	flower.can_be_synthesis_base = false
	assert_false(SynthesisRules.evaluate_candidate(recipe, flower, {&"dreamwalker": 5}).is_visible)


func _item(
	id: StringName,
	tags: Array[StringName],
	values: Dictionary,
) -> CardItemDefinition:
	var item := CardItemDefinition.new()
	item.id = id
	item.property_set = CardPropertySet.new()
	item.property_set.tags = tags
	item.property_set.values = values
	return item


func _recipe(
	output_id: StringName,
	base_tag: StringName,
	persona_id: StringName,
	amount: int,
) -> SynthesisRecipeDefinition:
	var rule := CardSlotRule.new()
	rule.id = &"base"
	rule.required_all = [base_tag]
	var recipe := SynthesisRecipeDefinition.new()
	recipe.id = StringName("recipe_%s" % output_id)
	recipe.base_rule = rule
	recipe.required_personas = {persona_id: amount}
	recipe.output_id = output_id
	return recipe
