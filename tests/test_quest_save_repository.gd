extends GutTest

const TEST_PATH := "user://opening_save_repository_test.json"

var repository: QuestSaveRepository


func before_each() -> void:
	repository = QuestSaveRepository.new(TEST_PATH)
	repository.erase()


func after_each() -> void:
	repository.erase()


func test_round_trip_preserves_each_bgm_playback_position() -> void:
	var source := QuestGameState.new()
	source.remember_bgm_playback_position(QuestBgmDirector.TRACK_EMPTY, 12.5)
	source.remember_bgm_playback_position(QuestBgmDirector.TRACK_DEBUSSY, 37.25)
	source.remember_bgm_playback_position(QuestBgmDirector.TRACK_DREAM, 4.75)
	var restored := _round_trip(source)
	assert_almost_eq(restored.bgm_playback_position(QuestBgmDirector.TRACK_EMPTY), 12.5, 0.001)
	assert_almost_eq(restored.bgm_playback_position(QuestBgmDirector.TRACK_DEBUSSY), 37.25, 0.001)
	assert_almost_eq(restored.bgm_playback_position(QuestBgmDirector.TRACK_DREAM), 4.75, 0.001)


func test_round_trip_preserves_fixed_shelf_stock() -> void:
	var source := QuestGameState.new()
	source.transaction_for_store(&"toy").shelf_slots[0].clear()
	var restored := _round_trip(source)
	assert_true(restored.transaction_for_store(&"toy").shelf_slots[0].is_empty())
	assert_eq(restored.transaction_for_store(&"toy").shelf_slots[1].item_id, &"lotus_candle")
	assert_eq(
		restored.transaction_for_store(&"record").shelf_slots[0].item_id,
		&"goldberg_variations",
	)


func test_synthesis_placement_is_not_persisted() -> void:
	var source := QuestGameState.new()
	var jasmine := source.grant_item(&"jasmine", &"test")
	var gardenia := source.grant_item(&"gardenia", &"test")
	assert_true(source.assign_synthesis_base(jasmine).ok)
	assert_true(source.assign_synthesis_helper(gardenia).ok)
	assert_true(source.select_synthesis_persona(&"nightwalker"))
	var restored := _round_trip(source)
	assert_eq(restored.synthesis_base_instance_id, 0)
	assert_eq(restored.synthesis_helper_instance_id, 0)
	assert_true(restored.synthesis_persona_id.is_empty())
	assert_eq(_card_by_definition(restored, &"jasmine").location, CardItemState.Location.HAND)
	assert_eq(_card_by_definition(restored, &"gardenia").location, CardItemState.Location.HAND)


func test_discovered_recipe_is_persisted_without_draft_inputs() -> void:
	var source := QuestGameState.new()
	source.discovered_recipe_ids[&"recipe_rose"] = true
	var restored := _round_trip(source)
	assert_true(restored.discovered_recipe_ids.has(&"recipe_rose"))
	assert_eq(restored.synthesis_base_instance_id, 0)


func test_expedition_checkpoint_preserves_candidates_progress_and_permanent_discovery() -> void:
	var source := QuestGameState.new()
	source.expedition.discovered_room_ids[&"gray_hall"] = true
	source.expedition.first_cleared_challenge_ids[&"gray_hall"] = true
	assert_true(source.begin_mall_expedition(91234).ok)
	source.expedition.rooms_completed = 1
	source.expedition.entered_room_ids[&"home"] = true
	var candidates := source.expedition.current_door_ids.duplicate()
	var rng_state := source.expedition.rng_state
	var restored := _round_trip(source)
	assert_true(restored.expedition.active)
	assert_eq(restored.expedition.rooms_completed, 1)
	assert_true(restored.expedition.has_entered(&"home"))
	assert_true(restored.expedition.is_discovered(&"gray_hall"))
	assert_true(restored.expedition.is_first_cleared(&"gray_hall"))
	assert_eq(restored.expedition.current_door_ids, candidates)
	assert_eq(restored.expedition.rng_state, rng_state)


func test_expedition_challenge_roll_is_identical_after_checkpoint_reload() -> void:
	var source := QuestGameState.new()
	assert_true(source.begin_mall_expedition(441122).ok)
	source.expedition.current_door_ids = [&"gray_hall"]
	source.protagonist_persona_counts[&"nightwalker"] = 4
	var before := source.evaluate_expedition_challenge_round(
		&"gray_hall", [], [&"nightwalker"], 0
	)
	var restored := _round_trip(source)
	var after := restored.evaluate_expedition_challenge_round(
		&"gray_hall", [], [&"nightwalker"], 0
	)
	assert_eq(after.roll_percent, before.roll_percent)
	assert_eq(after.success_probability, before.success_probability)
	assert_eq(after.success, before.success)


func _round_trip(source: QuestGameState) -> QuestGameState:
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	return restored


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null
