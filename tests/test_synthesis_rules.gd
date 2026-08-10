extends GutTest


func test_one_persona_and_both_items_contribute_all_aspects() -> void:
	var base := _item(&"flower", [&"flower"], {
		&"lamp": 1,
		&"gauze": 1,
	})
	var fuel := _item(&"ribbon", [], {
		&"gauze": 2,
		&"mirror": 3,
	})
	var totals := SynthesisRules.aspect_totals(base, fuel, &"reverie", {
		&"reverie": 2,
		&"clarity": 20,
	})
	assert_eq(totals[&"gauze"], 5)
	assert_eq(totals[&"mirror"], 3)
	assert_eq(totals[&"lamp"], 1)
	assert_eq(totals[&"pillow"], 0)


func test_matching_candidate_is_gray_below_threshold_and_named_when_ready() -> void:
	var recipe := _recipe(&"rose", &"flower", &"gauze", 5)
	var flower := _item(&"flower", [&"flower"], {})
	var gray := SynthesisRules.evaluate_candidate(recipe, flower, {&"gauze": 3})
	assert_true(gray.is_visible)
	assert_false(gray.is_complete)
	assert_eq(gray.missing_aspects[&"gauze"], 2)
	var ready := SynthesisRules.evaluate_candidate(recipe, flower, {
		&"gauze": 5,
		&"lamp": 20,
	})
	assert_true(ready.is_complete)
	assert_eq(ready.output_id, &"rose")


func test_zero_corresponding_aspect_and_disabled_base_hide_candidates() -> void:
	var recipe := _recipe(&"rose", &"flower", &"gauze", 5)
	var flower := _item(&"flower", [&"flower"], {})
	assert_false(SynthesisRules.evaluate_candidate(recipe, flower, {&"gauze": 0}).is_visible)
	flower.can_be_synthesis_base = false
	assert_false(SynthesisRules.evaluate_candidate(recipe, flower, {&"gauze": 5}).is_visible)


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
	aspect: StringName,
	amount: int,
) -> SynthesisRecipeDefinition:
	var rule := CardSlotRule.new()
	rule.id = &"base"
	rule.required_all = [base_tag]
	var recipe := SynthesisRecipeDefinition.new()
	recipe.id = StringName("recipe_%s" % output_id)
	recipe.base_rule = rule
	recipe.required_aspects = {aspect: amount}
	recipe.output_id = output_id
	return recipe
