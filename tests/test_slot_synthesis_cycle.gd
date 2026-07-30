extends GutTest


func test_synthesis_locks_inputs_then_atomically_creates_clear_receiver() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var inputs := _add_clear_receiver_inputs(commerce, 100)
	_assign_radio_inputs(commerce, inputs)

	var started := commerce.begin_synthesis(&"recipe_night_radio", 2.5)
	assert_true(started.ok)
	assert_not_null(commerce.active_synthesis)
	assert_true(commerce.activity_state.locked_activity_ids.has(&"recipe_night_radio"))
	assert_false(commerce.activity_state.return_card_to_hand(inputs[0]))
	assert_false(commerce.advance_synthesis(1.0).completed)
	assert_eq(commerce.inventory.size(), 3)

	var completed := commerce.advance_synthesis(1.5)
	assert_true(completed.ok)
	assert_true(completed.completed)
	assert_eq(completed.consumed_count, 3)
	assert_true(completed.first_reward_applied)
	assert_null(commerce.active_synthesis)
	assert_false(commerce.activity_state.locked_activity_ids.has(&"recipe_night_radio"))
	assert_eq(commerce.inventory.size(), 1)
	assert_eq(commerce.inventory[0].definition_id, &"craft_clear_receiver")
	assert_eq(commerce.inventory[0].location, CardItemState.Location.HAND)
	assert_eq(commerce.protagonist_aspect_counts[&"lamp"], 1)


func test_first_craft_reward_is_not_repeated_for_same_output() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var first_inputs := _add_clear_receiver_inputs(commerce, 100)
	_assign_radio_inputs(commerce, first_inputs)
	assert_true(commerce.begin_synthesis(&"recipe_night_radio", 0.0).ok)
	assert_true(commerce.advance_synthesis(0.0).first_reward_applied)

	var second_inputs := _add_clear_receiver_inputs(commerce, 200)
	_assign_radio_inputs(commerce, second_inputs)
	assert_true(commerce.begin_synthesis(&"recipe_night_radio", 0.0).ok)
	var repeated := commerce.advance_synthesis(0.0)

	assert_true(repeated.ok)
	assert_false(repeated.first_reward_applied)
	assert_eq(commerce.protagonist_aspect_counts[&"lamp"], 1)
	var clear_receiver_count := 0
	for card in commerce.inventory:
		if card.definition_id == &"craft_clear_receiver":
			clear_receiver_count += 1
	assert_eq(clear_receiver_count, 2)


func test_candle_dominant_inputs_create_tide_receiver_and_candle_reward() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var inputs: Array[CardItemState] = [
		_add_card(commerce, &"record_lullaby_cassette", 100),
		_add_card(commerce, &"toy_glass_marble", 101),
		_add_card(commerce, &"book_aquarium_issue", 102),
	]
	_assign_radio_inputs(commerce, inputs)
	assert_true(commerce.begin_synthesis(&"recipe_night_radio", 0.0).ok)

	var completed := commerce.advance_synthesis(0.0)

	assert_true(completed.ok)
	assert_eq(completed.output_id, &"craft_tide_receiver")
	assert_eq(commerce.inventory[0].definition_id, &"craft_tide_receiver")
	assert_eq(commerce.protagonist_aspect_counts[&"candle"], 1)


func test_incomplete_recipe_does_not_start_or_lock() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var result := commerce.begin_synthesis(&"recipe_night_radio")

	assert_false(result.ok)
	assert_eq(result.reason, SlotCommerceState.RESULT_RECIPE_NOT_READY)
	assert_null(commerce.active_synthesis)
	assert_true(commerce.activity_state.locked_activity_ids.is_empty())


func test_active_synthesis_blocks_duplicate_start_and_night_transition() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var inputs := _add_clear_receiver_inputs(commerce, 100)
	_assign_radio_inputs(commerce, inputs)
	assert_true(commerce.begin_synthesis(&"recipe_night_radio", 2.5).ok)

	var duplicate := commerce.begin_synthesis(&"recipe_night_radio", 2.5)
	var transition := commerce.begin_night_transition()

	assert_false(duplicate.ok)
	assert_eq(duplicate.reason, SlotCommerceState.RESULT_SYNTHESIS_ACTIVE)
	assert_false(transition.ok)
	assert_eq(transition.reason, SlotCommerceState.RESULT_SYNTHESIS_ACTIVE)


func test_unlocked_teddy_recipe_supports_mirror_and_pillow_outputs() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	commerce.activity_state.known_recipe_ids.append(&"recipe_teddy")
	var mirror_inputs: Array[CardItemState] = [
		_add_card(commerce, &"toy_cloth_scraps", 300),
		_add_card(commerce, &"toy_glass_marble", 301),
		_add_card(commerce, &"flower_lavender_sachet", 302),
	]
	_assign_teddy_inputs(commerce, mirror_inputs)
	assert_true(commerce.begin_synthesis(&"recipe_teddy", 0.0).ok)
	var mirror_result := commerce.advance_synthesis(0.0)
	assert_eq(mirror_result.output_id, &"craft_childhood_teddy")
	assert_eq(commerce.protagonist_aspect_counts[&"mirror"], 1)

	var pillow_inputs: Array[CardItemState] = [
		_add_card(commerce, &"flower_lavender_sachet", 400),
		_add_card(commerce, &"toy_cloth_scraps", 401),
		_add_card(commerce, &"fast_warm_milk", 402),
	]
	_assign_teddy_inputs(commerce, pillow_inputs)
	assert_true(commerce.begin_synthesis(&"recipe_teddy", 0.0).ok)
	var pillow_result := commerce.advance_synthesis(0.0)
	assert_eq(pillow_result.output_id, &"craft_comfort_bear")
	assert_eq(commerce.protagonist_aspect_counts[&"pillow"], 1)
	assert_lt(SlotDemoCatalog.item_by_id(&"craft_childhood_teddy").resale_value(), 52)
	assert_lt(SlotDemoCatalog.item_by_id(&"craft_comfort_bear").resale_value(), 52)


func _add_clear_receiver_inputs(
	commerce: SlotCommerceState,
	first_instance_id: int,
) -> Array[CardItemState]:
	return [
		_add_card(commerce, &"record_fluorescent_single", first_instance_id),
		_add_card(commerce, &"toy_glass_marble", first_instance_id + 1),
		_add_card(commerce, &"fast_hash_brown", first_instance_id + 2),
	]


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


func _assign_teddy_inputs(
	commerce: SlotCommerceState,
	inputs: Array[CardItemState],
) -> void:
	assert_true(commerce.activity_state.assign_card(
		&"recipe_teddy", &"soft_filling", inputs[0]
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_teddy", &"toy_shape", inputs[1]
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_teddy", &"calm", inputs[2]
	).ok)


func _add_card(
	commerce: SlotCommerceState,
	definition_id: StringName,
	instance_id: int,
) -> CardItemState:
	var card := CardItemState.new(instance_id, definition_id)
	commerce.inventory.append(card)
	return card
