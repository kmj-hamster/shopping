extends GutTest


func test_default_first_night_pair_is_feasible_for_thirty_two() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 1999)
	var result := commerce.tonight_is_satisfiable()

	assert_eq(
		commerce.activity_state.active_daily_wish_ids,
		[&"wish_hungry", &"wish_bedside"],
	)
	assert_true(result.feasible)
	assert_eq(result.minimum_cost, 32)
	assert_eq(result.choices.size(), 2)


func test_one_owned_card_cannot_satisfy_two_wishes_at_once() -> void:
	var inventory: Array[CardItemState] = [
		CardItemState.new(1, &"toy_glass_marble"),
	]
	var result := DailyWishSolver.evaluate(
		[&"wish_stay_awake", &"wish_remember"],
		{},
		inventory,
		{},
		[],
		0,
	)

	assert_false(result.feasible)


func test_second_night_pair_uses_two_independent_marble_shelves() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 1999)
	var pair: Array[StringName] = [&"wish_stay_awake", &"wish_remember"]
	var result := DailyWishSolver.evaluate(
		pair,
		{},
		commerce.inventory,
		commerce.store_transactions,
		ShopSchedule.open_store_ids(2),
		commerce.wallet.money,
	)

	assert_true(result.feasible)
	assert_eq(result.minimum_cost, 28)
	assert_ne(result.choices[0].source_key, result.choices[1].source_key)


func test_checkout_rejects_spending_the_last_viable_daily_budget() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(32), 1999)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[0].slot_id).ok)

	var result := commerce.checkout_store(SlotDemoCatalog.STORE_TOY)

	assert_false(result.ok)
	assert_eq(result.reason, SlotCommerceState.RESULT_DAILY_RISK)
	assert_eq(commerce.wallet.money, 32)
	assert_true(commerce.inventory.is_empty())
	assert_eq(toy.cart_count(), 1)


func test_checkout_allows_buying_part_of_the_daily_solution() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(32), 1999)
	var fast_food := commerce.transaction_for_store(SlotDemoCatalog.STORE_FAST_FOOD)
	assert_true(fast_food.select_shelf_slot(fast_food.shelf_slots[0].slot_id).ok)

	var result := commerce.checkout_store(SlotDemoCatalog.STORE_FAST_FOOD)

	assert_true(result.ok)
	assert_eq(commerce.wallet.money, 20)
	assert_eq(commerce.inventory[0].definition_id, &"fast_hash_brown")
	assert_true(commerce.tonight_is_satisfiable().feasible)


func test_recycling_last_viable_card_is_rejected_atomically() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(20), 1999)
	var hash_brown := CardItemState.new(1, &"fast_hash_brown")
	commerce.inventory.append(hash_brown)
	assert_true(commerce.stage_recycle_card(hash_brown).ok)

	var result := commerce.checkout_recycling()

	assert_false(result.ok)
	assert_eq(result.reason, SlotCommerceState.RESULT_DAILY_RISK)
	assert_eq(commerce.wallet.money, 20)
	assert_has(commerce.inventory, hash_brown)
	assert_eq(hash_brown.location, CardItemState.Location.RECYCLE)


func test_twenty_day_structure_always_selects_two_feasible_wishes() -> void:
	for seed in [1, 1999, 9917]:
		var commerce := SlotCommerceState.new(PlayerWallet.new(120), seed)
		for day in range(1, 21):
			if day > 1:
				commerce.begin_new_day(day)
			var wish_ids := commerce.activity_state.active_daily_wish_ids
			assert_eq(wish_ids.size(), 2, "seed %d day %d" % [seed, day])
			assert_ne(wish_ids[0], wish_ids[1], "seed %d day %d" % [seed, day])
			assert_true(
				commerce.tonight_is_satisfiable().feasible,
				"seed %d day %d" % [seed, day],
			)
