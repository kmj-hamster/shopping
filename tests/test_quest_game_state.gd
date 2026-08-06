extends GutTest


func test_new_game_starts_with_ten_coins_open_stores_and_day_one_tasks() -> void:
	var state := QuestGameState.new()
	assert_eq(state.day, 1)
	assert_eq(state.wallet.money, 10)
	for store_id in [&"toy", &"flower", &"fast_food", &"recycling"]:
		assert_true(state.is_store_unlocked(store_id), String(store_id))
	assert_false(state.is_store_unlocked(&"record"))
	assert_false(state.is_store_unlocked(&"book"))
	assert_not_null(state.task_instance_for_definition(&"order_hamster_midnight_supper"))
	assert_not_null(state.task_instance_for_definition(&"care_hungry"))
	assert_eq(state.active_tasks().size(), 2)
	for store_id in [&"toy", &"flower", &"fast_food", &"record", &"book"]:
		assert_eq(state.transaction_for_store(store_id).shelf_slots.size(), 6)


func test_store_slots_are_independent_and_daily_basic_stock_refills() -> void:
	var state := QuestGameState.new()
	var fast_food := state.transaction_for_store(&"fast_food")
	assert_eq(fast_food.shelf_slots[0].item_id, &"fast_hash_brown")
	assert_eq(fast_food.shelf_slots[1].item_id, &"fast_hash_brown")
	assert_true(fast_food.select_shelf_slot(fast_food.shelf_slots[0].slot_id).ok)
	var checkout := state.checkout_store(&"fast_food")
	assert_true(checkout.ok)
	assert_true(fast_food.shelf_slots[0].is_empty())
	assert_eq(fast_food.shelf_slots[1].item_id, &"fast_hash_brown")
	assert_eq(state.wallet.money, 8)
	assert_eq(checkout.purchased[0].purchase_price, 2)
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_true(state.finish_arc().ok)
	assert_eq(fast_food.shelf_slots[0].item_id, &"fast_hash_brown")


func test_recycling_refunds_the_exact_purchase_price() -> void:
	var state := QuestGameState.new()
	var flower := state.transaction_for_store(&"flower")
	assert_true(flower.select_shelf_slot(flower.shelf_slots[0].slot_id).ok)
	var card := state.checkout_store(&"flower").purchased[0] as CardItemState
	assert_eq(state.wallet.money, 8)
	assert_true(state.stage_recycle_card(card).ok)
	var recycled := state.checkout_recycle()
	assert_true(recycled.ok)
	assert_eq(recycled.total, 2)
	assert_eq(state.wallet.money, 10)
	assert_does_not_have(state.inventory, card)


func test_synthesis_previews_then_consumes_inputs_after_its_timer() -> void:
	var state := QuestGameState.new()
	var filling := state.grant_item(&"toy_cloth_scraps")
	var shape := state.grant_item(&"toy_cloth_scraps")
	var calm := state.grant_item(&"toy_sleeping_rabbit")
	assert_true(state.assign_synthesis_card(&"soft_filling", filling).ok)
	assert_true(state.assign_synthesis_card(&"toy_shape", shape).ok)
	assert_true(state.assign_synthesis_card(&"calm", calm).ok)
	var preview := state.synthesis_evaluation()
	assert_true(preview.is_complete)
	assert_eq(preview.output_id, &"craft_comfort_bear")
	assert_true(state.begin_synthesis().ok)
	assert_true(state.discovered_recipe_ids.has(&"recipe_teddy"))
	assert_false(state.advance_synthesis(1.0).completed)
	assert_eq(state.inventory.size(), 3)
	var completed := state.advance_synthesis(2.0)
	assert_true(completed.completed)
	assert_eq(state.inventory.size(), 1)
	assert_eq(state.inventory[0].definition_id, &"craft_comfort_bear")
	assert_eq(state.inventory[0].acquisition_source, &"synthesis")
	assert_null(state.active_synthesis)


func test_task_can_be_confirmed_cancelled_and_edited_again() -> void:
	var state := QuestGameState.new()
	var task := state.task_instance_for_definition(&"care_hungry")
	var card := state.grant_item(&"fast_hash_brown")
	assert_true(state.assign_card(task.instance_id, &"food", card).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	assert_true(task.confirmed)
	assert_false(state.return_card_to_hand(card))
	assert_true(state.cancel_task_confirmation(task.instance_id))
	assert_true(state.return_card_to_hand(card))
	assert_eq(card.location, CardItemState.Location.HAND)


func test_card_locked_in_confirmed_task_cannot_move_to_another_task() -> void:
	var state := QuestGameState.new()
	var care := state.task_instance_for_definition(&"care_hungry")
	var order := state.task_instance_for_definition(&"order_hamster_midnight_supper")
	var card := state.grant_item(&"fast_hash_brown")
	assert_true(state.assign_card(care.instance_id, &"food", card).ok)
	assert_true(state.confirm_task(care.instance_id).ok)
	var result := state.assign_card(order.instance_id, &"midnight_food", card)
	assert_false(result.ok)
	assert_eq(result.reason, QuestGameState.RESULT_LOCKED)
	assert_eq(care.assigned_instance_id(&"food"), card.instance_id)


func test_empty_arc_is_allowed_and_unfinished_tasks_survive_new_day() -> void:
	var state := QuestGameState.new()
	var day_one_task_ids := state.active_tasks().map(
		func(instance: TaskInstanceState) -> int: return instance.instance_id
	)
	var begin := state.begin_next_day()
	assert_true(begin.ok)
	assert_true(begin.empty_arc)
	assert_eq(begin.confirmed_task_count, 0)
	assert_true(state.apply_arc_effects().ok)
	assert_true(state.finish_arc().ok)
	assert_eq(state.day, 2)
	assert_eq(state.wallet.money, 10)
	assert_eq(state.active_tasks().size(), 4)
	for instance_id in day_one_task_ids:
		assert_false(state.task_instance(instance_id).settled)
	assert_not_null(state.task_instance_for_definition(&"order_riverside_broadcast"))
	assert_not_null(state.task_instance_for_definition(&"care_sleepless"))


func test_confirmed_arc_consumes_once_pays_order_and_counts_self_care_aspect() -> void:
	var state := QuestGameState.new()
	var order := state.task_instance_for_definition(&"order_hamster_midnight_supper")
	var care := state.task_instance_for_definition(&"care_hungry")
	var order_food := state.grant_item(&"fast_hash_brown")
	var care_food := state.grant_item(&"fast_hash_brown")
	assert_true(state.assign_card(order.instance_id, &"midnight_food", order_food).ok)
	assert_true(state.assign_card(care.instance_id, &"food", care_food).ok)
	assert_true(state.confirm_task(order.instance_id).ok)
	assert_true(state.confirm_task(care.instance_id).ok)
	assert_eq(state.begin_next_day().confirmed_task_count, 2)

	var applied := state.apply_arc_effects()
	assert_true(applied.ok)
	assert_false(applied.already_applied)
	assert_eq(applied.consumed_count, 2)
	assert_eq(applied.money_gained, 5)
	assert_eq(state.wallet.money, 15)
	assert_eq(state.protagonist_aspect_counts[&"lamp"], 1)
	assert_true(state.inventory.is_empty())
	assert_true(state.apply_arc_effects().already_applied)
	assert_eq(state.wallet.money, 15)
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.finish_arc().ok)
	assert_eq(state.day, 2)


func test_map_unlock_consumes_only_the_exact_key_item() -> void:
	var state := QuestGameState.new()
	var sunflower := state.grant_item(&"flower_sunflower")
	assert_false(state.unlock_store(&"record", sunflower).ok)
	assert_has(state.inventory, sunflower)
	var moth := state.grant_item(&"toy_windup_moth")
	var result := state.unlock_store(&"record", moth)
	assert_true(result.ok)
	assert_true(state.is_store_unlocked(&"record"))
	assert_does_not_have(state.inventory, moth)
	assert_has(state.inventory, sunflower)


func test_owner_task_settles_immediately_and_locks_other_branch() -> void:
	var state := QuestGameState.new()
	var task := state.activate_task(&"owner_balloon_erase_smile")
	var thinner := state.grant_item(&"craft_banana_water", &"synthesis")
	assert_true(state.assign_card(task.instance_id, &"answer", thinner).ok)
	var result := state.submit_owner_task(task.instance_id)
	assert_true(result.ok)
	assert_eq(result.outcome_id, &"flight")
	assert_eq(state.story_flags[&"balloon_route"], &"flight")
	assert_eq(state.protagonist_aspect_counts[&"candle"], 1)
	assert_eq(state.owner_states[&"balloon"], &"departed")
	assert_true(task.settled)
	assert_null(state.activate_task(&"owner_balloon_erase_smile"))


func test_arc_prevalidates_every_entry_before_mutating_any_task() -> void:
	var state := QuestGameState.new()
	var order := state.task_instance_for_definition(&"order_hamster_midnight_supper")
	var care := state.task_instance_for_definition(&"care_hungry")
	var order_food := state.grant_item(&"fast_hash_brown")
	var care_food := state.grant_item(&"fast_hash_brown")
	assert_true(state.assign_card(order.instance_id, &"midnight_food", order_food).ok)
	assert_true(state.assign_card(care.instance_id, &"food", care_food).ok)
	assert_true(state.confirm_task(order.instance_id).ok)
	assert_true(state.confirm_task(care.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	# Simulate a corrupted payload that references a missing card in the second entry.
	state.inventory.erase(care_food)
	var result := state.apply_arc_effects()
	assert_false(result.ok)
	assert_eq(result.reason, QuestGameState.RESULT_NOT_READY)
	assert_eq(state.wallet.money, 10)
	assert_has(state.inventory, order_food)
	assert_false(order.settled)
	assert_false(care.settled)
