extends GutTest


func test_formal_manifest_has_rooms_no_tasks_and_tin_frog_in_hand() -> void:
	var content := QuestArcCatalog.manifest()
	assert_not_null(content)
	assert_eq(content.tasks.size(), 0)
	assert_eq(content.expedition_rooms.size(), 14)
	assert_true(content.starting_item_ids.has(&"tin_frog"))
	var errors := content.validation_errors()
	assert_true(errors.is_empty(), str(errors))
	var state := QuestGameState.new()
	assert_eq(state.inventory.size(), 1)
	assert_eq(state.inventory[0].definition_id, &"tin_frog")


func test_challenge_feedback_uses_category_presence_then_total_deficit() -> void:
	var room := _challenge_room([&"nightwalker"], 5)
	var enough := MallChallengeRules.evaluate(room, [_item({&"nightwalker": 5})])
	assert_eq(enough.feedback_tier, MallChallengeRules.FEEDBACK_ENOUGH)
	assert_eq(enough.success_probability, 100)
	var one_short := MallChallengeRules.evaluate(room, [_item({&"nightwalker": 4})])
	assert_eq(one_short.feedback_tier, MallChallengeRules.FEEDBACK_MAYBE)
	assert_eq(one_short.success_probability, 50)
	var two_short := MallChallengeRules.evaluate(room, [_item({&"nightwalker": 3})])
	assert_eq(two_short.success_probability, 20)
	var hopeless := MallChallengeRules.evaluate(room, [_item({&"nightwalker": 2})])
	assert_eq(hopeless.feedback_tier, MallChallengeRules.FEEDBACK_HOPELESS)
	assert_eq(hopeless.success_probability, 0)


func test_multi_persona_requirement_needs_each_category_and_uses_sum() -> void:
	var room := _challenge_room([&"nightwalker", &"mourner"], 7)
	var missing_category := MallChallengeRules.evaluate(
		room, [_item({&"nightwalker": 7})]
	)
	assert_false(missing_category.personas_met)
	assert_eq(missing_category.success_probability, 0)
	var ready := MallChallengeRules.evaluate(
		room, [_item({&"nightwalker": 6, &"mourner": 1})]
	)
	assert_true(ready.personas_met)
	assert_eq(ready.success_probability, 100)


func test_boss_is_forced_at_five_first_clears() -> void:
	var run := MallExpeditionState.new()
	run.begin_night(1, 7)
	for room_id in [
		&"spaceship_library_city",
		&"gray_hall",
		&"anniversary_corridor",
		&"aquarium",
		&"clothing_area",
	]:
		run.first_cleared_challenge_ids[room_id] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
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


func test_work_check_stops_after_a_work_door_has_appeared() -> void:
	var found_work_seed := false
	for seed_value in 200:
		var run := MallExpeditionState.new()
		run.begin_night(1, seed_value + 1)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 1
		var doors := MallDoorGenerator.generate(
			run, QuestArcCatalog.manifest().expedition_rooms, rng
		)
		if doors.has(&"cold_storage") or doors.has(&"shelf_shift"):
			found_work_seed = true
			assert_true(run.work_offer_seen)
			var second_doors := MallDoorGenerator.generate(
				run, QuestArcCatalog.manifest().expedition_rooms, rng
			)
			assert_true(run.work_offer_seen)
			assert_eq(second_doors.size(), 2)
			assert_false(second_doors.has(&"cold_storage"))
			assert_false(second_doors.has(&"shelf_shift"))
			break
	assert_true(found_work_seed)


func test_failed_challenge_commits_wound_discovery_and_next_checkpoint() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(state.day, 31)
	state.expedition.current_door_ids = [&"gray_hall"]
	var result := state.complete_expedition_room(
		&"gray_hall",
		[],
		[],
		[{"approach_index": 0, "card_instance_ids": [], "persona_ids": []}],
	)
	assert_true(result.ok)
	assert_false(result.success)
	assert_true(state.expedition.is_discovered(&"gray_hall"))
	assert_false(state.expedition.is_first_cleared(&"gray_hall"))
	assert_eq(state.expedition.rooms_completed, 1)
	assert_eq(state.inventory[-1].definition_id, &"expedition_wound")
	assert_eq(state.expedition.current_door_ids.size(), 2)


func test_successful_challenge_uses_persona_without_consuming_it() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"nightwalker"] = 5
	state.expedition.begin_night(state.day, 17)
	state.expedition.current_door_ids = [&"aquarium"]
	var inventory_count := state.inventory.size()
	var result := state.complete_expedition_room(
		&"aquarium",
		[],
		[],
		[{
			"approach_index": 1,
			"card_instance_ids": [],
			"persona_ids": [&"nightwalker"],
		}],
	)
	assert_true(result.ok)
	assert_true(result.success)
	assert_true(state.expedition.is_first_cleared(&"aquarium"))
	assert_eq(state.inventory.size(), inventory_count + 1)
	assert_eq(state.inventory[-1].definition_id, &"expedition_salvage")


func test_rest_growth_consumes_item_and_increases_each_stronger_persona_once() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"nightwalker"] = 0
	state.protagonist_persona_counts[&"dreamwalker"] = 0
	var card := state.grant_item(&"kaleidoscope", &"test")
	state.expedition.begin_night(state.day, 3)
	state.expedition.current_door_ids = [&"home"]
	var result := state.complete_expedition_room(&"home", [card.instance_id])
	assert_true(result.ok)
	assert_null(state.card_by_instance_id(card.instance_id))
	assert_eq(state.protagonist_persona_counts[&"nightwalker"], 1)
	assert_eq(state.protagonist_persona_counts[&"dreamwalker"], 1)


func test_work_room_pays_twelve_and_does_not_add_wage_to_hand() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(state.day, 8)
	state.expedition.current_door_ids = [&"cold_storage"]
	var inventory_count := state.inventory.size()
	var result := state.complete_expedition_room(&"cold_storage")
	assert_true(result.ok)
	assert_eq(result.money_gained, 12)
	assert_eq(state.wallet.money, 12)
	assert_eq(state.inventory.size(), inventory_count)


func test_third_room_advances_day_and_returns_to_courtyard() -> void:
	var state := QuestGameState.new()
	state.day = 3
	state.transaction_for_store(&"toy").shelf_slots[0].clear()
	state.expedition.begin_night(state.day, 22)
	state.expedition.rooms_completed = 2
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


func test_rest_room_type_filters_and_rainforest_persona_growth() -> void:
	var state := QuestGameState.new()
	var frog := state.inventory[0]
	var food := state.grant_item(&"mung_bean_cake", &"test")
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", frog))
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", food))
	var persona_before := int(state.protagonist_persona_counts[&"nightwalker"])
	state.expedition.begin_night(1, 3)
	state.expedition.current_door_ids = [&"rainforest"]
	var result := state.complete_expedition_room(&"rainforest", [], [&"nightwalker"])
	assert_true(result.ok)
	assert_eq(state.protagonist_persona_counts[&"nightwalker"], persona_before + 1)
	assert_true(state.inventory.has(frog))
	assert_true(state.inventory.has(food))


func test_each_rest_room_enforces_its_confirmed_card_categories() -> void:
	var state := QuestGameState.new()
	var toy := state.inventory[0]
	var food := state.grant_item(&"fries", &"test")
	var drink := state.grant_item(&"milkshake", &"test")
	var book := state.grant_item(&"conservatory_story", &"test")
	var cassette := state.grant_item(&"goldberg_variations", &"test")
	var flower := state.grant_item(&"jasmine", &"test")
	var wound := state.grant_item(&"expedition_wound", &"test")
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", food))
	assert_true(state.expedition_room_accepts_card(&"retro_restaurant", drink))
	assert_false(state.expedition_room_accepts_card(&"retro_restaurant", toy))
	assert_true(state.expedition_room_accepts_card(&"screening_room", book))
	assert_true(state.expedition_room_accepts_card(&"screening_room", cassette))
	assert_false(state.expedition_room_accepts_card(&"screening_room", food))
	assert_true(state.expedition_room_accepts_card(&"children_playground", toy))
	assert_true(state.expedition_room_accepts_card(&"children_playground", flower))
	assert_false(state.expedition_room_accepts_card(&"children_playground", book))
	assert_true(state.expedition_room_accepts_card(&"home", toy))
	assert_false(state.expedition_room_accepts_card(&"home", wound))
	assert_true(
		state.expedition_room_accepts_card(&"rainforest", null, &"nightwalker")
	)
	assert_false(state.expedition_room_accepts_card(&"rainforest", toy))


func test_optional_rest_can_be_left_empty_but_rainforest_cannot() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 35)
	state.expedition.current_door_ids = [&"home"]
	var home_result := state.complete_expedition_room(&"home")
	assert_true(home_result.ok)
	assert_eq(state.expedition.rooms_completed, 1)
	state.expedition.current_door_ids = [&"rainforest"]
	var rainforest_result := state.complete_expedition_room(&"rainforest")
	assert_false(rainforest_result.ok)
	assert_eq(state.expedition.rooms_completed, 1)


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


func test_rest_growth_from_zero_queues_first_persona_reveal() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"nightwalker"] = 0
	var item := state.grant_item(&"cactus", &"test")
	state.expedition.begin_night(1, 6)
	state.expedition.current_door_ids = [&"home"]
	var result := state.complete_expedition_room(&"home", [item.instance_id])
	assert_true(result.ok)
	assert_eq(result.new_persona_ids, [&"nightwalker"])
	assert_true(state.pending_persona_reveal_ids.has(&"nightwalker"))


func test_boss_requires_three_successful_rounds_and_then_completes_demo() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"nightwalker"] = 5
	state.expedition.begin_night(1, 12)
	state.expedition.current_door_ids = [&"scanner"]
	var rounds: Array[Dictionary] = []
	for index in 3:
		rounds.append({
			"approach_index": index % 2,
			"card_instance_ids": [],
			"persona_ids": [&"nightwalker"],
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
		[{"approach_index": 0, "card_instance_ids": [], "persona_ids": []}],
	)
	assert_true(result.ok)
	assert_true(result.boss_failed)
	assert_true(result.night_finished)
	assert_eq(state.day, 2)
	assert_eq(state.inventory[-1].definition_id, &"expedition_wound")
	assert_true(state.expedition.is_discovered(&"scanner"))


func _challenge_room(
	personas: Array[StringName],
	threshold: int,
) -> MallRoomDefinition:
	var room := MallRoomDefinition.new()
	room.id = &"test_room"
	room.display_name_key = &"test.room"
	room.category = MallRoomDefinition.Category.CHALLENGE
	room.required_persona_ids = personas
	room.persona_total_required = threshold
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
