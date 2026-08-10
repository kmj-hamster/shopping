extends GutTest

const TEST_PATH := "user://shopping0807_save_repository_test.json"

var repository: QuestSaveRepository


func before_each() -> void:
	repository = QuestSaveRepository.new(TEST_PATH)
	repository.erase()


func after_each() -> void:
	repository.erase()


func test_round_trip_preserves_ppt_cards_tasks_and_map_state() -> void:
	var source := QuestGameState.new()
	var girl := source.task_instance_for_definition(&"girl_order")
	var fries := source.inventory[0]
	assert_true(source.assign_card(girl.instance_id, &"food", fries).ok)
	assert_true(source.confirm_task(girl.instance_id).ok)
	var sunflower := source.grant_item(&"sunflower", &"test", 10)
	assert_true(source.unlock_store(&"record", sunflower).ok)
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	var result := repository.load_into(restored)
	assert_true(result.ok)
	assert_eq(restored.wallet.money, 30)
	assert_true(restored.task_instance_for_definition(&"girl_order").confirmed)
	assert_true(restored.is_store_unlocked(&"record"))
	assert_eq(restored.inventory.size(), 6)
	assert_eq(restored.inventory[0].definition_id, &"fries")


func test_round_trip_preserves_owner_page_two_cola_stock() -> void:
	var source := QuestGameState.new()
	assert_true(source.interact_with_store_owner(&"flower").activated)
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	var flower := restored.transaction_for_store(&"flower")
	assert_eq(flower.unlocked_page_count, 2)
	assert_eq(flower.shelf_slots_for_page(2).size(), 1)
	assert_eq(flower.shelf_slots_for_page(2)[0].item_id, &"cola")
	assert_not_null(restored.task_instance_for_definition(&"flower_owner_request"))


func test_pending_arc_resumes_without_duplicate_reward() -> void:
	var source := _state_with_confirmed_girl_order()
	assert_true(source.begin_next_day().ok)
	assert_true(repository.save(source))
	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_not_null(restored.pending_arc)
	assert_eq(restored.pending_arc.entries[0].item_definition_ids, [&"fries"])
	assert_eq(restored.pending_arc.entries[0].reward_money, 12)
	assert_eq(restored.apply_arc_effects().money_gained, 12)
	assert_eq(restored.wallet.money, 42)
	assert_true(restored.apply_arc_effects().already_applied)
	assert_eq(restored.wallet.money, 42)


func test_synthesis_placement_is_not_persisted() -> void:
	var source := QuestGameState.new()
	var cola := source.grant_item(&"cola", &"test")
	var sunflower := source.grant_item(&"sunflower", &"test")
	assert_true(source.assign_synthesis_base(cola).ok)
	assert_true(source.assign_synthesis_fuel(sunflower).ok)
	assert_true(source.select_synthesis_persona(&"clarity"))
	assert_true(repository.save(source))

	var restored := QuestGameState.new()
	assert_true(repository.load_into(restored).ok)
	assert_eq(restored.synthesis_base_instance_id, 0)
	assert_eq(restored.synthesis_fuel_instance_id, 0)
	assert_true(restored.synthesis_persona_id.is_empty())
	assert_eq(_card_by_definition(restored, &"cola").location, CardItemState.Location.HAND)
	assert_eq(_card_by_definition(restored, &"sunflower").location, CardItemState.Location.HAND)


func test_pre_ppt_save_is_rejected_instead_of_migrated() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 3, "content_version": "quest-arc-1"}))
	file.close()
	var result := repository.load_into(QuestGameState.new())
	assert_false(result.ok)
	assert_eq(result.reason, &"unsupported_version")


func _state_with_confirmed_girl_order() -> QuestGameState:
	var state := QuestGameState.new()
	var task := state.task_instance_for_definition(&"girl_order")
	assert_true(state.assign_card(task.instance_id, &"food", state.inventory[0]).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	return state


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null
