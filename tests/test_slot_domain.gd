extends GutTest


func test_catalog_loads_complete_valid_content() -> void:
	var retail := SlotDemoCatalog.retail_items()
	var crafted := SlotDemoCatalog.crafted_items()
	var wishes := SlotDemoCatalog.wishes()
	var recipes := SlotDemoCatalog.recipes()
	var owners := SlotDemoCatalog.owners()
	var requests := SlotDemoCatalog.requests()
	assert_eq(retail.size(), 12)
	assert_eq(crafted.size(), 4)
	assert_eq(wishes.size(), 6)
	assert_eq(recipes.size(), 2)
	assert_eq(owners.size(), 1)
	assert_eq(requests.size(), 1)
	assert_eq(_unique_ids(retail).size(), 12)
	assert_eq(_unique_ids(crafted).size(), 4)
	assert_eq(_unique_ids(wishes).size(), 6)
	assert_eq(_unique_ids(recipes).size(), 2)
	assert_eq(_unique_ids(owners).size(), 1)
	assert_eq(_unique_ids(requests).size(), 1)
	for definition in retail + crafted + wishes + recipes + owners + requests:
		assert_true(definition.validation_errors().is_empty(), "%s: %s" % [definition.id, definition.validation_errors()])


func test_retail_prices_weights_and_unlock_are_data_driven() -> void:
	var expected := {
		&"book_bedtime_clipping": [&"book", 16, 3],
		&"book_aquarium_issue": [&"book", 18, 1],
		&"record_lullaby_cassette": [&"record", 24, 2],
		&"record_fluorescent_single": [&"record", 18, 3],
		&"flower_sunflower": [&"flower", 20, 3],
		&"flower_lavender_sachet": [&"flower", 26, 1],
		&"flower_night_jasmine": [&"flower", 22, 2],
		&"toy_cloth_scraps": [&"toy", 12, 3],
		&"toy_glass_marble": [&"toy", 14, 2],
		&"toy_windup_moth": [&"toy", 22, 1],
		&"fast_warm_milk": [&"fast_food", 14, 2],
		&"fast_hash_brown": [&"fast_food", 12, 3],
	}
	for item in SlotDemoCatalog.retail_items():
		assert_eq([item.store_id, item.base_price, item.restock_weight], expected[item.id], String(item.id))
		for value in item.property_set.values.values():
			assert_between(int(value), 1, 8, String(item.id))
	var moth := SlotDemoCatalog.item_by_id(&"toy_windup_moth")
	assert_eq(moth.unlock_owner_id, &"balloon")
	assert_eq(moth.unlock_level, 1)
	assert_eq(moth.shelf_page, 2)


func test_item_instances_and_shelf_slots_are_independent() -> void:
	var first := ShelfSlotState.new(&"fast_food", &"slot_1", &"fast_hash_brown")
	var second := ShelfSlotState.new(&"fast_food", &"slot_2", &"fast_hash_brown")
	first.clear()
	assert_true(first.is_empty())
	assert_eq(second.item_id, &"fast_hash_brown")

	var card := CardItemState.new(17, &"fast_hash_brown", 2, &"shop")
	card.assign_to(&"wish_hungry", &"hungry")
	assert_eq(card.location, CardItemState.Location.ACTIVITY_SLOT)
	card.return_to_hand()
	assert_eq(card.location, CardItemState.Location.HAND)
	assert_true(card.activity_id.is_empty())
	assert_true(card.slot_id.is_empty())


func test_placement_and_value_threshold_are_separate() -> void:
	var awake := SlotDemoCatalog.wish_by_id(&"wish_stay_awake")
	var hash_brown := SlotDemoCatalog.item_by_id(&"fast_hash_brown")
	var result := CardRuleEvaluator.evaluate(awake.slot_rule, hash_brown)
	assert_true(result.can_place)
	assert_false(result.value_satisfied)
	assert_false(result.can_execute)
	assert_eq(result.insufficient_values[0].actual, 2)
	assert_eq(result.insufficient_values[0].minimum, 3)

	var milk := SlotDemoCatalog.item_by_id(&"fast_warm_milk")
	result = CardRuleEvaluator.evaluate(awake.slot_rule, milk)
	assert_false(result.can_place)
	assert_true(&"sleep_aid" in result.forbidden_matches)


func test_every_executable_wish_item_has_specific_result_copy() -> void:
	for wish in SlotDemoCatalog.wishes():
		for item in SlotDemoCatalog.all_items():
			var can_execute: bool = CardRuleEvaluator.evaluate(wish.slot_rule, item).can_execute
			var has_result := not wish.result_key_for(item.id).is_empty()
			assert_eq(has_result, can_execute, "%s + %s" % [wish.id, item.id])


func test_teddy_recipe_selects_mirror_or_pillow_output() -> void:
	var recipe := SlotDemoCatalog.recipe_by_id(&"recipe_teddy")
	var mirror_inputs: Array[CardItemDefinition] = [
		SlotDemoCatalog.item_by_id(&"toy_cloth_scraps"),
		SlotDemoCatalog.item_by_id(&"toy_glass_marble"),
		SlotDemoCatalog.item_by_id(&"record_lullaby_cassette"),
	]
	var result := SynthesisRules.evaluate(recipe, mirror_inputs)
	assert_true(result.is_complete)
	assert_eq(result.output_id, &"craft_childhood_teddy")
	assert_eq(result.preview_key, &"slot.recipe.teddy.preview.childhood")

	var pillow_inputs: Array[CardItemDefinition] = [
		SlotDemoCatalog.item_by_id(&"toy_cloth_scraps"),
		SlotDemoCatalog.item_by_id(&"toy_cloth_scraps"),
		SlotDemoCatalog.item_by_id(&"fast_warm_milk"),
	]
	result = SynthesisRules.evaluate(recipe, pillow_inputs)
	assert_true(result.is_complete)
	assert_eq(result.output_id, &"craft_comfort_bear")
	assert_eq(recipe.tie_winner, &"pillow")


func test_night_radio_recipe_selects_lamp_or_candle_output() -> void:
	var recipe := SlotDemoCatalog.recipe_by_id(&"recipe_night_radio")
	var lamp_inputs: Array[CardItemDefinition] = [
		SlotDemoCatalog.item_by_id(&"record_fluorescent_single"),
		SlotDemoCatalog.item_by_id(&"toy_glass_marble"),
		SlotDemoCatalog.item_by_id(&"fast_hash_brown"),
	]
	var result := SynthesisRules.evaluate(recipe, lamp_inputs)
	assert_true(result.is_complete)
	assert_eq(result.output_id, &"craft_clear_receiver")

	var candle_inputs: Array[CardItemDefinition] = [
		SlotDemoCatalog.item_by_id(&"record_lullaby_cassette"),
		SlotDemoCatalog.item_by_id(&"toy_glass_marble"),
		SlotDemoCatalog.item_by_id(&"book_aquarium_issue"),
	]
	result = SynthesisRules.evaluate(recipe, candle_inputs)
	assert_true(result.is_complete)
	assert_eq(result.output_id, &"craft_tide_receiver")
	assert_eq(recipe.tie_winner, &"lamp")


func _unique_ids(definitions: Array) -> Dictionary:
	var ids := {}
	for definition in definitions:
		ids[definition.id] = true
	return ids
