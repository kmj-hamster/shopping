extends GutTest


func test_owned_card_can_fill_wish_and_return_to_hand() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var result := commerce.activity_state.assign_card(&"wish_hungry", &"hungry", hash_brown)

	assert_true(result.ok)
	assert_eq(hash_brown.location, CardItemState.Location.ACTIVITY_SLOT)
	assert_true(commerce.activity_state.evaluation_for(&"wish_hungry").is_ready)
	assert_true(commerce.activity_state.return_card_to_hand(hash_brown))
	assert_eq(hash_brown.location, CardItemState.Location.HAND)
	assert_null(commerce.activity_state.card_for_slot(&"wish_hungry", &"hungry"))


func test_type_rules_reject_card_without_moving_it() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var marble := _buy_card(commerce, SlotDemoCatalog.STORE_TOY, 4)
	var result := commerce.activity_state.assign_card(&"wish_hungry", &"hungry", marble)

	assert_false(result.ok)
	assert_eq(result.reason, SlotActivityState.RESULT_REJECTED)
	assert_eq(marble.location, CardItemState.Location.HAND)


func test_type_match_may_be_placed_before_value_requirement_is_met() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var result := commerce.activity_state.assign_card(
		&"wish_stay_awake", &"stay_awake", hash_brown
	)
	var evaluation := commerce.activity_state.evaluation_for(&"wish_stay_awake")

	assert_true(result.ok)
	assert_true(result.placement.can_place)
	assert_false(result.placement.value_satisfied)
	assert_false(evaluation.is_ready)


func test_moving_card_to_another_activity_clears_its_old_slot() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", hash_brown).ok)
	assert_true(commerce.activity_state.assign_card(
		&"wish_stay_awake", &"stay_awake", hash_brown
	).ok)

	assert_null(commerce.activity_state.card_for_slot(&"wish_hungry", &"hungry"))
	assert_eq(
		commerce.activity_state.card_for_slot(&"wish_stay_awake", &"stay_awake"),
		hash_brown,
	)


func test_occupied_slot_rejects_second_card() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var first := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var second := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 1)
	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", first).ok)
	var result := commerce.activity_state.assign_card(&"wish_hungry", &"hungry", second)

	assert_false(result.ok)
	assert_eq(result.reason, SlotActivityState.RESULT_OCCUPIED)
	assert_eq(second.location, CardItemState.Location.HAND)


func test_night_radio_recipe_reports_ready_output_and_preview() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var record := _buy_card(commerce, SlotDemoCatalog.STORE_RECORD, 0)
	var marble := _buy_card(commerce, SlotDemoCatalog.STORE_TOY, 4)
	var hash_brown := _buy_card(commerce, SlotDemoCatalog.STORE_FAST_FOOD, 0)
	var activity := commerce.activity_state

	assert_true(activity.assign_card(&"recipe_night_radio", &"sound", record).ok)
	assert_true(activity.assign_card(&"recipe_night_radio", &"shell", marble).ok)
	assert_true(activity.assign_card(&"recipe_night_radio", &"tuning", hash_brown).ok)
	var evaluation := activity.evaluation_for(&"recipe_night_radio")

	assert_true(evaluation.is_ready)
	assert_true(evaluation.synthesis.is_complete)
	assert_eq(evaluation.synthesis.output_id, &"craft_clear_receiver")
	assert_eq(evaluation.synthesis.preview_key, &"slot.recipe.night_radio.preview.clear")


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
