extends GutTest


func test_formal_manifest_has_rooms_owner_requests_and_tin_frog_in_hand() -> void:
	var content := QuestArcCatalog.manifest()
	assert_not_null(content)
	assert_eq(content.tasks.size(), 5)
	assert_eq(content.expedition_rooms.size(), 9)
	var room_ids: Array[StringName] = []
	for raw_room in content.expedition_rooms:
		room_ids.append((raw_room as MallRoomDefinition).id)
	room_ids.sort()
	var expected_room_ids: Array[StringName] = [
		&"birthday_party",
		&"gray_hall",
		&"home",
		&"rainforest",
		&"retro_restaurant",
		&"salvage_yard",
		&"scanner",
		&"shelf_shift",
		&"spaceship_library_city",
	]
	expected_room_ids.sort()
	assert_eq(room_ids, expected_room_ids)
	assert_eq(MallDoorGenerator.CHALLENGE_CHANCE, 0.60)
	assert_eq(
		QuestArcCatalog.mall_room_by_id(&"home").generation_weight,
		3,
	)
	assert_eq(
		QuestArcCatalog.mall_room_by_id(&"rainforest").generation_weight,
		1,
	)
	assert_eq(
		QuestArcCatalog.mall_room_by_id(&"retro_restaurant").generation_weight,
		2,
	)
	assert_eq(
		QuestArcCatalog.mall_room_by_id(&"shelf_shift").generation_weight,
		3,
	)
	assert_eq(
		QuestArcCatalog.mall_room_by_id(&"salvage_yard").generation_weight,
		1,
	)
	assert_true(content.starting_item_ids.has(&"tin_frog"))
	var errors := content.validation_errors()
	assert_true(errors.is_empty(), str(errors))
	var state := QuestGameState.new()
	assert_eq(state.inventory.size(), 1)
	assert_eq(state.inventory[0].definition_id, &"tin_frog")


func test_challenge_feedback_uses_category_presence_then_total_deficit() -> void:
	var room := _challenge_room([&"light"], 5)
	var enough := MallChallengeRules.evaluate(room, [_item({&"light": 5})])
	assert_eq(enough.feedback_tier, MallChallengeRules.FEEDBACK_ENOUGH)
	assert_eq(enough.success_probability, 100)
	var one_short := MallChallengeRules.evaluate(room, [_item({&"light": 4})])
	assert_eq(one_short.feedback_tier, MallChallengeRules.FEEDBACK_MAYBE)
	assert_eq(one_short.success_probability, 50)
	var two_short := MallChallengeRules.evaluate(room, [_item({&"light": 3})])
	assert_eq(two_short.success_probability, 20)
	var hopeless := MallChallengeRules.evaluate(room, [_item({&"light": 2})])
	assert_eq(hopeless.feedback_tier, MallChallengeRules.FEEDBACK_HOPELESS)
	assert_eq(hopeless.success_probability, 0)


func test_multi_shape_requirement_needs_each_category_and_uses_sum() -> void:
	var room := _challenge_room([&"light", &"tear"], 7)
	var missing_category := MallChallengeRules.evaluate(
		room, [_item({&"light": 7})]
	)
	assert_false(missing_category.shapes_met)
	assert_eq(missing_category.success_probability, 0)
	var ready := MallChallengeRules.evaluate(
		room, [_item({&"light": 6, &"tear": 1})]
	)
	assert_true(ready.shapes_met)
	assert_eq(ready.success_probability, 100)


func test_boss_chance_grows_by_thirds_and_only_runs_for_second_selection() -> void:
	assert_eq(MallDoorGenerator.boss_chance(0), 0.0)
	assert_almost_eq(MallDoorGenerator.boss_chance(1), 1.0 / 3.0, 0.0001)
	assert_almost_eq(MallDoorGenerator.boss_chance(2), 2.0 / 3.0, 0.0001)
	assert_eq(MallDoorGenerator.boss_chance(3), 1.0)
	var run := MallExpeditionState.new()
	run.begin_night(1, 7)
	for room_id in [
		&"spaceship_library_city",
		&"gray_hall",
		&"birthday_party",
	]:
		run.first_cleared_challenge_ids[room_id] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	run.economy_offer_seen = true
	var first_selection := MallDoorGenerator.generate(
		run, QuestArcCatalog.manifest().expedition_rooms, rng
	)
	assert_false(first_selection.has(&"scanner"))
	assert_eq(first_selection.size(), 2)
	for room_id in first_selection:
		assert_eq(
			QuestArcCatalog.mall_room_by_id(room_id).category,
			MallRoomDefinition.Category.REST,
		)
	run.rooms_completed = 1
	assert_eq(
		MallDoorGenerator.generate(run, QuestArcCatalog.manifest().expedition_rooms, rng),
		[&"scanner"],
	)


func test_ordinary_door_pair_is_distinct_and_excludes_rooms_entered_that_night() -> void:
	var run := MallExpeditionState.new()
	run.begin_night(1, 91)
	run.entered_room_ids[&"gray_hall"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var doors := MallDoorGenerator.generate(
		run, QuestArcCatalog.manifest().expedition_rooms, rng
	)
	assert_eq(doors.size(), 2)
	assert_ne(doors[0], doors[1])
	assert_false(doors.has(&"gray_hall"))


func test_economy_offer_is_once_per_night_and_uses_three_to_one_weights() -> void:
	var shelf_offers := 0
	var salvage_offers := 0
	for seed_value in 800:
		var run := MallExpeditionState.new()
		run.begin_night(1, seed_value + 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 1
		var doors := MallDoorGenerator.generate(
			run, QuestArcCatalog.manifest().expedition_rooms, rng
		)
		var economy_id: StringName
		if doors.has(&"shelf_shift"):
			economy_id = &"shelf_shift"
			shelf_offers += 1
		elif doors.has(&"salvage_yard"):
			economy_id = &"salvage_yard"
			salvage_offers += 1
		if not economy_id.is_empty():
			assert_true(run.economy_offer_seen)
			var second_doors := MallDoorGenerator.generate(
				run, QuestArcCatalog.manifest().expedition_rooms, rng
			)
			assert_true(run.economy_offer_seen)
			assert_eq(second_doors.size(), 2)
			assert_false(second_doors.has(&"shelf_shift"))
			assert_false(second_doors.has(&"salvage_yard"))
	assert_gt(shelf_offers, 0)
	assert_gt(salvage_offers, 0)
	var ratio := float(shelf_offers) / float(salvage_offers)
	assert_gt(ratio, 2.0)
	assert_lt(ratio, 4.2)


func test_first_cleared_challenge_never_returns_to_the_door_pool() -> void:
	for seed_value in 100:
		var run := MallExpeditionState.new()
		run.begin_night(1, seed_value + 1)
		run.economy_offer_seen = true
		run.first_cleared_challenge_ids[&"gray_hall"] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 1
		var doors := MallDoorGenerator.generate(
			run, QuestArcCatalog.manifest().expedition_rooms, rng
		)
		assert_false(doors.has(&"gray_hall"), str(seed_value))


func test_failed_challenge_commits_wound_discovery_and_next_checkpoint() -> void:
	var state := QuestGameState.new()
	state.gain_disease(&"white_flower")
	state.expedition.begin_night(state.day, 31)
	state.expedition.current_door_ids = [&"gray_hall"]
	var result := state.complete_expedition_room(
		&"gray_hall",
		[],
		[],
		[{"approach_index": 0, "card_instance_ids": [], "persona_shape_ids": []}],
	)
	assert_true(result.ok)
	assert_false(result.success)
	assert_true(state.expedition.is_discovered(&"gray_hall"))
	assert_false(state.expedition.is_first_cleared(&"gray_hall"))
	assert_eq(state.expedition.rooms_completed, 1)
	assert_eq(state.inventory[-1].definition_id, &"expedition_wound")
	assert_eq(state.disease_count(&"white_flower"), 0)
	assert_eq(state.disease_count(&"expedition_wound"), 1)
	assert_eq(state.expedition.current_door_ids.size(), 2)


func test_successful_challenge_uses_persona_without_consuming_it() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 5
	state.expedition.begin_night(state.day, 17)
	state.expedition.current_door_ids = [&"birthday_party"]
	var inventory_count := state.inventory.size()
	var result := state.complete_expedition_room(
		&"birthday_party",
		[],
		[],
		[{
			"approach_index": 1,
			"card_instance_ids": [],
			"persona_shape_ids": [&"light"],
		}],
	)
	assert_true(result.ok)
	assert_true(result.success)
	assert_true(state.expedition.is_first_cleared(&"birthday_party"))
	assert_eq(state.inventory.size(), inventory_count + 1)
	assert_eq(state.inventory[-1].definition_id, &"expedition_salvage")


func test_rest_growth_consumes_item_and_increases_each_stronger_shape_once() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 0
	state.protagonist_shape_levels[&"dream"] = 0
	var card := state.grant_item(&"kaleidoscope", &"test")
	state.expedition.begin_night(state.day, 3)
	state.expedition.current_door_ids = [&"home"]
	var result := state.complete_expedition_room(&"home", [card.instance_id])
	assert_true(result.ok)
	assert_null(state.card_by_instance_id(card.instance_id))
	assert_eq(state.protagonist_shape_levels[&"light"], 1)
	assert_eq(state.protagonist_shape_levels[&"dream"], 1)
	assert_eq(state.disease_count(&"white_flower"), 1)


func test_work_room_pays_twenty_and_does_not_add_wage_to_hand() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(state.day, 8)
	state.expedition.current_door_ids = [&"shelf_shift"]
	var inventory_count := state.inventory.size()
	var result := state.complete_expedition_room(&"shelf_shift")
	assert_true(result.ok)
	assert_eq(result.money_gained, 20)
	assert_eq(state.wallet.money, 20)
	assert_eq(state.inventory.size(), inventory_count)


func test_second_room_advances_day_and_returns_to_courtyard() -> void:
	var state := QuestGameState.new()
	state.day = 3
	state.transaction_for_store(&"toy").shelf_slots[0].clear()
	state.expedition.begin_night(state.day, 22)
	state.expedition.rooms_completed = 1
	state.expedition.current_door_ids = [&"shelf_shift"]
	var result := state.complete_expedition_room(&"shelf_shift")
	assert_true(result.night_finished)
	assert_eq(state.day, 4)
	assert_false(state.expedition.active)
	assert_eq(
		state.transaction_for_store(&"toy").shelf_slots[0].item_id,
		&"kaleidoscope",
	)


func test_door_checkpoint_round_trips_without_rerolling() -> void:
	var state := QuestGameState.new()
	assert_true(state.begin_mall_expedition(123456).ok)
	var expected_doors := state.expedition.current_door_ids.duplicate()
	var expected_rng_state := state.expedition.rng_state
	var repository := QuestSaveRepository.new("user://test_expedition_checkpoint.json")
	repository.erase()
	assert_true(repository.save(state))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_true(restored.expedition.active)
	assert_eq(restored.expedition.current_door_ids, expected_doors)
	assert_eq(restored.expedition.rng_state, expected_rng_state)
	repository.erase()


func test_rest_room_type_filters_and_rainforest_shape_growth() -> void:
	var state := QuestGameState.new()
	var frog := state.inventory[0]
	var food := state.grant_item(&"mung_bean_cake", &"test")
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", frog))
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", food))
	var shape_before := int(state.protagonist_shape_levels[&"light"])
	state.expedition.begin_night(1, 3)
	state.expedition.current_door_ids = [&"rainforest"]
	var result := state.complete_expedition_room(&"rainforest", [], [&"light"])
	assert_true(result.ok)
	assert_eq(state.protagonist_shape_levels[&"light"], shape_before + 1)
	assert_eq(state.disease_count(&"white_flower"), 2)
	assert_true(state.inventory.has(frog))
	assert_true(state.inventory.has(food))


func test_three_reward_rooms_enforce_their_confirmed_card_categories() -> void:
	var state := QuestGameState.new()
	var toy := state.inventory[0]
	var food := state.grant_item(&"fries", &"test")
	var drink := state.grant_item(&"milkshake", &"test")
	var wound := state.grant_item(&"expedition_wound", &"test")
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", food))
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", drink))
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", toy))
	assert_true(state.expedition_room_accepts_card(&"home", toy))
	assert_false(state.expedition_room_accepts_card(&"home", wound))
	assert_true(
		state.expedition_room_accepts_card(&"rainforest", null, &"light")
	)
	assert_false(state.expedition_room_accepts_card(&"rainforest", toy))


func test_each_reward_room_can_be_left_empty_for_twenty_without_white_flower() -> void:
	for room_id in [&"home", &"rainforest", &"retro_restaurant"]:
		var state := QuestGameState.new()
		state.expedition.begin_night(1, 35)
		state.expedition.current_door_ids = [room_id]
		var result := state.complete_expedition_room(room_id)
		assert_true(result.ok, room_id)
		assert_eq(result.money_gained, 20, room_id)
		assert_eq(state.wallet.money, 20, room_id)
		assert_eq(state.disease_count(&"white_flower"), 0, room_id)


func test_used_rest_item_with_no_growth_is_consumed_and_still_grants_white_flower() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 5
	var frog := state.inventory[0]
	state.expedition.begin_night(1, 36)
	state.expedition.current_door_ids = [&"home"]
	var result := state.complete_expedition_room(&"home", [frog.instance_id])
	assert_true(result.ok)
	assert_true(result.shape_growth.is_empty())
	assert_eq(result.money_gained, 0)
	assert_null(state.card_by_instance_id(frog.instance_id))
	assert_eq(state.disease_count(&"white_flower"), 1)


func test_salvage_room_sells_up_to_three_items_at_full_recorded_value() -> void:
	var state := QuestGameState.new()
	var fries := state.grant_item(&"fries", &"test", 8)
	var gardenia := state.grant_item(&"gardenia", &"test")
	state.expedition.begin_night(1, 4)
	state.expedition.current_door_ids = [&"salvage_yard"]
	var result := state.complete_expedition_room(
		&"salvage_yard", [fries.instance_id, gardenia.instance_id]
	)
	assert_true(result.ok)
	assert_eq(result.money_gained, 32)
	assert_eq(state.wallet.money, 32)
	assert_null(state.card_by_instance_id(fries.instance_id))
	assert_null(state.card_by_instance_id(gardenia.instance_id))
	assert_eq(state.disease_count(&"white_flower"), 0)


func test_salvage_rejects_a_fourth_item_without_consuming_anything() -> void:
	var state := QuestGameState.new()
	var cards: Array[CardItemState] = []
	for item_id in [&"fries", &"milkshake", &"jasmine", &"tin_frog"]:
		cards.append(state.grant_item(item_id, &"test"))
	state.expedition.begin_night(1, 48)
	state.expedition.current_door_ids = [&"salvage_yard"]
	var ids: Array[int] = []
	for card in cards:
		ids.append(card.instance_id)
	var result := state.complete_expedition_room(&"salvage_yard", ids)
	assert_false(result.ok)
	for card in cards:
		assert_true(state.inventory.has(card))


func test_rest_growth_from_zero_no_longer_queues_a_persona_reveal() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 0
	var item := state.grant_item(&"cactus", &"test")
	state.expedition.begin_night(1, 6)
	state.expedition.current_door_ids = [&"home"]
	var result := state.complete_expedition_room(&"home", [item.instance_id])
	assert_true(result.ok)
	assert_true(result.new_persona_shape_ids.is_empty())
	assert_true(state.pending_persona_reveal_shape_ids.is_empty())
	assert_eq(state.disease_count(&"white_flower"), 1)


func test_diseases_are_gained_then_remove_one_opposite_per_card() -> void:
	var state := QuestGameState.new()
	assert_true(state.gain_disease(&"white_flower", 2).ok)
	assert_eq(state.disease_count(&"white_flower"), 2)
	assert_eq(state.disease_count(&"expedition_wound"), 0)
	assert_true(state.gain_disease(&"expedition_wound").ok)
	assert_eq(state.disease_count(&"white_flower"), 1)
	assert_eq(state.disease_count(&"expedition_wound"), 1)
	assert_true(state.gain_disease(&"white_flower").ok)
	assert_eq(state.disease_count(&"white_flower"), 2)
	assert_eq(state.disease_count(&"expedition_wound"), 0)


func test_disease_cards_only_enter_the_synthesis_base_slot() -> void:
	var state := QuestGameState.new()
	var wound_id := int(state.gain_disease(&"expedition_wound").granted_instance_ids[0])
	var wound_card := state.card_by_instance_id(wound_id)
	assert_true(state.assign_synthesis_base(wound_card).ok)
	assert_true(state.return_card_to_hand(wound_card))
	var frog := state.inventory[0]
	assert_true(state.assign_synthesis_base(frog).ok)
	assert_false(state.assign_synthesis_helper(wound_card).ok)
	state.clear_synthesis_draft()
	assert_false(state.expedition_room_accepts_card(&"home", wound_card))
	assert_false(state.expedition_room_accepts_card(&"gray_hall", wound_card))
	assert_false(state.unlock_store(&"toy", wound_card).ok)


func test_keepsakes_are_reserved_for_request_slots() -> void:
	var state := QuestGameState.new()
	var keepsake := state.grant_item(&"concrete_city_vol_2", &"test")
	var definition := state.definition_for_card(keepsake)
	assert_not_null(definition)
	assert_true(definition.has_property(CardPropertySet.PROPERTY_KEEPSAKE))
	assert_false(state.assign_synthesis_base(keepsake).ok)

	var frog := state.inventory[0]
	assert_true(state.assign_synthesis_base(frog).ok)
	assert_false(state.assign_synthesis_helper(keepsake).ok)
	state.clear_synthesis_draft()
	assert_false(state.expedition_card_can_be_used(keepsake))
	assert_false(state.stage_recycle_card(keepsake).ok)
	assert_false(MallChallengeRules.can_use_in_challenge(definition))

	var request_rule := CardSlotRule.new()
	request_rule.id = &"keepsake_request"
	request_rule.required_all = [&"keepsake"]
	assert_true(CardRuleEvaluator.can_execute(request_rule, definition))
	var unlock := StoreUnlockDefinition.new()
	unlock.id = &"keepsake_unlock"
	unlock.store_id = &"test"
	unlock.slot_rule = request_rule
	assert_false(QuestArcRules.store_unlock_accepts(unlock, definition))


func test_shopping_card_contributes_all_four_shapes_without_being_a_type() -> void:
	var state := QuestGameState.new()
	var shopping_card := state.grant_item(&"shopping_card", &"test")
	var definition := state.definition_for_card(shopping_card)
	assert_not_null(definition)
	assert_true(definition.property_set.tags.is_empty())
	for shape_id in CardPropertySet.SHAPES:
		assert_eq(definition.property_value(shape_id), 2, shape_id)
	assert_true(state.expedition_card_can_be_used(shopping_card))

	var room := _challenge_room([&"light", &"tear"], 4)
	var evaluation := MallChallengeRules.evaluate(room, [definition])
	assert_eq(evaluation.feedback_tier, MallChallengeRules.FEEDBACK_ENOUGH)
	assert_eq(evaluation.success_probability, 100)

	assert_true(state.assign_synthesis_base(state.inventory[0]).ok)
	assert_true(state.assign_synthesis_helper(shopping_card).ok)


func test_disease_death_is_checked_only_when_starting_an_expedition() -> void:
	var state := QuestGameState.new()
	state.gain_disease(&"white_flower", 3)
	assert_false(state.expedition.active)
	assert_eq(state.disease_count(&"white_flower"), 3)
	var result := state.begin_mall_expedition(919)
	assert_true(result.ok)
	assert_true(result.game_over)
	assert_true(state.expedition.active)
	assert_eq(state.expedition.disease_game_over_id, &"white_flower")
	assert_true(state.expedition.current_door_ids.is_empty())


func test_outputless_disease_recipe_consumes_inputs_and_only_grows_used_path() -> void:
	var state := QuestGameState.new()
	var gained := state.gain_disease(&"white_flower")
	var white_flower := state.card_by_instance_id(int(gained.granted_instance_ids[0]))
	var cactus := state.grant_item(&"cactus", &"test")
	assert_true(state.assign_synthesis_base(white_flower).ok)
	assert_true(state.assign_synthesis_helper(cactus).ok)
	assert_true(state.select_synthesis_persona(&"light"))
	assert_true(state.select_synthesis_candidate(&"recipe_clear_white_flower_light"))
	var result := state.begin_synthesis()
	assert_true(result.ok)
	assert_null(result.output)
	assert_null(state.card_by_instance_id(white_flower.instance_id))
	assert_null(state.card_by_instance_id(cactus.instance_id))
	assert_eq(
		state.synthesis_recipe_requirements(
			QuestArcCatalog.recipe_by_id(&"recipe_clear_white_flower_light")
		),
		{&"light": 4},
	)
	assert_eq(
		state.synthesis_recipe_requirements(
			QuestArcCatalog.recipe_by_id(&"recipe_clear_white_flower_tear")
		),
		{&"tear": 3},
	)


func test_boss_requires_two_successful_rounds_and_then_completes_demo() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 5
	state.expedition.begin_night(1, 12)
	state.expedition.current_door_ids = [&"scanner"]
	var rounds: Array[Dictionary] = []
	for index in 2:
		rounds.append({
			"approach_index": index % 2,
			"card_instance_ids": [],
			"persona_shape_ids": [&"light"],
		})
	var result := state.complete_expedition_room(&"scanner", [], [], rounds)
	assert_true(result.ok)
	assert_true(result.demo_complete)
	assert_true(state.expedition.boss_cleared)
	assert_false(state.expedition.active)
	assert_eq(state.day, 1)


func test_boss_failure_grants_wound_and_immediately_ends_the_night() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 14)
	state.expedition.current_door_ids = [&"scanner"]
	var result := state.complete_expedition_room(
		&"scanner",
		[],
		[],
		[{"approach_index": 0, "card_instance_ids": [], "persona_shape_ids": []}],
	)
	assert_true(result.ok)
	assert_true(result.boss_failed)
	assert_true(result.night_finished)
	assert_eq(state.day, 2)
	assert_eq(state.inventory[-1].definition_id, &"expedition_wound")
	assert_true(state.expedition.is_discovered(&"scanner"))


func _challenge_room(
	shapes: Array[StringName],
	threshold: int,
) -> MallRoomDefinition:
	var room := MallRoomDefinition.new()
	room.id = &"test_room"
	room.display_name_key = &"test.room"
	room.category = MallRoomDefinition.Category.CHALLENGE
	room.required_shape_ids = shapes
	room.shape_total_required = threshold
	room.approach_title_keys = [&"a", &"b"]
	room.approach_text_keys = [&"a", &"b"]
	room.intro_text_keys = [&"intro"]
	room.challenge_text_keys = [&"challenge"]
	return room


func _item(values: Dictionary) -> CardItemDefinition:
	var item := CardItemDefinition.new()
	item.id = &"test_item"
	item.property_set = CardPropertySet.new()
	item.property_set.values = values
	return item
