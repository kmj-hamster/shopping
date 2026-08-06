extends GutTest

const TEST_SAVE_PATH := "user://slot_save_repository_test.json"

var repository: SlotSaveRepository


func before_each() -> void:
	repository = SlotSaveRepository.new(TEST_SAVE_PATH)
	repository.erase()


func after_each() -> void:
	repository.erase()


func test_round_trip_preserves_inventory_slots_shelves_relationships_and_carts() -> void:
	var source := SlotCommerceState.new(PlayerWallet.new(137), 27)
	source.set_owner_level(&"balloon", 2)
	assert_true(source.talk_to_store_owner(SlotDemoCatalog.STORE_TOY).ok)
	var hungry := _add_card(source, &"fast_hash_brown", 100)
	var spare := _add_card(source, &"flower_sunflower", 101)
	spare.purchase_price = 17
	var recycled := _add_card(source, &"toy_glass_marble", 102)
	assert_true(source.activity_state.assign_card(&"wish_hungry", &"hungry", hungry).ok)
	assert_true(source.activity_state.confirm_daily_wish(&"wish_hungry").ok)
	assert_true(source.stage_recycle_card(recycled).ok)
	var flower := source.transaction_for_store(SlotDemoCatalog.STORE_FLOWER)
	assert_true(flower.select_shelf_slot(flower.shelf_slots[0].slot_id).ok)
	source.story_flags[&"balloon_hug"] = &"comfort"
	source.protagonist_aspect_counts[&"lamp"] = 4
	source.first_crafted_output_ids[&"craft_clear_receiver"] = true

	assert_true(repository.save(source))
	var restored := SlotCommerceState.new(PlayerWallet.new(1), 99)
	var load_result := repository.load_into(restored)

	assert_true(load_result.ok)
	assert_eq(restored.wallet.money, 137)
	assert_eq(restored.inventory.size(), 3)
	assert_eq(restored.card_by_instance_id(spare.instance_id).location, CardItemState.Location.HAND)
	assert_eq(restored.card_by_instance_id(spare.instance_id).purchase_price, 17)
	assert_eq(
		restored.activity_state.card_for_slot(&"wish_hungry", &"hungry").instance_id,
		hungry.instance_id,
	)
	assert_true(restored.activity_state.is_daily_confirmed(&"wish_hungry"))
	assert_eq(restored.recycle_transaction.staged_instance_ids, [recycled.instance_id])
	assert_eq(
		restored.card_by_instance_id(recycled.instance_id).location,
		CardItemState.Location.RECYCLE,
	)
	assert_eq(
		restored.transaction_for_store(SlotDemoCatalog.STORE_FLOWER).selected_shelf_slot_ids,
		flower.selected_shelf_slot_ids,
	)
	var restored_toy := restored.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_eq(restored_toy.unlocked_page_count, 2)
	assert_eq(restored_toy.shelf_slots_for_page(1).size(), 6)
	assert_eq(restored_toy.shelf_slots_for_page(2).size(), 1)
	assert_eq(restored.relationship_state_for_owner(&"balloon").level, 2)
	assert_eq(restored.relationship_state_for_owner(&"balloon").last_talk_day, 1)
	assert_has(restored.activity_state.known_recipe_ids, &"recipe_teddy")
	assert_has(restored.activity_state.active_request_ids, &"request_balloon_hug")
	assert_eq(restored.story_flags[&"balloon_hug"], &"comfort")
	assert_eq(restored.protagonist_aspect_counts[&"lamp"], 4)
	assert_true(restored.first_crafted_output_ids.has(&"craft_clear_receiver"))


func test_legacy_linear_shelves_migrate_into_pages() -> void:
	var source := SlotCommerceState.new(PlayerWallet.new(120), 7)
	source.set_owner_level(&"balloon", 1)
	var payload := repository.to_dictionary(source)
	var toy_store := payload.stores["toy"] as Dictionary
	toy_store.erase("unlocked_page_count")
	toy_store["capacity"] = 7
	for shelf in toy_store.shelves:
		(shelf as Dictionary).erase("page_index")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

	var restored := SlotCommerceState.new(PlayerWallet.new(1), 99)
	assert_true(repository.load_into(restored).ok)
	var toy := restored.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_eq(toy.unlocked_page_count, 2)
	assert_eq(toy.shelf_slots_for_page(1).size(), 6)
	assert_eq(toy.shelf_slots_for_page(2).size(), 1)
	assert_eq(toy.shelf_slots_for_page(2)[0].item_id, &"toy_windup_moth")


func test_active_synthesis_resumes_remaining_time_and_cannot_duplicate_output() -> void:
	var source := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var inputs: Array[CardItemState] = [
		_add_card(source, &"record_fluorescent_single", 100),
		_add_card(source, &"toy_glass_marble", 101),
		_add_card(source, &"fast_hash_brown", 102),
	]
	_assign_radio_inputs(source, inputs)
	assert_true(source.begin_synthesis(&"recipe_night_radio", 10.0).ok)
	source.advance_synthesis(3.25)
	assert_true(repository.save(source))

	var restored := SlotCommerceState.new(PlayerWallet.new(1), 99)
	assert_true(repository.load_into(restored).ok)
	assert_not_null(restored.active_synthesis)
	assert_almost_eq(restored.active_synthesis.remaining_seconds, 6.75, 0.001)
	assert_false(restored.activity_state.return_card_to_hand(
		restored.card_by_instance_id(100)
	))
	var completed := restored.advance_synthesis(6.75)
	assert_true(completed.ok)
	assert_eq(restored.inventory.size(), 1)
	assert_eq(restored.inventory[0].definition_id, &"craft_clear_receiver")
	assert_eq(restored.protagonist_aspect_counts[&"lamp"], 1)
	assert_true(repository.save(restored))

	var reloaded := SlotCommerceState.new(PlayerWallet.new(1), 101)
	assert_true(repository.load_into(reloaded).ok)
	assert_null(reloaded.active_synthesis)
	assert_eq(reloaded.inventory.size(), 1)
	assert_eq(reloaded.inventory[0].definition_id, &"craft_clear_receiver")
	assert_eq(reloaded.protagonist_aspect_counts[&"lamp"], 1)


func test_pending_night_transition_resumes_before_and_after_atomic_consumption() -> void:
	var source := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var food := _add_card(source, &"fast_hash_brown", 100)
	var flower := _add_card(source, &"flower_sunflower", 101)
	assert_true(source.activity_state.assign_card(&"wish_hungry", &"hungry", food).ok)
	assert_true(source.activity_state.assign_card(&"wish_bedside", &"bedside", flower).ok)
	assert_true(source.activity_state.confirm_daily_wish(&"wish_hungry").ok)
	assert_true(source.activity_state.confirm_daily_wish(&"wish_bedside").ok)
	assert_true(source.begin_night_transition().ok)
	assert_true(repository.save(source))

	var before_consumption := SlotCommerceState.new(PlayerWallet.new(1), 99)
	assert_true(repository.load_into(before_consumption).ok)
	assert_not_null(before_consumption.pending_transition)
	assert_false(before_consumption.pending_transition.consumption_applied)
	var consumed := before_consumption.apply_night_transition_consumption()
	assert_true(consumed.ok)
	assert_eq(consumed.consumed_count, 2)
	assert_true(before_consumption.inventory.is_empty())
	assert_eq(before_consumption.protagonist_aspect_counts[&"lamp"], 2)
	assert_true(before_consumption.mark_night_transition_result_shown())
	assert_eq(before_consumption.pending_transition.next_result_index, 1)
	assert_true(repository.save(before_consumption))

	var after_consumption := SlotCommerceState.new(PlayerWallet.new(1), 101)
	assert_true(repository.load_into(after_consumption).ok)
	assert_true(after_consumption.pending_transition.consumption_applied)
	assert_eq(after_consumption.pending_transition.next_result_index, 1)
	assert_true(after_consumption.apply_night_transition_consumption().already_applied)
	assert_eq(after_consumption.protagonist_aspect_counts[&"lamp"], 2)
	var finished := after_consumption.finish_night_transition()
	assert_true(finished.ok)
	assert_eq(after_consumption.day, 2)
	assert_eq(after_consumption.wallet.money, 220)


func _add_card(
	commerce: SlotCommerceState,
	definition_id: StringName,
	instance_id: int,
) -> CardItemState:
	var card := CardItemState.new(instance_id, definition_id)
	commerce.inventory.append(card)
	return card


func _assign_radio_inputs(
	commerce: SlotCommerceState,
	inputs: Array[CardItemState],
) -> void:
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"sound", inputs[0]
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"shell", inputs[1]
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"tuning", inputs[2]
	).ok)
