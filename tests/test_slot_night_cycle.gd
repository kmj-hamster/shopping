extends GutTest


func test_confirmation_locks_card_without_consuming_or_counting_aspects() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 1999)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	assert_true(commerce.activity_state.assign_card(
		&"wish_hungry", &"hungry", hash_brown
	).ok)

	var result := commerce.activity_state.confirm_daily_wish(&"wish_hungry")

	assert_true(result.ok)
	assert_true(commerce.activity_state.is_daily_confirmed(&"wish_hungry"))
	assert_has(commerce.inventory, hash_brown)
	assert_eq(commerce.protagonist_aspect_counts[&"lamp"], 0)
	assert_false(commerce.activity_state.return_card_to_hand(hash_brown))
	assert_true(commerce.activity_state.cancel_daily_confirmation(&"wish_hungry"))
	assert_true(commerce.activity_state.return_card_to_hand(hash_brown))


func test_transition_consumes_once_counts_present_aspects_and_starts_day_two() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 1999)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var sunflower := _buy_card(commerce, SlotDemoCatalog.STORE_FLOWER, 0)
	_confirm_first_night(commerce, hash_brown, sunflower)

	var begin := commerce.begin_night_transition()
	assert_true(begin.ok)
	assert_eq(begin.transition.entries.size(), 2)
	assert_eq(commerce.inventory.size(), 2)
	assert_eq(commerce.protagonist_aspect_counts[&"lamp"], 0)

	var applied := commerce.apply_night_transition_consumption()
	assert_true(applied.ok)
	assert_eq(applied.consumed_count, 2)
	assert_true(commerce.inventory.is_empty())
	assert_eq(commerce.protagonist_aspect_counts[&"lamp"], 2)
	assert_eq(commerce.protagonist_aspect_counts[&"pillow"], 1)
	assert_eq(commerce.protagonist_aspect_counts[&"mirror"], 0)
	assert_true(commerce.apply_night_transition_consumption().already_applied)
	assert_eq(commerce.protagonist_aspect_counts[&"lamp"], 2)

	var finish := commerce.finish_night_transition()
	assert_true(finish.ok)
	assert_eq(commerce.day, 2)
	assert_eq(commerce.wallet.money, 188)
	assert_eq(
		commerce.activity_state.active_daily_wish_ids,
		[&"wish_stay_awake", &"wish_remember"],
	)
	assert_false(commerce.activity_state.all_daily_wishes_confirmed())
	assert_null(commerce.pending_transition)


func test_transition_snapshot_uses_selected_item_result_keys() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 1999)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var sunflower := _buy_card(commerce, SlotDemoCatalog.STORE_FLOWER, 0)
	_confirm_first_night(commerce, hash_brown, sunflower)

	var transition := commerce.begin_night_transition().transition as SlotNightTransition

	assert_eq(transition.result_keys(), [
		&"slot.wish.hungry.result.fast_hash_brown",
		&"slot.wish.bedside.result.flower_sunflower",
	])
	assert_has(commerce.inventory, hash_brown)
	assert_has(commerce.inventory, sunflower)


func test_transition_cannot_finish_before_black_screen_consumption() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 1999)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var sunflower := _buy_card(commerce, SlotDemoCatalog.STORE_FLOWER, 0)
	_confirm_first_night(commerce, hash_brown, sunflower)
	assert_true(commerce.begin_night_transition().ok)

	var result := commerce.finish_night_transition()

	assert_false(result.ok)
	assert_eq(result.reason, SlotCommerceState.RESULT_CONSUMPTION_PENDING)
	assert_eq(commerce.day, 1)


func _confirm_first_night(
	commerce: SlotCommerceState,
	hash_brown: CardItemState,
	sunflower: CardItemState,
) -> void:
	assert_true(commerce.activity_state.assign_card(
		&"wish_hungry", &"hungry", hash_brown
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"wish_bedside", &"bedside", sunflower
	).ok)
	assert_true(commerce.activity_state.confirm_daily_wish(&"wish_hungry").ok)
	assert_true(commerce.activity_state.confirm_daily_wish(&"wish_bedside").ok)


func _buy_card(
	commerce: SlotCommerceState,
	store_id: StringName,
	shelf_index: int,
) -> CardItemState:
	var transaction := commerce.transaction_for_store(store_id)
	assert_true(transaction.select_shelf_slot(transaction.shelf_slots[shelf_index].slot_id).ok)
	var result := commerce.checkout_store(store_id)
	assert_true(result.ok)
	return result.purchased[0] as CardItemState
