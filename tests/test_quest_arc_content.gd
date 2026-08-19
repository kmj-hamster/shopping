extends GutTest

const EXPECTED_ITEM_IDS: Array[StringName] = [
	&"kaleidoscope", &"lotus_candle", &"mung_bean_cake", &"tin_frog", &"ratty_doll",
	&"milkshake", &"fruit_wine", &"fries", &"nuggets",
	&"jasmine", &"camellia", &"cactus", &"foam_fake_flower", &"gardenia",
	&"candy_fake_flower", &"goldberg_variations", &"debussy_clair_de_lune",
	&"conservatory_story", &"nocturne_competition_recording", &"concrete_city_vol_1",
	&"mirror_and_lamp", &"ufo_exploration_magazine", &"mania_manga",
	&"cold_teddy_bear", &"baby_soothing_bear", &"birthday_cake", &"cola", &"rose",
]

const EXPECTED_PERSONA_LEVELS := {
	&"nightwalker": 1,
	&"mourner": 3,
	&"dreamwalker": 5,
	&"homecomer": 3,
}


func test_manifest_is_the_live_content_whitelist_without_test_cards() -> void:
	var manifest := QuestArcCatalog.manifest()
	assert_not_null(manifest)
	assert_eq(manifest.initial_money, 0)
	assert_true(manifest.starting_item_ids.is_empty())
	assert_eq(manifest.maximum_item_price, 84)
	assert_eq(manifest.properties.size(), 14)
	assert_eq(manifest.items.size(), EXPECTED_ITEM_IDS.size())
	assert_eq(manifest.tasks.size(), 30)
	assert_eq(manifest.recipes.size(), 5)
	assert_eq(manifest.stores.size(), 5)
	assert_eq(manifest.store_unlocks.size(), 5)
	assert_eq(manifest.owners.size(), 3)
	for persona_id in CardPropertySet.PERSONAS:
		assert_eq(
			int(manifest.initial_protagonist_stats.get(persona_id, -1)),
			int(EXPECTED_PERSONA_LEVELS[persona_id]),
		)
	var actual_ids: Array[StringName] = []
	for raw_item in manifest.items:
		var item := raw_item as QuestItemDefinition
		assert_not_null(item)
		actual_ids.append(item.id)
		assert_null(item.image, item.id)
		assert_false(String(item.id).begins_with("test_"), item.id)
	actual_ids.sort()
	var expected_ids := EXPECTED_ITEM_IDS.duplicate()
	expected_ids.sort()
	assert_eq(actual_ids, expected_ids)
	assert_true(manifest.validation_errors().is_empty(), str(manifest.validation_errors()))


func test_retail_cards_match_the_declared_prices_types_and_personas() -> void:
	_assert_item(&"kaleidoscope", 20, [&"toy"], {&"dreamwalker": 2, &"nightwalker": 2})
	_assert_item(&"lotus_candle", 40, [&"toy"], {&"mourner": 3})
	_assert_item(&"mung_bean_cake", 8, [&"food"], {&"mourner": 1})
	_assert_item(&"tin_frog", 8, [&"toy"], {&"nightwalker": 1})
	_assert_item(&"ratty_doll", 18, [&"toy"], {&"homecomer": 2, &"mourner": 1})
	_assert_item(&"milkshake", 16, [&"drink"], {&"homecomer": 2})
	_assert_item(&"fruit_wine", 42, [&"drink"], {&"dreamwalker": 1, &"homecomer": 3})
	_assert_item(&"fries", 8, [&"food"], {&"homecomer": 1})
	_assert_item(&"nuggets", 18, [&"food"], {&"dreamwalker": 2, &"homecomer": 1})
	_assert_item(&"jasmine", 8, [&"flower"], {&"homecomer": 1})
	_assert_item(&"camellia", 16, [&"flower"], {&"mourner": 2})
	_assert_item(&"cactus", 16, [&"flower"], {&"nightwalker": 2})
	_assert_item(&"foam_fake_flower", 10, [&"flower", &"toy"], {&"dreamwalker": 1, &"mourner": 1})
	_assert_item(&"gardenia", 24, [&"flower"], {&"dreamwalker": 2, &"homecomer": 2})
	_assert_item(&"candy_fake_flower", 40, [&"flower", &"food"], {&"dreamwalker": 3})
	_assert_item(&"goldberg_variations", 20, [&"cassette"], {&"homecomer": 2, &"nightwalker": 2})
	_assert_item(&"debussy_clair_de_lune", 80, [&"cassette"], {&"dreamwalker": 4})
	_assert_item(&"conservatory_story", 16, [&"book"], {&"dreamwalker": 2})
	_assert_item(&"nocturne_competition_recording", 12, [&"cassette"], {&"dreamwalker": 2, &"mourner": 3})
	_assert_item(&"concrete_city_vol_1", 84, [&"book"], {&"dreamwalker": 1, &"nightwalker": 4})
	_assert_item(&"mirror_and_lamp", 40, [&"book"], {&"nightwalker": 3})
	_assert_item(&"ufo_exploration_magazine", 18, [&"book"], {&"dreamwalker": 1, &"nightwalker": 2})
	_assert_item(&"mania_manga", 10, [&"book"], {&"dreamwalker": 1, &"mourner": 1})
	assert_eq(
		QuestArcCatalog.item_by_id(&"nocturne_competition_recording").supply_mode,
		QuestItemDefinition.SupplyMode.FINITE_ONCE,
	)
	assert_eq(
		QuestArcCatalog.item_by_id(&"concrete_city_vol_1").supply_mode,
		QuestItemDefinition.SupplyMode.FINITE_ONCE,
	)
	for locked_item_id in [&"gardenia", &"candy_fake_flower"]:
		assert_eq(
			QuestArcCatalog.item_by_id(locked_item_id).supply_mode,
			QuestItemDefinition.SupplyMode.EVENT_ONLY,
		)


func test_shelves_are_three_by_two_with_declared_duplicates_and_reserved_flower_slots() -> void:
	_assert_shelf(&"toy", [
		&"kaleidoscope", &"lotus_candle", &"mung_bean_cake",
		&"tin_frog", &"ratty_doll", &"mung_bean_cake",
	])
	_assert_shelf(&"fast_food", [
		&"milkshake", &"fruit_wine", &"fries", &"fries", &"milkshake", &"nuggets",
	])
	_assert_shelf(&"flower", [
		&"jasmine", &"camellia", &"cactus", &"foam_fake_flower",
	])
	_assert_shelf(&"record", [
		&"goldberg_variations", &"debussy_clair_de_lune", &"conservatory_story",
		&"nocturne_competition_recording",
	])
	_assert_shelf(&"bookstore", [
		&"concrete_city_vol_1", &"mirror_and_lamp", &"ufo_exploration_magazine",
		&"mania_manga", &"mania_manga",
	])
	var state := QuestGameState.new()
	var flower_slots := state.transaction_for_store(&"flower").shelf_slots
	assert_eq(flower_slots.size(), 6)
	assert_true(flower_slots[4].is_empty())
	assert_true(flower_slots[5].is_empty())


func test_five_live_recipes_match_requirements_outputs_and_resale_values() -> void:
	var cases := [
		[&"recipe_cold_teddy_bear", &"toy", {&"mourner": 5}, &"cold_teddy_bear", [&"toy"], {&"mourner": 3}, 20, &"lotus_candle", &"", &"mourner"],
		[&"recipe_baby_soothing_bear", &"toy", {&"homecomer": 5}, &"baby_soothing_bear", [&"toy"], {&"homecomer": 3}, 20, &"ratty_doll", &"", &"homecomer"],
		[&"recipe_birthday_cake", &"food", {&"mourner": 7}, &"birthday_cake", [&"food"], {&"mourner": 4}, 40, &"mung_bean_cake", &"lotus_candle", &"mourner"],
		[&"recipe_cola", &"drink", {&"homecomer": 7}, &"cola", [&"drink"], {&"homecomer": 4}, 40, &"fruit_wine", &"ratty_doll", &"homecomer"],
		[&"recipe_rose", &"flower", {&"dreamwalker": 3}, &"rose", [&"flower"], {&"dreamwalker": 2}, 8, &"jasmine", &"", &"dreamwalker"],
	]
	for test_case in cases:
		var recipe := QuestArcCatalog.recipe_by_id(test_case[0])
		var output := QuestArcCatalog.item_by_id(test_case[3])
		assert_not_null(recipe)
		assert_eq(recipe.base_rule.required_all, [test_case[1]], recipe.id)
		assert_eq(recipe.required_personas, test_case[2], recipe.id)
		assert_eq(recipe.output_id, test_case[3], recipe.id)
		assert_eq(output.property_set.tags, test_case[4], output.id)
		assert_eq(output.property_set.values, test_case[5], output.id)
		assert_true(output.is_crafted, output.id)
		assert_true(output.can_recycle, output.id)
		assert_eq(output.resale_value(), test_case[6], output.id)
		var base := QuestArcCatalog.item_by_id(test_case[7])
		var helper := (
			QuestArcCatalog.item_by_id(test_case[8])
			if not (test_case[8] as StringName).is_empty()
			else null
		)
		var totals := SynthesisRules.persona_totals(
			base,
			helper,
			test_case[9],
			EXPECTED_PERSONA_LEVELS,
		)
		assert_true(SynthesisRules.evaluate_candidate(recipe, base, totals).is_complete, recipe.id)


func test_store_unlocks_use_items_or_non_consuming_personas() -> void:
	var toy_unlock := QuestArcCatalog.store_unlock_for_store(&"toy")
	assert_true(QuestArcRules.store_unlock_accepts(toy_unlock, QuestArcCatalog.item_by_id(&"tin_frog")))
	assert_true(toy_unlock.consume_item)
	var record_unlock := QuestArcCatalog.store_unlock_for_store(&"record")
	assert_true(QuestArcRules.store_unlock_accepts(record_unlock, QuestArcCatalog.item_by_id(&"rose")))
	assert_false(QuestArcRules.store_unlock_accepts(record_unlock, QuestArcCatalog.item_by_id(&"jasmine")))
	assert_false(QuestArcCatalog.store_unlock_for_store(&"flower").consume_item)
	assert_false(QuestArcCatalog.store_unlock_for_store(&"bookstore").consume_item)


func test_live_rose_recipe_consumes_its_base_and_creates_the_declared_output() -> void:
	var state := QuestGameState.new()
	var jasmine := state.grant_item(&"jasmine", &"test")
	assert_true(state.assign_synthesis_base(jasmine).ok)
	assert_true(state.select_synthesis_persona(&"dreamwalker"))
	assert_true(state.select_synthesis_candidate(&"recipe_rose"))
	var result := state.begin_synthesis()
	assert_true(result.ok)
	assert_null(state.card_by_instance_id(jasmine.instance_id))
	assert_eq((result.output as CardItemState).definition_id, &"rose")


func test_finite_shelf_cards_do_not_return_on_their_store_restock_day() -> void:
	var state := QuestGameState.new()
	var record_slot := state.transaction_for_store(&"record").shelf_slots[3]
	var book_slot := state.transaction_for_store(&"bookstore").shelf_slots[0]
	record_slot.clear()
	book_slot.clear()
	state.refill_scheduled_shelves(4)
	state.refill_scheduled_shelves(5)
	assert_true(record_slot.is_empty())
	assert_true(book_slot.is_empty())


func test_new_game_starts_without_test_items_but_keeps_four_personas() -> void:
	var state := QuestGameState.new()
	assert_eq(state.wallet.money, 0)
	assert_true(state.inventory.is_empty())
	assert_true(state.unlocked_store_ids.is_empty())
	assert_eq(state.active_tasks().size(), 6)
	assert_not_null(state.task_instance_for_definition(&"remittance"))
	assert_not_null(state.task_instance_for_definition(&"tin_boy_gift"))
	for index in 4:
		assert_not_null(state.task_instance_for_definition(StringName("debug_todo_page_%d" % (index + 1))))
	assert_null(state.task_instance_for_definition(&"self_care"))
	for persona_id in CardPropertySet.PERSONAS:
		assert_eq(
			int(state.protagonist_persona_counts.get(persona_id, -1)),
			int(EXPECTED_PERSONA_LEVELS[persona_id]),
		)


func test_store_restock_phases_are_staggered() -> void:
	assert_true(QuestArcCatalog.store_by_id(&"toy").is_restock_day(1))
	assert_true(QuestArcCatalog.store_by_id(&"fast_food").is_restock_day(2))
	assert_true(QuestArcCatalog.store_by_id(&"flower").is_restock_day(3))
	assert_eq(QuestArcCatalog.store_by_id(&"toy").nights_until_restock(1), 3)
	assert_eq(QuestArcCatalog.store_by_id(&"fast_food").nights_until_restock(1), 1)
	assert_eq(QuestArcCatalog.store_by_id(&"flower").nights_until_restock(1), 2)


func test_archived_demo_manifest_remains_valid_for_legacy_argument() -> void:
	var legacy := load(QuestArcCatalog.LEGACY_MANIFEST_PATH) as GameContentManifest
	assert_not_null(legacy)
	assert_true(legacy.validation_errors().is_empty(), str(legacy.validation_errors()))


func _assert_item(
	item_id: StringName,
	price: int,
	tags: Array[StringName],
	values: Dictionary,
) -> void:
	var item := QuestArcCatalog.item_by_id(item_id)
	assert_not_null(item, item_id)
	assert_eq(item.base_price, price, item_id)
	assert_eq(item.property_set.tags, tags, item_id)
	assert_eq(item.property_set.values, values, item_id)


func _assert_shelf(store_id: StringName, expected_item_ids: Array) -> void:
	var store := QuestArcCatalog.store_by_id(store_id)
	assert_not_null(store)
	assert_eq(store.initial_capacity, 6, store_id)
	assert_eq(store.initial_shelf_item_ids, expected_item_ids, store_id)
