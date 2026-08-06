extends GutTest

const TEST_PATH := "user://quest_save_repository_test.json"

var repository: QuestSaveRepository


func before_each() -> void:
	repository = QuestSaveRepository.new(TEST_PATH)
	repository.erase()


func after_each() -> void:
	repository.erase()


func test_round_trip_preserves_cards_tasks_map_and_story_state() -> void:
	var source := QuestGameState.new()
	var care := source.task_instance_for_definition(&"care_hungry")
	var card := source.grant_item(&"fast_hash_brown", &"fast_food", 2)
	assert_true(source.assign_card(care.instance_id, &"food", card).ok)
	assert_true(source.confirm_task(care.instance_id).ok)
	source.story_flags[&"test_flag"] = &"seen"
	source.known_recipe_hint_ids[&"recipe_teddy"] = true
	var moth := source.grant_item(&"toy_windup_moth", &"toy", 6)
	assert_true(source.unlock_store(&"record", moth).ok)
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	var load_result := repository.load_into(restored)
	assert_true(load_result.ok)
	assert_eq(restored.wallet.money, 10)
	assert_eq(restored.inventory.size(), 1)
	assert_eq(restored.inventory[0].purchase_price, 2)
	assert_true(restored.task_instance_for_definition(&"care_hungry").confirmed)
	assert_eq(restored.story_flags[&"test_flag"], &"seen")
	assert_true(restored.known_recipe_hint_ids.has(&"recipe_teddy"))
	assert_true(restored.is_store_unlocked(&"record"))


func test_round_trip_preserves_empty_finite_shelves_and_recycle_staging() -> void:
	var source := QuestGameState.new()
	var toy := source.transaction_for_store(&"toy")
	assert_true(toy.select_shelf_slot(toy.shelf_slots[3].slot_id).ok)
	var moth := source.checkout_store(&"toy").purchased[0] as CardItemState
	assert_true(toy.shelf_slots[3].is_empty())
	var flower := source.transaction_for_store(&"flower")
	assert_true(flower.select_shelf_slot(flower.shelf_slots[0].slot_id).ok)
	var sunflower := source.checkout_store(&"flower").purchased[0] as CardItemState
	assert_true(source.stage_recycle_card(sunflower).ok)
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_true(restored.transaction_for_store(&"toy").shelf_slots[3].is_empty())
	assert_eq(restored.recycle_transaction.staged_instance_ids, [sunflower.instance_id])
	assert_eq(restored.card_by_instance_id(sunflower.instance_id).location, CardItemState.Location.RECYCLE)
	assert_eq(restored.card_by_instance_id(moth.instance_id).purchase_price, 6)


func test_pending_arc_resumes_before_effects_without_duplicate_reward() -> void:
	var source := _state_with_confirmed_awake_order()
	assert_eq(source.begin_next_day().confirmed_task_count, 1)
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_not_null(restored.pending_arc)
	assert_false(restored.pending_arc.effects_applied)
	assert_eq(restored.wallet.money, 10)
	assert_eq(restored.apply_arc_effects().money_gained, 5)
	assert_eq(restored.wallet.money, 15)
	assert_true(restored.apply_arc_effects().already_applied)
	assert_eq(restored.wallet.money, 15)


func test_pending_arc_resumes_after_effects_at_next_unread_entry() -> void:
	var source := _state_with_confirmed_awake_order()
	assert_true(source.begin_next_day().ok)
	assert_true(source.apply_arc_effects().ok)
	assert_true(source.mark_arc_entry_shown())
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_true(restored.pending_arc.effects_applied)
	assert_eq(restored.pending_arc.next_entry_index, 1)
	assert_true(restored.apply_arc_effects().already_applied)
	assert_eq(restored.wallet.money, 15)
	assert_true(restored.finish_arc().ok)
	assert_eq(restored.day, 2)


func test_active_synthesis_round_trip_preserves_inputs_and_remaining_time() -> void:
	var source := QuestGameState.new()
	var filling := source.grant_item(&"toy_cloth_scraps")
	var shape := source.grant_item(&"toy_cloth_scraps")
	var calm := source.grant_item(&"toy_sleeping_rabbit")
	assert_true(source.assign_synthesis_card(&"soft_filling", filling).ok)
	assert_true(source.assign_synthesis_card(&"toy_shape", shape).ok)
	assert_true(source.assign_synthesis_card(&"calm", calm).ok)
	assert_true(source.begin_synthesis().ok)
	assert_false(source.advance_synthesis(1.0).completed)
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_not_null(restored.active_synthesis)
	assert_almost_eq(restored.active_synthesis.remaining_seconds, 1.5, 0.01)
	assert_eq(restored.synthesis_assignments.size(), 3)
	assert_true(restored.advance_synthesis(1.5).completed)
	assert_eq(restored.inventory.size(), 1)
	assert_eq(restored.inventory[0].definition_id, &"craft_comfort_bear")


func test_version_two_save_is_rejected_instead_of_migrated() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 2, "content_version": "slot-demo-0.9"}))
	file.close()
	var result := repository.load_into(QuestGameState.new())
	assert_false(result.ok)
	assert_eq(result.reason, &"unsupported_version")


func _state_with_confirmed_awake_order() -> QuestGameState:
	var state := QuestGameState.new()
	var order := state.task_instance_for_definition(&"order_hamster_midnight_supper")
	var card := state.grant_item(&"fast_hash_brown")
	assert_true(state.assign_card(order.instance_id, &"midnight_food", card).ok)
	assert_true(state.confirm_task(order.instance_id).ok)
	return state
