extends GutTest


func test_one_selected_persona_and_both_items_contribute_all_shapes() -> void:
	var base := _item(&"flower", [&"flower"], {
		&"light": 1,
		&"dream": 1,
	})
	var helper := _item(&"ribbon", [], {
		&"dream": 2,
		&"tear": 3,
	})
	var totals := SynthesisRules.shape_totals(base, helper, &"dream", {
		&"dream": 2,
		&"light": 20,
	})
	assert_eq(totals[&"dream"], 5)
	assert_eq(totals[&"tear"], 3)
	assert_eq(totals[&"light"], 1)
	assert_eq(totals[&"sleep"], 0)


func test_matching_candidate_is_gray_below_threshold_and_named_when_ready() -> void:
	var recipe := _recipe(&"rose", &"flower", &"dream", 5)
	var flower := _item(&"flower", [&"flower"], {})
	var gray := SynthesisRules.evaluate_candidate(recipe, flower, {&"dream": 1})
	assert_true(gray.is_visible)
	assert_false(gray.is_complete)
	assert_eq(gray.missing_shapes[&"dream"], 4)
	var ready := SynthesisRules.evaluate_candidate(recipe, flower, {
		&"dream": 5,
		&"light": 20,
	})
	assert_true(ready.is_complete)
	assert_eq(ready.output_id, &"rose")


func test_type_match_stays_visible_with_zero_persona_but_disabled_base_is_hidden() -> void:
	var recipe := _recipe(&"rose", &"flower", &"dream", 5)
	var flower := _item(&"flower", [&"flower"], {})
	assert_true(SynthesisRules.evaluate_candidate(recipe, flower, {&"dream": 0}).is_visible)
	flower.can_be_synthesis_base = false
	assert_false(SynthesisRules.evaluate_candidate(recipe, flower, {&"dream": 5}).is_visible)


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
	shape_id: StringName,
	amount: int,
) -> SynthesisRecipeDefinition:
	var rule := CardSlotRule.new()
	rule.id = &"base"
	rule.required_all = [base_tag]
	var recipe := SynthesisRecipeDefinition.new()
	recipe.id = StringName("recipe_%s" % output_id)
	recipe.base_rule = rule
	recipe.required_shapes = {shape_id: amount}
	recipe.output_id = output_id
	return recipe
