extends GutTest


func test_talk_and_cumulative_spend_unlock_levels_without_split_purchase_exploit() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var relationship := commerce.relationship_state_for_owner(&"balloon")
	var first_talk := commerce.talk_to_store_owner(SlotDemoCatalog.STORE_TOY)
	var repeated_talk := commerce.talk_to_store_owner(SlotDemoCatalog.STORE_TOY)

	assert_eq(first_talk.experience_gained, 2)
	assert_eq(repeated_talk.experience_gained, 0)
	assert_eq(relationship.experience, 2)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[0].slot_id).ok)
	var first_purchase := commerce.checkout_store(SlotDemoCatalog.STORE_TOY)
	assert_true(first_purchase.ok)
	assert_eq(first_purchase.owner_experience_gained, 1)
	assert_eq(relationship.level, 1)
	assert_eq(toy.unlocked_page_count, 2)
	assert_eq(toy.shelf_slots_for_page(1).size(), 6)
	assert_eq(toy.shelf_slots_for_page(2).size(), 1)
	assert_eq(toy.shelf_slots_for_page(2)[0].item_id, &"toy_windup_moth")

	commerce.begin_new_day(2)
	assert_eq(commerce.talk_to_store_owner(SlotDemoCatalog.STORE_TOY).experience_gained, 2)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[1].slot_id).ok)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[2].slot_id).ok)
	var second_purchase := commerce.checkout_store(SlotDemoCatalog.STORE_TOY)

	assert_true(second_purchase.ok)
	assert_eq(second_purchase.total, 24)
	assert_eq(second_purchase.owner_experience_gained, 2)
	assert_eq(relationship.lifetime_spend, 36)
	assert_eq(relationship.awarded_spend_experience, 3)
	assert_eq(relationship.level, 2)
	assert_has(commerce.activity_state.known_recipe_ids, &"recipe_teddy")
	assert_has(commerce.activity_state.active_request_ids, &"request_balloon_hug")


func test_level_three_applies_ceil_ten_percent_discount() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	commerce.set_owner_level(&"balloon", 3)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	var marble_slot := toy.shelf_slots[4]

	assert_eq(toy.discount_rate, 0.1)
	assert_true(toy.select_shelf_slot(marble_slot.slot_id).ok)
	assert_eq(toy.cart_total(), 13)
	var result := commerce.checkout_store(SlotDemoCatalog.STORE_TOY)

	assert_true(result.ok)
	assert_eq(result.total, 13)
	assert_eq(commerce.wallet.money, 107)


func test_preferred_comfort_bear_completes_request_and_reaches_friend_level() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	commerce.set_owner_level(&"balloon", 2)
	var bear := CardItemState.new(100, &"craft_comfort_bear")
	commerce.inventory.append(bear)
	assert_true(commerce.activity_state.assign_card(
		&"request_balloon_hug", &"hug", bear
	).ok)

	var result := commerce.submit_owner_request(&"request_balloon_hug")

	assert_true(result.ok)
	assert_eq(result.experience_gained, 8)
	assert_eq(result.consumed_count, 1)
	assert_eq(result.story_flag_value, &"comfort")
	assert_true(commerce.inventory.is_empty())
	assert_true(commerce.is_request_completed(&"request_balloon_hug"))
	assert_eq(commerce.story_flags[&"balloon_hug"], &"comfort")
	assert_eq(commerce.relationship_state_for_owner(&"balloon").level, 3)
	assert_eq(commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY).discount_rate, 0.1)
	assert_false(commerce.activity_state.can_edit_activity(&"request_balloon_hug"))
	var repeated := commerce.submit_owner_request(&"request_balloon_hug")
	assert_false(repeated.ok)
	assert_eq(repeated.reason, SlotCommerceState.RESULT_REQUEST_COMPLETED)


func test_childhood_teddy_records_memory_branch_without_preference_bonus() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	commerce.set_owner_level(&"balloon", 2)
	var bear := CardItemState.new(100, &"craft_childhood_teddy")
	commerce.inventory.append(bear)
	assert_true(commerce.activity_state.assign_card(
		&"request_balloon_hug", &"hug", bear
	).ok)

	var result := commerce.submit_owner_request(&"request_balloon_hug")

	assert_true(result.ok)
	assert_eq(result.experience_gained, 6)
	assert_eq(result.story_flag_value, &"memory")
	assert_eq(commerce.relationship_state_for_owner(&"balloon").level, 2)
	assert_eq(commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY).discount_rate, 0.0)


func test_request_delivery_is_rejected_if_it_would_leave_tonight_impossible() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(0), 7)
	commerce.set_owner_level(&"balloon", 2)
	for transaction in commerce.store_transactions.values():
		for slot in transaction.shelf_slots:
			slot.clear()
	var bear := CardItemState.new(100, &"craft_comfort_bear")
	commerce.inventory.append(bear)
	assert_true(commerce.activity_state.assign_card(
		&"request_balloon_hug", &"hug", bear
	).ok)

	var result := commerce.submit_owner_request(&"request_balloon_hug")

	assert_false(result.ok)
	assert_eq(result.reason, SlotCommerceState.RESULT_DAILY_RISK)
	assert_has(commerce.inventory, bear)
	assert_false(commerce.is_request_completed(&"request_balloon_hug"))


func test_other_store_owner_uses_same_once_per_day_talk_interface_without_balloon_unlocks() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var first := commerce.talk_to_store_owner(SlotDemoCatalog.STORE_FLOWER)
	var repeated := commerce.talk_to_store_owner(SlotDemoCatalog.STORE_FLOWER)

	assert_true(first.ok)
	assert_eq(first.dialogue_key, &"slot.owner.placeholder.talk")
	assert_eq(first.experience_gained, 0)
	assert_true(repeated.already_talked)
	assert_eq(commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY).shelf_slots.size(), 6)
