extends GutTest


func test_manifest_is_the_shopping0807_demo_whitelist() -> void:
	var manifest := QuestArcCatalog.manifest()
	assert_not_null(manifest)
	assert_eq(manifest.initial_money, 30)
	assert_eq(manifest.starting_item_ids, [
		&"fries", &"sunflower", &"toy_block", &"soft_gauze", &"soft_gauze", &"mirror_shard",
	])
	assert_eq(manifest.properties.size(), 15)
	assert_not_null(QuestArcCatalog.property_by_id(CardPropertySet.PROPERTY_PERSONA))
	assert_eq(manifest.items.size(), 12)
	assert_eq(manifest.tasks.size(), 4)
	assert_eq(manifest.recipes.size(), 4)
	assert_eq(manifest.stores.size(), 2)
	assert_eq(manifest.store_unlocks.size(), 1)
	assert_eq(manifest.owners.size(), 2)
	assert_true(manifest.validation_errors().is_empty(), str(manifest.validation_errors()))


func test_only_ppt_items_are_runtime_visible_and_have_images() -> void:
	var expected_ids: Array[StringName] = [
		&"fries", &"sunflower", &"agave", &"cola", &"scissors",
		&"toy_block", &"midnight_rose", &"worn_teddy", &"baby_teddy", &"pale_teddy",
		&"soft_gauze", &"mirror_shard",
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
	assert_null(QuestArcCatalog.item_by_id(&"fast_hash_brown"))
	assert_null(QuestArcCatalog.store_by_id(&"recycling"))


func test_record_shop_unlock_consumes_a_sunflower() -> void:
	var record_store := QuestArcCatalog.store_by_id(&"record")
	var unlock := QuestArcCatalog.store_unlock_by_id(record_store.unlock_definition_id)
	assert_false(record_store.initially_unlocked)
	assert_true(QuestArcRules.store_unlock_accepts(
		unlock,
		QuestArcCatalog.item_by_id(&"sunflower"),
	))
	assert_false(QuestArcRules.store_unlock_accepts(
		unlock,
		QuestArcCatalog.item_by_id(&"fries"),
	))
	assert_true(unlock.consume_item)


func test_new_game_uses_ppt_money_tasks_and_starting_hand() -> void:
	var state := QuestGameState.new()
	assert_eq(state.wallet.money, 30)
	assert_eq(state.inventory.size(), 6)
	assert_eq(state.inventory[0].definition_id, &"fries")
	assert_true(state.is_store_unlocked(&"flower"))
	assert_false(state.is_store_unlocked(&"record"))
	assert_eq(state.protagonist_aspect_counts[&"ease"], 3)
	assert_eq(state.synthesis_base_instance_id, 0)
	assert_not_null(state.task_instance_for_definition(&"girl_order"))
	assert_not_null(state.task_instance_for_definition(&"self_care"))
	assert_not_null(state.task_instance_for_definition(&"mouse_order"))
	assert_null(state.task_instance_for_definition(&"flower_owner_request"))


func test_girl_request_pays_the_ppt_salty_reward() -> void:
	var task := QuestArcCatalog.task_by_id(&"girl_order")
	var outcome := QuestArcRules.outcome_for(task, [QuestArcCatalog.item_by_id(&"fries")])
	assert_eq(outcome.id, &"salty")
	assert_eq(_money_reward(outcome), 12)


func test_flower_owner_request_is_an_explicit_either_or_choice() -> void:
	var task := QuestArcCatalog.task_by_id(&"flower_owner_request")
	assert_eq(task.slot_mode, TaskDefinition.SlotMode.ANY)
	assert_eq(task.slot_rules.size(), 2)
	var trim_rule := task.slot_rules[0] as CardSlotRule
	var nourish_rule := task.slot_rules[1] as CardSlotRule
	assert_eq(trim_rule.accepted_item_ids, [&"scissors"])
	assert_eq(nourish_rule.accepted_item_ids, [&"agave"])


func _money_reward(outcome: TaskOutcomeDefinition) -> int:
	for raw_effect in outcome.effects:
		var effect := raw_effect as StoryEffect
		if effect != null and effect.kind == StoryEffect.Kind.ADD_MONEY:
			return effect.amount
	return 0
