extends GutTest


func test_manifest_is_the_new_opening_whitelist() -> void:
	var manifest := QuestArcCatalog.manifest()
	assert_not_null(manifest)
	assert_eq(manifest.initial_money, 0)
	assert_true(manifest.starting_item_ids.is_empty())
	assert_eq(manifest.maximum_item_price, 40)
	assert_eq(manifest.properties.size(), 12)
	assert_eq(manifest.items.size(), 14)
	assert_eq(manifest.tasks.size(), 5)
	assert_eq(manifest.recipes.size(), 1)
	assert_eq(manifest.stores.size(), 5)
	assert_eq(manifest.store_unlocks.size(), 5)
	assert_eq(manifest.owners.size(), 3)
	for persona_id in CardPropertySet.PROTAGONIST_STATS:
		assert_eq(int(manifest.initial_protagonist_stats.get(persona_id, -1)), 0)
	assert_true(manifest.validation_errors().is_empty(), str(manifest.validation_errors()))


func test_opening_items_are_runtime_visible_and_have_images() -> void:
	var expected_ids: Array[StringName] = [
		&"plastic_car", &"kaleidoscope", &"lotus_candle", &"mung_bean_cake",
		&"milkshake", &"cola", &"fries", &"nuggets",
		&"jasmine", &"gardenia", &"cactus", &"plastic_orchid",
		&"tin_frog", &"midnight_rose",
	]
	var actual_ids: Array[StringName] = []
	for raw_item in QuestArcCatalog.manifest().items:
		var item := raw_item as QuestItemDefinition
		assert_not_null(item)
		actual_ids.append(item.id)
		assert_not_null(item.image, String(item.id))
	actual_ids.sort()
	expected_ids.sort()
	assert_eq(actual_ids, expected_ids)
	assert_null(QuestArcCatalog.item_by_id(&"toy_block"))
	assert_null(QuestArcCatalog.store_by_id(&"recycling"))


func test_opening_shelves_match_the_requested_prices_and_properties() -> void:
	_assert_item(&"plastic_car", 8, [&"toy"], {&"lamp": 1})
	_assert_item(&"kaleidoscope", 20, [&"toy"], {&"gauze": 2, &"mirror": 2})
	_assert_item(&"lotus_candle", 40, [&"toy"], {&"mirror": 3})
	_assert_item(&"mung_bean_cake", 8, [&"food"], {&"mirror": 1})
	_assert_item(&"milkshake", 16, [&"drink"], {&"pillow": 2})
	_assert_item(&"cola", 10, [&"drink"], {&"lamp": 1, &"pillow": 1})
	_assert_item(&"fries", 8, [&"food"], {&"pillow": 1})
	_assert_item(&"nuggets", 18, [&"food"], {&"gauze": 2, &"pillow": 1})
	_assert_item(&"jasmine", 8, [&"flower"], {&"pillow": 1})
	_assert_item(&"gardenia", 40, [&"flower"], {&"gauze": 3})
	_assert_item(&"cactus", 16, [&"flower"], {&"lamp": 2})
	_assert_item(&"plastic_orchid", 10, [&"flower", &"toy"], {&"gauze": 1, &"mirror": 1})
	_assert_item(&"tin_frog", 0, [&"toy", &"metal"], {&"lamp": 2})


func test_night_aspect_icons_are_the_declared_solid_colors() -> void:
	var expected_colors := {
		&"lamp": "f2d14f",
		&"mirror": "6faed9",
		&"gauze": "f3c6d6",
		&"pillow": "9a78c5",
	}
	for aspect_id in expected_colors:
		var texture := ItemDetailPopup.property_icon_texture(aspect_id)
		assert_not_null(texture, aspect_id)
		assert_eq(
			texture.get_image().get_pixel(48, 48).to_html(false),
			expected_colors[aspect_id],
			aspect_id,
		)


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


func test_new_game_starts_with_only_the_two_opening_letters() -> void:
	var state := QuestGameState.new()
	assert_eq(state.wallet.money, 0)
	assert_true(state.inventory.is_empty())
	assert_true(state.unlocked_store_ids.is_empty())
	assert_eq(state.active_tasks().size(), 2)
	assert_not_null(state.task_instance_for_definition(&"remittance"))
	assert_not_null(state.task_instance_for_definition(&"tin_boy_gift"))
	assert_null(state.task_instance_for_definition(&"self_care"))
	for persona_id in CardPropertySet.PROTAGONIST_STATS:
		assert_eq(int(state.protagonist_aspect_counts.get(persona_id, -1)), 0)


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
