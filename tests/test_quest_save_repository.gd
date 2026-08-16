extends GutTest

const TEST_PATH := "user://opening_save_repository_test.json"

var repository: QuestSaveRepository


func before_each() -> void:
	repository = QuestSaveRepository.new(TEST_PATH)
	repository.erase()


func after_each() -> void:
	repository.erase()


func test_round_trip_preserves_opening_tasks_cards_and_map_state() -> void:
	var source := QuestGameState.new()
	_unlock_toy_shop(source)
	var self_care := source.task_instance_for_definition(&"self_care")
	var car := source.grant_item(&"plastic_car", &"test", 8)
	assert_true(source.assign_card(self_care.instance_id, &"self_care_item", car).ok)
	assert_true(source.confirm_task(self_care.instance_id).ok)
	source.mark_store_visited(&"toy")
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_eq(restored.wallet.money, 0)
	assert_true(restored.task_instance_for_definition(&"self_care").confirmed)
	assert_true(restored.is_store_unlocked(&"toy"))
	assert_true(restored.has_visited_store(&"toy"))
	assert_eq(
		restored.card_by_instance_id(car.instance_id).location,
		CardItemState.Location.ACTIVITY_SLOT,
	)


func test_round_trip_preserves_each_bgm_playback_position() -> void:
	var source := QuestGameState.new()
	source.remember_bgm_playback_position(QuestBgmDirector.TRACK_EMPTY, 12.5)
	source.remember_bgm_playback_position(QuestBgmDirector.TRACK_DEBUSSY, 37.25)
	source.remember_bgm_playback_position(QuestBgmDirector.TRACK_DREAM, 4.75)
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_almost_eq(
		restored.bgm_playback_position(QuestBgmDirector.TRACK_EMPTY),
		12.5,
		0.001,
	)
	assert_almost_eq(
		restored.bgm_playback_position(QuestBgmDirector.TRACK_DEBUSSY),
		37.25,
		0.001,
	)
	assert_almost_eq(
		restored.bgm_playback_position(QuestBgmDirector.TRACK_DREAM),
		4.75,
		0.001,
	)


func test_round_trip_preserves_fixed_shelf_stock() -> void:
	var source := QuestGameState.new()
	var toy := source.transaction_for_store(&"toy")
	toy.shelf_slots[0].clear()
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	var restored_toy := restored.transaction_for_store(&"toy")
	assert_true(restored_toy.shelf_slots[0].is_empty())
	assert_eq(restored_toy.shelf_slots[1].item_id, &"kaleidoscope")
	assert_true(restored.transaction_for_store(&"record").shelf_slots.is_empty())


func test_pending_arc_preserves_dynamic_persona_growth_without_duplicate_reward() -> void:
	var source := _state_with_confirmed_self_care(&"kaleidoscope")
	assert_true(source.begin_next_day().ok)
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_not_null(restored.pending_arc)
	assert_eq(restored.pending_arc.entries[0].item_definition_ids, [&"kaleidoscope"])
	assert_eq(restored.pending_arc.entries[0].persona_growth, {
		&"dreamwalker": 1,
		&"mourner": 1,
	})
	assert_true(restored.apply_arc_effects().ok)
	assert_eq(int(restored.protagonist_persona_counts[&"dreamwalker"]), 1)
	assert_eq(int(restored.protagonist_persona_counts[&"mourner"]), 1)
	assert_true(restored.apply_arc_effects().already_applied)
	assert_eq(int(restored.protagonist_persona_counts[&"dreamwalker"]), 1)


func test_synthesis_placement_is_not_persisted() -> void:
	var source := QuestGameState.new()
	var jasmine := source.grant_item(&"jasmine", &"test")
	var gardenia := source.grant_item(&"gardenia", &"test")
	source.protagonist_persona_counts[&"nightwalker"] = 1
	assert_true(source.assign_synthesis_base(jasmine).ok)
	assert_true(source.assign_synthesis_helper(gardenia).ok)
	assert_true(source.select_synthesis_persona(&"nightwalker"))
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_eq(restored.synthesis_base_instance_id, 0)
	assert_eq(restored.synthesis_helper_instance_id, 0)
	assert_true(restored.synthesis_persona_id.is_empty())
	assert_eq(_card_by_definition(restored, &"jasmine").location, CardItemState.Location.HAND)
	assert_eq(_card_by_definition(restored, &"gardenia").location, CardItemState.Location.HAND)


func test_discovered_recipe_is_persisted_without_draft_inputs() -> void:
	var source := QuestGameState.new()
	source.discovered_recipe_ids[&"recipe_midnight_rose"] = true
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_true(restored.discovered_recipe_ids.has(&"recipe_midnight_rose"))
	assert_eq(restored.synthesis_base_instance_id, 0)
	assert_eq(restored.synthesis_helper_instance_id, 0)


func test_item_and_money_gift_states_survive_round_trip() -> void:
	var source := QuestGameState.new()
	var money_gift := source.task_instance_for_definition(&"remittance")
	assert_true(source.reveal_task_gift(money_gift.instance_id).ok)
	var item_gift := source.task_instance_for_definition(&"tin_boy_gift")
	assert_true(source.reveal_task_gift(item_gift.instance_id).ok)
	assert_true(repository.save(source))

	var revealed := QuestGameState.new()
	assert_true(repository.load_into(revealed).ok)
	assert_eq(revealed.wallet.money, 100)
	assert_true(revealed.task_instance_for_definition(&"remittance").gift_claimed)
	var revealed_item_gift := revealed.task_instance_for_definition(&"tin_boy_gift")
	assert_true(revealed_item_gift.gift_revealed)
	assert_false(revealed_item_gift.gift_claimed)
	assert_true(revealed.claim_task_gift(revealed_item_gift.instance_id).ok)
	assert_true(repository.save(revealed))
	var claimed := QuestGameState.new()
	assert_true(repository.load_into(claimed).ok)
	assert_true(claimed.task_instance_for_definition(&"tin_boy_gift").gift_claimed)
	assert_not_null(_card_by_definition(claimed, &"tin_frog"))


func test_task_pool_cooldowns_offers_and_persona_reveals_survive_round_trip() -> void:
	var source := _state_with_confirmed_self_care(&"plastic_orchid")
	assert_true(source.begin_next_day().ok)
	assert_true(source.apply_arc_effects().ok)
	source.task_pool_available_days[&"daily_midnight_radio"] = 9
	source.self_care_type_available_days[&"toy"] = 5
	source.pending_task_offer_rounds = [{
		"kind": QuestGameState.OFFER_KIND_DAILY,
		"candidate_ids": [
			&"daily_midnight_radio",
			QuestGameState.DEEP_NIGHT_JOB_ID,
		],
	}]
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_eq(int(restored.task_pool_available_days[&"daily_midnight_radio"]), 9)
	assert_eq(int(restored.self_care_type_available_days[&"toy"]), 5)
	assert_eq(restored.pending_task_offer_rounds.size(), 1)
	assert_eq(
		restored.pending_task_offer_rounds[0].candidate_ids,
		[&"daily_midnight_radio", QuestGameState.DEEP_NIGHT_JOB_ID],
	)
	assert_true(&"dreamwalker" in restored.pending_persona_reveal_ids)
	assert_true(&"mourner" in restored.pending_persona_reveal_ids)


func _state_with_confirmed_self_care(item_id: StringName) -> QuestGameState:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"dreamwalker"] = 0
	state.protagonist_persona_counts[&"mourner"] = 0
	_unlock_toy_shop(state)
	var task := state.task_instance_for_definition(&"self_care")
	var item := state.grant_item(item_id, &"test")
	assert_true(state.assign_card(task.instance_id, &"self_care_item", item).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	return state


func _unlock_toy_shop(state: QuestGameState) -> void:
	var frog := state.grant_item(&"tin_frog", &"test")
	assert_true(state.unlock_store(&"toy", frog).ok)


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null
