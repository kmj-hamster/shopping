extends GutTest

const TEST_STARTING_IDS: Array[StringName] = [
	&"fries",
	&"plastic_car",
	&"midnight_rose",
	&"test_late_train_timetable",
	&"test_blank_disc",
	&"test_rewound_tape",
	&"test_clockwork_moon",
	&"test_cold_pudding",
	&"test_paper_cup_water",
	&"test_pressed_violet",
	&"test_birthday_candle",
	&"test_inside_out_raincoat",
]

const TEST_PERSONA_LEVELS := {
	&"nightwalker": 1,
	&"mourner": 3,
	&"dreamwalker": 5,
	&"homecomer": 3,
}


func test_manifest_is_the_new_opening_whitelist() -> void:
	var manifest := QuestArcCatalog.manifest()
	assert_not_null(manifest)
	assert_eq(manifest.initial_money, 0)
	assert_eq(
		manifest.starting_item_ids,
		TEST_STARTING_IDS,
	)
	assert_eq(manifest.maximum_item_price, 40)
	assert_eq(manifest.properties.size(), 16)
	assert_eq(manifest.items.size(), 32)
	assert_eq(manifest.tasks.size(), 9)
	assert_eq(manifest.recipes.size(), 10)
	assert_eq(manifest.stores.size(), 5)
	assert_eq(manifest.store_unlocks.size(), 5)
	assert_eq(manifest.owners.size(), 3)
	for persona_id in CardPropertySet.PERSONAS:
		assert_eq(
			int(manifest.initial_protagonist_stats.get(persona_id, -1)),
			int(TEST_PERSONA_LEVELS[persona_id]),
		)
	assert_true(manifest.validation_errors().is_empty(), str(manifest.validation_errors()))


func test_opening_items_keep_images_and_generated_synthesis_cards_use_no_icons() -> void:
	var expected_ids: Array[StringName] = [
		&"plastic_car", &"kaleidoscope", &"lotus_candle", &"mung_bean_cake",
		&"milkshake", &"cola", &"fries", &"nuggets",
		&"jasmine", &"gardenia", &"cactus", &"plastic_orchid",
		&"tin_frog", &"midnight_rose",
		&"test_late_train_timetable", &"test_blank_disc", &"test_rewound_tape",
		&"test_clockwork_moon", &"test_cold_pudding", &"test_paper_cup_water",
		&"test_pressed_violet", &"test_birthday_candle", &"test_inside_out_raincoat",
		&"test_unborrowed_atlas", &"test_four_am_live", &"test_unsent_message",
		&"test_blinking_satellite", &"test_counterclockwise_pudding",
		&"test_waiting_room_soda", &"test_echo_violet", &"test_countdown_candle",
		&"test_bedtime_overcoat",
	]
	var actual_ids: Array[StringName] = []
	for raw_item in QuestArcCatalog.manifest().items:
		var item := raw_item as QuestItemDefinition
		assert_not_null(item)
		actual_ids.append(item.id)
		if String(item.id).begins_with("test_"):
			assert_null(item.image, String(item.id))
		else:
			assert_not_null(item.image, String(item.id))
	actual_ids.sort()
	expected_ids.sort()
	assert_eq(actual_ids, expected_ids)
	assert_null(QuestArcCatalog.item_by_id(&"toy_block"))
	assert_null(QuestArcCatalog.store_by_id(&"recycling"))


func test_generated_recipes_cover_every_requested_type_and_are_craftable() -> void:
	var cases := {
		&"book": [&"recipe_test_unborrowed_atlas", &"test_late_train_timetable", &"test_birthday_candle", &""],
		&"cd": [&"recipe_test_four_am_live", &"test_blank_disc", &"", &"dreamwalker"],
		&"cassette": [&"recipe_test_unsent_message", &"test_rewound_tape", &"", &"mourner"],
		&"toy": [&"recipe_test_blinking_satellite", &"test_clockwork_moon", &"test_birthday_candle", &"dreamwalker"],
		&"food": [&"recipe_test_counterclockwise_pudding", &"test_cold_pudding", &"", &"homecomer"],
		&"drink": [&"recipe_test_waiting_room_soda", &"test_paper_cup_water", &"test_clockwork_moon", &""],
		&"flower": [&"recipe_test_echo_violet", &"test_pressed_violet", &"test_rewound_tape", &"dreamwalker"],
		&"candle": [&"recipe_test_countdown_candle", &"test_birthday_candle", &"", &"mourner"],
		&"clothing": [&"recipe_test_bedtime_overcoat", &"test_inside_out_raincoat", &"test_cold_pudding", &""],
	}
	for type_id in cases:
		var test_case := cases[type_id] as Array
		var recipe := QuestArcCatalog.recipe_by_id(test_case[0])
		var base := QuestArcCatalog.item_by_id(test_case[1])
		var helper := (
			QuestArcCatalog.item_by_id(test_case[2])
			if not (test_case[2] as StringName).is_empty()
			else null
		)
		var persona_id := test_case[3] as StringName
		var output := QuestArcCatalog.item_by_id(recipe.output_id)
		assert_not_null(recipe, type_id)
		assert_not_null(base, type_id)
		assert_not_null(output, type_id)
		assert_eq(base.property_set.tags, [type_id], type_id)
		assert_eq(output.property_set.tags, [type_id], type_id)
		assert_lte(base.property_set.present_personas().size(), 2, type_id)
		assert_lte(output.property_set.present_personas().size(), 2, type_id)
		assert_lte(recipe.required_personas.size(), 2, type_id)
		var totals := SynthesisRules.persona_totals(
			base,
			helper,
			persona_id,
			TEST_PERSONA_LEVELS,
		)
		assert_true(
			SynthesisRules.evaluate_candidate(recipe, base, totals).is_complete,
			"Generated %s recipe should be reachable with its documented test inputs." % type_id,
		)


func test_opening_shelves_match_the_requested_prices_and_properties() -> void:
	_assert_item(&"plastic_car", 8, [&"toy"], {&"nightwalker": 1})
	_assert_item(&"kaleidoscope", 20, [&"toy"], {&"dreamwalker": 2, &"mourner": 2})
	_assert_item(&"lotus_candle", 40, [&"toy"], {&"mourner": 3})
	_assert_item(&"mung_bean_cake", 8, [&"food"], {&"mourner": 1})
	_assert_item(&"milkshake", 16, [&"drink"], {&"homecomer": 2})
	_assert_item(&"cola", 10, [&"drink"], {&"nightwalker": 1, &"homecomer": 1})
	_assert_item(&"fries", 8, [&"food"], {&"homecomer": 1})
	_assert_item(&"nuggets", 18, [&"food"], {&"dreamwalker": 2, &"homecomer": 1})
	_assert_item(&"jasmine", 8, [&"flower"], {&"homecomer": 1})
	_assert_item(&"gardenia", 40, [&"flower"], {&"dreamwalker": 3})
	_assert_item(&"cactus", 16, [&"flower"], {&"nightwalker": 2})
	_assert_item(&"plastic_orchid", 10, [&"flower", &"toy"], {&"dreamwalker": 1, &"mourner": 1})
	_assert_item(&"tin_frog", 0, [&"toy", &"metal"], {&"nightwalker": 2})


func test_persona_icons_use_the_confirmed_four_line_art_assets() -> void:
	var expected_paths := {
		&"nightwalker": "res://resources/ui/persona/nightwalker.png",
		&"mourner": "res://resources/ui/persona/mourner.png",
		&"dreamwalker": "res://resources/ui/persona/dreamwalker.png",
		&"homecomer": "res://resources/ui/persona/homecomer.png",
	}
	for persona_id in expected_paths:
		var texture := ItemDetailPopup.property_icon_texture(persona_id)
		assert_not_null(texture, persona_id)
		assert_eq(texture.resource_path, expected_paths[persona_id], persona_id)
		assert_gt(texture.get_width(), 600, persona_id)
		assert_gt(texture.get_height(), 300, persona_id)


func test_store_unlocks_use_items_or_non_consuming_personas() -> void:
	var toy_unlock := QuestArcCatalog.store_unlock_for_store(&"toy")
	assert_true(QuestArcRules.store_unlock_accepts(
		toy_unlock, QuestArcCatalog.item_by_id(&"tin_frog")
	))
	assert_true(toy_unlock.consume_item)
	var record_unlock := QuestArcCatalog.store_unlock_for_store(&"record")
	assert_true(QuestArcRules.store_unlock_accepts(
		record_unlock, QuestArcCatalog.item_by_id(&"midnight_rose")
	))
	assert_false(QuestArcRules.store_unlock_accepts(
		record_unlock, QuestArcCatalog.item_by_id(&"jasmine")
	))
	assert_false(QuestArcCatalog.store_unlock_for_store(&"flower").consume_item)
	assert_false(QuestArcCatalog.store_unlock_for_store(&"bookstore").consume_item)


func test_new_game_starts_with_letters_pagination_tests_and_store_unlock_cards() -> void:
	var state := QuestGameState.new()
	assert_eq(state.wallet.money, 0)
	var starting_definition_ids: Array[StringName] = []
	for card in state.inventory:
		starting_definition_ids.append(card.definition_id)
	assert_eq(
		starting_definition_ids,
		TEST_STARTING_IDS,
	)
	assert_true(state.unlocked_store_ids.is_empty())
	assert_eq(state.active_tasks().size(), 6)
	assert_not_null(state.task_instance_for_definition(&"remittance"))
	assert_not_null(state.task_instance_for_definition(&"tin_boy_gift"))
	for index in 4:
		assert_not_null(state.task_instance_for_definition(
			StringName("debug_todo_page_%d" % (index + 1))
		))
	assert_null(state.task_instance_for_definition(&"self_care"))
	for persona_id in CardPropertySet.PERSONAS:
		assert_eq(
			int(state.protagonist_persona_counts.get(persona_id, -1)),
			int(TEST_PERSONA_LEVELS[persona_id]),
		)


func test_new_order_rewards_are_fixed() -> void:
	assert_eq(_money_reward(QuestArcCatalog.task_by_id(&"tin_boy_toy").outcomes[0]), 20)
	assert_eq(_money_reward(QuestArcCatalog.task_by_id(&"girl_order").outcomes[0]), 15)


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


func _money_reward(outcome: TaskOutcomeDefinition) -> int:
	for raw_effect in outcome.effects:
		var effect := raw_effect as StoryEffect
		if effect != null and effect.kind == StoryEffect.Kind.ADD_MONEY:
			return effect.amount
	return 0
