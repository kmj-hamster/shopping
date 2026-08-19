extends GutTest


func test_new_game_has_no_tasks_and_can_enter_expedition_without_a_gate() -> void:
	var state := QuestGameState.new()
	assert_true(state.task_instances.is_empty())
	assert_eq(state.inventory.size(), 1)
	assert_eq(state.inventory[0].definition_id, &"tin_frog")
	var result := state.begin_mall_expedition(771)
	assert_true(result.ok)
	assert_true(state.expedition.active)
	assert_true(state.expedition.current_door_ids.size() in [1, 2])


func test_store_visibility_and_persona_unlocks_follow_the_opening_chain() -> void:
	var state := QuestGameState.new()
	_unlock_toy_shop(state)
	assert_false(state.is_store_visible(&"record"))
	assert_false(state.is_store_visible(&"bookstore"))
	var food := state.grant_item(&"mung_bean_cake", &"test")
	assert_true(state.unlock_store(&"fast_food", food).ok)
	state.protagonist_persona_counts[&"nightwalker"] = 1
	var nightwalker := PersonaMaskCatalog.card_for_persona(&"nightwalker")
	PersonaMaskCatalog.sync_selection(&"")
	var flower_unlock := state.unlock_store(&"flower", nightwalker)
	assert_true(flower_unlock.ok)
	assert_eq(int(flower_unlock.consumed_instance_id), 0)
	assert_true(state.is_store_visible(&"record"))
	assert_true(state.is_store_visible(&"bookstore"))
	assert_eq(nightwalker.location, CardItemState.Location.HAND)


func test_bookstore_needs_level_three_nightwalker_or_dreamwalker() -> void:
	var state := QuestGameState.new()
	state.unlocked_store_ids = {&"toy": true, &"fast_food": true, &"flower": true}
	var nightwalker := PersonaMaskCatalog.card_for_persona(&"nightwalker")
	PersonaMaskCatalog.sync_selection(&"")
	state.protagonist_persona_counts[&"nightwalker"] = 2
	assert_false(state.unlock_store(&"bookstore", nightwalker).ok)
	state.protagonist_persona_counts[&"nightwalker"] = 3
	assert_true(state.unlock_store(&"bookstore", nightwalker).ok)
	assert_eq(nightwalker.location, CardItemState.Location.HAND)


func test_shelves_refill_only_on_the_store_fixed_phase() -> void:
	var state := QuestGameState.new()
	_unlock_toy_shop(state)
	var transaction := state.transaction_for_store(&"toy")
	var slot := transaction.shelf_slots[0]
	slot.clear()
	state.refill_scheduled_shelves(2)
	assert_true(slot.is_empty())
	state.refill_scheduled_shelves(4)
	assert_eq(slot.item_id, &"kaleidoscope")


func _unlock_toy_shop(state: QuestGameState) -> void:
	var frog := state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"tin_frog"
	)[0] as CardItemState
	assert_true(state.unlock_store(&"toy", frog).ok)
