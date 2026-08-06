extends GutTest


func test_manifest_loads_complete_valid_first_content_batch() -> void:
	var manifest := QuestArcCatalog.manifest()
	assert_not_null(manifest)
	assert_eq(manifest.initial_money, 10)
	assert_eq(manifest.properties.size(), 22)
	assert_eq(manifest.items.size(), 21)
	assert_eq(manifest.tasks.size(), 9)
	assert_eq(manifest.recipes.size(), 2)
	assert_eq(manifest.stores.size(), 6)
	assert_eq(manifest.store_unlocks.size(), 2)
	assert_true(manifest.validation_errors().is_empty(), str(manifest.validation_errors()))


func test_items_use_small_prices_and_hybrid_property_limits() -> void:
	for raw_item in QuestArcCatalog.manifest().items:
		var item := raw_item as QuestItemDefinition
		assert_not_null(item)
		assert_between(item.base_price, 0, 20, String(item.id))
		assert_lte(item.property_set.property_count(), 4, String(item.id))
		assert_lte(item.property_set.present_aspects().size(), 2, String(item.id))
	var hash_brown := QuestArcCatalog.item_by_id(&"fast_hash_brown")
	assert_true(hash_brown.property_set.tags.has(&"food"))
	assert_eq(hash_brown.property_value(&"food"), 0)
	assert_eq(hash_brown.property_value(&"crispy"), 4)


func test_store_unlocks_consume_exact_map_keys() -> void:
	var record_store := QuestArcCatalog.store_by_id(&"record")
	var record_unlock := QuestArcCatalog.store_unlock_by_id(record_store.unlock_definition_id)
	assert_false(record_store.initially_unlocked)
	assert_true(QuestArcRules.store_unlock_accepts(
		record_unlock,
		QuestArcCatalog.item_by_id(&"toy_windup_moth"),
	))
	assert_false(QuestArcRules.store_unlock_accepts(
		record_unlock,
		QuestArcCatalog.item_by_id(&"flower_sunflower"),
	))
	assert_true(record_unlock.consume_item)


func test_authored_tasks_activate_by_day_without_completion_prerequisites() -> void:
	var expected := {
		&"order_hamster_midnight_supper": 1,
		&"order_riverside_broadcast": 2,
		&"order_lost_found_birthday": 3,
		&"order_window_without_sun": 4,
		&"care_hungry": 1,
		&"care_sleepless": 2,
		&"care_bedside": 3,
		&"care_rain_close": 4,
	}
	for task_id in expected:
		assert_eq(QuestArcCatalog.task_by_id(task_id).activation_day, expected[task_id])


func test_first_order_resolves_awake_or_sleep_and_pays_small_reward() -> void:
	var task := QuestArcCatalog.task_by_id(&"order_hamster_midnight_supper")
	var awake := QuestArcRules.outcome_for(task, [QuestArcCatalog.item_by_id(&"fast_hash_brown")])
	var sleep := QuestArcRules.outcome_for(task, [QuestArcCatalog.item_by_id(&"fast_warm_milk")])
	assert_eq(awake.id, &"awake")
	assert_eq(sleep.id, &"sleep")
	assert_eq(_money_reward(awake), 5)
	assert_eq(_money_reward(sleep), 4)


func _money_reward(outcome: TaskOutcomeDefinition) -> int:
	for raw_effect in outcome.effects:
		var effect := raw_effect as StoryEffect
		if effect != null and effect.kind == StoryEffect.Kind.ADD_MONEY:
			return effect.amount
	return 0
