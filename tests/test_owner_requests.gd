extends GutTest


func test_owner_request_conditions_latch_only_after_delay_purchase_and_special_gate() -> void:
	var state := QuestGameState.new()
	for store_id in [&"fast_food", &"flower", &"record", &"bookstore"]:
		state.unlocked_store_ids[store_id] = true
		state.store_unlock_days[store_id] = 1
		state.store_purchase_counts[store_id] = 1
	state.day = 2
	state.wallet.money = 50
	state.expedition.discovered_room_ids[&"gray_hall"] = true
	state.purchased_item_ids[&"concrete_city_vol_1"] = true

	var changed := state.refresh_owner_request_availability()
	assert_has(changed, &"fast_food")
	assert_has(changed, &"flower")
	assert_has(changed, &"record")
	assert_has(changed, &"bookstore")
	for owner_id in [
		&"fast_food_owner", &"opening_flower_owner", &"record_owner", &"bookstore_owner",
	]:
		assert_true(state.available_owner_request_ids.has(owner_id), owner_id)

	state.wallet.money = 0
	state.expedition.discovered_room_ids.erase(&"gray_hall")
	state.purchased_item_ids.erase(&"concrete_city_vol_1")
	assert_true(state.owner_request_notice_visible(&"flower"))
	assert_true(state.owner_request_notice_visible(&"record"))
	assert_true(state.owner_request_notice_visible(&"bookstore"))


func test_toy_request_counts_successful_checkouts_and_waits_until_the_next_day() -> void:
	var state := QuestGameState.new()
	state.unlocked_store_ids[&"toy"] = true
	state.store_unlock_days[&"toy"] = 1
	state.wallet.money = 200
	var transaction := state.transaction_for_store(&"toy")
	for slot_index in 3:
		var slot := transaction.shelf_slots[slot_index] as ShelfSlotState
		assert_true(transaction.toggle_shelf_slot(slot.slot_id).ok)
		assert_true(state.checkout_store(&"toy").ok)
	assert_eq(int(state.store_purchase_counts.get(&"toy", 0)), 3)
	assert_false(state.owner_request_notice_visible(&"toy"))
	state.day = 2
	state.refresh_owner_request_availability()
	assert_true(state.owner_request_notice_visible(&"toy"))
	var interaction := state.interact_with_store_owner(&"toy")
	assert_true(interaction.ok)
	assert_true(interaction.activated)
	assert_false(state.owner_request_notice_visible(&"toy"))
	assert_not_null(state.task_instance_for_definition(&"owner_toy_birthday_cake"))


func test_owner_requests_settle_one_at_a_time_without_advancing_the_day() -> void:
	var state := QuestGameState.new()
	var starting_day := state.day
	var starting_tear := int(state.protagonist_shape_levels[&"tear"])
	var toy_task := state.activate_task(&"owner_toy_birthday_cake")
	var flower_task := state.activate_task(&"owner_flower_teddy")
	var cake := state.grant_item(&"birthday_cake", &"test")
	var bear := state.grant_item(&"cold_teddy_bear", &"test")
	assert_true(state.assign_card(toy_task.instance_id, &"birthday_cake", cake).ok)
	assert_true(state.assign_card(flower_task.instance_id, &"teddy", bear).ok)
	assert_true(state.confirm_task(toy_task.instance_id).ok)
	assert_true(state.confirm_task(flower_task.instance_id).ok)

	var prepared := state.prepare_owner_request_settlement()
	assert_true(prepared.ok)
	assert_eq(state.pending_arc.entries.size(), 2)
	assert_eq(state.pending_arc.entries[0].task_definition_id, &"owner_toy_birthday_cake")
	assert_eq(state.pending_arc.entries[1].task_definition_id, &"owner_flower_teddy")

	var first := state.settle_current_arc_entry()
	assert_true(first.ok)
	assert_eq(state.wallet.money, 20)
	assert_eq(int(state.protagonist_shape_levels[&"tear"]), starting_tear + 1)
	assert_null(state.card_by_instance_id(cake.instance_id))
	assert_not_null(state.card_by_instance_id(bear.instance_id))
	assert_true(toy_task.settled)
	assert_false(flower_task.settled)
	assert_true(state.pending_persona_reveal_shape_ids.is_empty())
	assert_true(state.mark_arc_entry_shown())

	var second := state.settle_current_arc_entry()
	assert_true(second.ok)
	assert_eq(second.reward_item_ids, [&"gardenia"])
	assert_null(state.card_by_instance_id(bear.instance_id))
	assert_true(flower_task.settled)
	assert_true(state.unlocked_store_item_ids.has(&"gardenia"))
	assert_true(state.unlocked_store_item_ids.has(&"candy_fake_flower"))
	var flower_slots := state.transaction_for_store(&"flower").shelf_slots
	assert_eq(flower_slots[4].item_id, &"gardenia")
	assert_eq(flower_slots[5].item_id, &"candy_fake_flower")
	assert_eq(
		state.inventory.filter(
			func(card: CardItemState) -> bool: return card.definition_id == &"gardenia"
		).size(),
		1,
	)
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.finish_arc().ok)
	assert_eq(state.day, starting_day)


func test_all_five_owner_requests_use_the_confirmed_exact_submission_rules() -> void:
	var accepted_cases := [
		[&"owner_fast_food_cola", &"cola", &"cola"],
		[&"owner_flower_teddy", &"teddy", &"baby_soothing_bear"],
		[&"owner_toy_birthday_cake", &"birthday_cake", &"birthday_cake"],
		[&"owner_record_nocturne", &"published_nocturne", &"nocturne_published"],
		[&"owner_bookstore_concrete_city", &"concrete_city_lower", &"concrete_city_vol_2"],
	]
	for test_case in accepted_cases:
		var state := QuestGameState.new()
		var task := state.activate_task(test_case[0])
		var card := state.grant_item(test_case[2], &"test")
		assert_true(state.assign_card(task.instance_id, test_case[1], card).ok, test_case[0])
		assert_true(state.confirm_task(task.instance_id).ok, test_case[0])


func test_unlocked_flower_products_refill_in_their_reserved_slots() -> void:
	var state := QuestGameState.new()
	state.unlocked_store_item_ids[&"gardenia"] = true
	state.unlocked_store_item_ids[&"candy_fake_flower"] = true
	var slots := state.transaction_for_store(&"flower").shelf_slots
	slots[4].clear()
	slots[5].clear()
	state.refill_scheduled_shelves(3)
	assert_eq(slots[4].item_id, &"gardenia")
	assert_eq(slots[5].item_id, &"candy_fake_flower")
