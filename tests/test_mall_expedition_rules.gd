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
	var approach := _challenge_approach([&"light"], 5)
	var enough := MallChallengeRules.evaluate(approach, [_item({&"light": 5})])
	assert_eq(enough.feedback_tier, MallChallengeRules.FEEDBACK_ENOUGH)
	assert_eq(enough.success_probability, 100)
	var one_short := MallChallengeRules.evaluate(approach, [_item({&"light": 4})])
	assert_eq(one_short.feedback_tier, MallChallengeRules.FEEDBACK_MAYBE)
	assert_eq(one_short.success_probability, 50)
	var two_short := MallChallengeRules.evaluate(approach, [_item({&"light": 3})])
	assert_eq(two_short.success_probability, 20)
	var hopeless := MallChallengeRules.evaluate(approach, [_item({&"light": 2})])
	assert_eq(hopeless.feedback_tier, MallChallengeRules.FEEDBACK_HOPELESS)
	assert_eq(hopeless.success_probability, 0)


func test_multi_shape_requirement_needs_each_category_and_uses_sum() -> void:
	var approach := _challenge_approach([&"light", &"tear"], 7)
	var missing_category := MallChallengeRules.evaluate(
		approach, [_item({&"light": 7})]
	)
	assert_false(missing_category.shapes_met)
	assert_eq(missing_category.success_probability, 0)
	var ready := MallChallengeRules.evaluate(
		approach, [_item({&"light": 6, &"tear": 1})]
	)
	assert_true(ready.shapes_met)
	assert_eq(ready.success_probability, 100)


func test_feedback_shape_prefers_missing_then_lower_then_primary_shape() -> void:
	var approach := _challenge_approach([&"tear", &"sleep"], 6)
	approach.feedback_primary_shape_id = &"tear"
	var missing := MallChallengeRules.evaluate(
		approach, [_item({&"tear": 4})]
	)
	assert_eq(missing.feedback_shape_id, &"sleep")
	var lower := MallChallengeRules.evaluate(
		approach, [_item({&"tear": 3, &"sleep": 1})]
	)
	assert_eq(lower.feedback_shape_id, &"sleep")
	var enough := MallChallengeRules.evaluate(
		approach, [_item({&"tear": 3, &"sleep": 3})]
	)
	assert_eq(enough.feedback_shape_id, &"tear")


func test_specific_persona_and_any_type_are_independent_requirements() -> void:
	var persona_approach := _challenge_approach([&"dream"], 5)
	persona_approach.required_persona_shape_id = &"dream"
	var item_only := MallChallengeRules.evaluate(
		persona_approach, [_item({&"dream": 5})]
	)
	assert_false(item_only.persona_met)
	assert_false(item_only.required_inputs_met)
	var combined := MallChallengeRules.evaluate(
		persona_approach,
		[_item({&"dream": 1}), _item({&"dream": 4})],
		[&"dream"],
	)
	assert_true(combined.persona_met)
	assert_true(combined.required_inputs_met)
	assert_eq(combined.success_probability, 100)

	var gift_approach := _challenge_approach([&"tear", &"sleep"], 4)
	gift_approach.required_any_type_ids = [&"toy", &"flower"]
	var gift := _item({&"tear": 2, &"sleep": 2})
	assert_false(MallChallengeRules.evaluate(gift_approach, [gift]).required_inputs_met)
	gift.property_set.tags = [&"flower"]
	var gift_ready := MallChallengeRules.evaluate(gift_approach, [gift])
	assert_true(gift_ready.types_met)
	assert_true(gift_ready.required_inputs_met)


func test_formal_rooms_keep_distinct_approach_rules_and_fixed_rewards() -> void:
	var spaceship := QuestArcCatalog.mall_room_by_id(&"spaceship_library_city")
	assert_eq(
		spaceship.image_path,
		"res://resources/background/expedition/spaceship-library-city.png",
	)
	assert_true(ResourceLoader.exists(spaceship.image_path))
	var spaceship_round := spaceship.challenge_round_at(0)
	assert_eq(spaceship.reward_item_id, &"concrete_city_vol_2")
	assert_eq(spaceship_round.approach_at(0).required_persona_shape_id, &"dream")
	assert_eq(spaceship_round.approach_at(0).shape_total_required, 5)
	assert_eq(spaceship_round.approach_at(1).required_all_type_ids, [&"book"])
	assert_eq(spaceship_round.approach_at(1).required_shape_ids, [&"light"])

	var gray := QuestArcCatalog.mall_room_by_id(&"gray_hall")
	var gray_round := gray.challenge_round_at(0)
	assert_eq(gray.reward_item_id, &"nocturne_published")
	assert_eq(gray_round.approach_at(0).required_all_type_ids, [&"cassette"])
	assert_eq(gray_round.approach_at(0).shape_total_required, 4)
	assert_eq(gray_round.approach_at(1).required_persona_shape_id, &"tear")

	var birthday := QuestArcCatalog.mall_room_by_id(&"birthday_party")
	var birthday_round := birthday.challenge_round_at(0)
	assert_eq(birthday.reward_item_id, &"birthday_cake")
	assert_eq(birthday_round.approach_at(0).required_any_type_ids, [&"toy", &"flower"])
	assert_eq(birthday_round.approach_at(0).required_shape_ids, [&"tear", &"sleep"])
	assert_eq(birthday_round.approach_at(1).required_persona_shape_id, &"sleep")

	var scanner := QuestArcCatalog.mall_room_by_id(&"scanner")
	assert_eq(scanner.challenge_round_count(), 2)
	assert_eq(scanner.challenge_round_at(0).approach_at(0).shape_total_required, 6)
	assert_eq(scanner.challenge_round_at(1).approach_at(0).required_persona_shape_id, &"sleep")
	assert_eq(scanner.challenge_round_at(1).approach_at(1).required_all_type_ids, [&"flower"])
	assert_eq(scanner.challenge_round_at(1).approach_at(1).feedback_primary_shape_id, &"dream")


func test_each_normal_challenge_grants_its_story_reward() -> void:
	var cases: Array[Dictionary] = [
		{
			"room_id": &"spaceship_library_city",
			"shape_id": &"dream",
			"amount": 5,
			"reward_id": &"concrete_city_vol_2",
		},
		{
			"room_id": &"gray_hall",
			"shape_id": &"tear",
			"amount": 5,
			"reward_id": &"nocturne_published",
		},
		{
			"room_id": &"birthday_party",
			"shape_id": &"sleep",
			"amount": 3,
			"reward_id": &"birthday_cake",
		},
	]
	for case in cases:
		var state := QuestGameState.new()
		var shape_id := StringName(case.shape_id)
		state.protagonist_shape_levels[shape_id] = int(case.amount)
		state.expedition.begin_night(1, 700)
		state.expedition.current_door_ids = [StringName(case.room_id)]
		var result := state.complete_expedition_room(
			StringName(case.room_id),
			[],
			[],
			[{
				"approach_index": 0 if shape_id == &"dream" else 1,
				"card_instance_ids": [],
				"persona_shape_ids": [shape_id],
			}],
		)
		assert_true(result.ok, case.room_id)
		assert_true(result.success, case.room_id)
		assert_eq(result.reward_item_id, case.reward_id, case.room_id)
		assert_eq(state.inventory[-1].definition_id, case.reward_id, case.room_id)


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
	state.protagonist_shape_levels[&"sleep"] = 3
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
			"persona_shape_ids": [&"sleep"],
		}],
	)
	assert_true(result.ok)
	assert_true(result.success)
	assert_true(state.expedition.is_first_cleared(&"birthday_party"))
	assert_eq(state.inventory.size(), inventory_count + 1)
	assert_eq(state.inventory[-1].definition_id, &"birthday_cake")


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
	assert_eq(state.wallet.money, 60)
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
	assert_eq(state.disease_count(&"white_flower"), 1)
	assert_true(state.inventory.has(frog))
	assert_true(state.inventory.has(food))


func test_three_reward_rooms_enforce_their_confirmed_card_categories() -> void:
	var state := QuestGameState.new()
	var toy := state.inventory[0]
	var food := state.grant_item(&"fries", &"test")
	var drink := state.grant_item(&"milkshake", &"test")
	var wound := state.grant_item(&"expedition_wound", &"test")
	var white_flower := state.grant_item(&"white_flower", &"test")
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", food))
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", drink))
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", toy))
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", wound))
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", white_flower))
	assert_true(state.expedition_room_accepts_card(&"home", toy))
	assert_false(state.expedition_room_accepts_card(&"home", wound))
	assert_false(state.expedition_room_accepts_card(&"home", white_flower))
	assert_true(
		state.expedition_room_accepts_card(&"rainforest", null, &"light")
	)
	assert_false(state.expedition_room_accepts_card(&"rainforest", wound))
	assert_false(state.expedition_room_accepts_card(&"rainforest", white_flower))
	assert_false(state.expedition_room_accepts_card(&"rainforest", toy))


func test_each_reward_room_can_be_left_empty_for_twenty_without_white_flower() -> void:
	for room_id in [&"home", &"rainforest", &"retro_restaurant"]:
		var state := QuestGameState.new()
		state.gain_disease(&"expedition_wound")
		state.expedition.begin_night(1, 35)
		state.expedition.current_door_ids = [room_id]
		var result := state.complete_expedition_room(room_id)
		assert_true(result.ok, room_id)
		assert_eq(result.money_gained, 20, room_id)
		assert_eq(state.wallet.money, 60, room_id)
		assert_eq(state.disease_count(&"white_flower"), 0, room_id)
		assert_eq(state.disease_count(&"expedition_wound"), 1, room_id)


func test_used_rest_item_with_no_growth_is_consumed_without_a_white_flower() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 5
	var frog := state.inventory[0]
	state.expedition.begin_night(1, 36)
	state.expedition.current_door_ids = [&"home"]
	var result := state.complete_expedition_room(&"home", [frog.instance_id])
	assert_true(result.ok)
	assert_true(result.shape_growth.is_empty())
	assert_false(result.cleared_wound)
	assert_eq(result.money_gained, 0)
	assert_null(state.card_by_instance_id(frog.instance_id))
	assert_eq(result.white_flower_amount, 0)
	assert_eq(state.disease_count(&"white_flower"), 0)


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
	assert_eq(state.wallet.money, 72)
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


func test_wounds_remove_white_flowers_but_white_flowers_do_not_remove_wounds() -> void:
	var state := QuestGameState.new()
	assert_true(state.gain_disease(&"white_flower", 2).ok)
	assert_eq(state.disease_count(&"white_flower"), 2)
	assert_eq(state.disease_count(&"expedition_wound"), 0)
	assert_true(state.gain_disease(&"expedition_wound").ok)
	assert_eq(state.disease_count(&"white_flower"), 1)
	assert_eq(state.disease_count(&"expedition_wound"), 1)
	assert_true(state.gain_disease(&"white_flower").ok)
	assert_eq(state.disease_count(&"white_flower"), 2)
	assert_eq(state.disease_count(&"expedition_wound"), 1)


func test_item_rest_without_growth_heals_exactly_one_wound() -> void:
	for room_id in [&"home", &"retro_restaurant"]:
		var state := QuestGameState.new()
		for shape_id in CardPropertySet.SHAPES:
			state.protagonist_shape_levels[shape_id] = 10
		state.gain_disease(&"expedition_wound", 2)
		var rest_item := (
			state.inventory[0]
			if room_id == &"home"
			else state.grant_item(&"fries", &"test")
		)
		state.expedition.begin_night(1, 70)
		state.expedition.current_door_ids = [room_id]
		var result := state.complete_expedition_room(room_id, [rest_item.instance_id])
		assert_true(result.ok, room_id)
		assert_true(result.cleared_wound, room_id)
		assert_true(result.shape_growth.is_empty(), room_id)
		assert_eq(result.money_gained, 0, room_id)
		assert_eq(result.white_flower_amount, 0, room_id)
		assert_null(state.card_by_instance_id(rest_item.instance_id), room_id)
		assert_eq(state.disease_count(&"expedition_wound"), 1, room_id)
		assert_eq(state.disease_count(&"white_flower"), 0, room_id)


func test_disease_cards_only_enter_the_synthesis_base() -> void:
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

	var approach := _challenge_approach([&"light", &"tear"], 4)
	var evaluation := MallChallengeRules.evaluate(approach, [definition])
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
	state.protagonist_shape_levels[&"light"] = 6
	state.protagonist_shape_levels[&"sleep"] = 6
	state.expedition.begin_night(1, 12)
	state.expedition.current_door_ids = [&"scanner"]
	var rounds: Array[Dictionary] = []
	rounds.append({
		"approach_index": 0,
		"card_instance_ids": [],
		"persona_shape_ids": [&"light"],
	})
	rounds.append({
		"approach_index": 0,
		"card_instance_ids": [],
		"persona_shape_ids": [&"sleep"],
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


func _challenge_approach(
	shapes: Array[StringName],
	threshold: int,
) -> MallChallengeApproachDefinition:
	var approach := MallChallengeApproachDefinition.new()
	approach.required_shape_ids = shapes
	approach.shape_total_required = threshold
	return approach


func _item(values: Dictionary) -> CardItemDefinition:
	var item := CardItemDefinition.new()
	item.id = &"test_item"
	item.property_set = CardPropertySet.new()
	item.property_set.values = values
	return item
