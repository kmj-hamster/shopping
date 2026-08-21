extends GutTest


func test_new_game_has_no_tasks_and_can_enter_expedition_without_a_gate() -> void:
	var state := QuestGameState.new()
	assert_true(state.task_instances.is_empty())
	assert_eq(state.wallet.money, 40)
	assert_eq(state.inventory.size(), 1)
	assert_eq(state.inventory[0].definition_id, &"tin_frog")
	assert_true(state.is_store_visible(&"toy"))
	assert_false(state.is_store_visible(&"fast_food"))
	assert_false(state.is_store_visible(&"flower"))
	assert_false(state.is_store_visible(&"record"))
	assert_false(state.is_store_visible(&"bookstore"))
	var result := state.begin_mall_expedition(771)
	assert_true(result.ok)
	assert_true(state.expedition.active)
	assert_true(state.expedition.current_door_ids.size() in [1, 2])


func test_store_visibility_and_persona_unlocks_follow_the_opening_chain() -> void:
	var state := QuestGameState.new()
	var early_food := state.grant_item(&"mung_bean_cake", &"test")
	assert_false(state.unlock_store(&"fast_food", early_food).ok)
	_unlock_toy_shop(state)
	assert_true(state.is_store_visible(&"fast_food"))
	assert_true(state.is_store_visible(&"flower"))
	assert_false(state.is_store_visible(&"record"))
	assert_false(state.is_store_visible(&"bookstore"))
	var food := state.grant_item(&"mung_bean_cake", &"test")
	assert_true(state.unlock_store(&"fast_food", food).ok)
	state.protagonist_shape_levels[&"light"] = 0
	var light := PersonaCardCatalog.card_for_shape(&"light")
	PersonaCardCatalog.sync_selection(&"")
	assert_false(state.unlock_store(&"flower", light).ok)
	state.protagonist_shape_levels[&"light"] = 1
	var flower_unlock := state.unlock_store(&"flower", light)
	assert_true(flower_unlock.ok)
	assert_eq(int(flower_unlock.consumed_instance_id), 0)
	assert_true(state.is_store_visible(&"record"))
	assert_true(state.is_store_visible(&"bookstore"))
	assert_eq(light.location, CardItemState.Location.HAND)


func test_initial_persona_allocation_requires_exactly_five_points_and_commits_zeroes() -> void:
	var state := QuestGameState.new()
	var before := state.protagonist_shape_levels.duplicate(true)
	assert_false(state.apply_initial_persona_allocation({&"light": 3, &"tear": 1}).ok)
	assert_eq(state.protagonist_shape_levels, before)
	assert_false(state.apply_initial_persona_allocation({&"light": 4, &"tear": 1}).ok)
	assert_eq(state.protagonist_shape_levels, before)

	var result := state.apply_initial_persona_allocation({
		&"light": 3,
		&"tear": 2,
		&"dream": 0,
		&"sleep": 0,
	})
	assert_true(result.ok)
	assert_eq(int(state.protagonist_shape_levels[&"light"]), 3)
	assert_eq(int(state.protagonist_shape_levels[&"tear"]), 2)
	assert_eq(int(state.protagonist_shape_levels[&"dream"]), 0)
	assert_eq(int(state.protagonist_shape_levels[&"sleep"]), 0)
	assert_eq(state.story_flags[&"initial_persona_allocation_complete"], &"true")


func test_bookstore_consumes_any_dream_item_but_rejects_a_persona_card() -> void:
	var state := QuestGameState.new()
	state.unlocked_store_ids = {&"fast_food": true, &"flower": true}
	var dream_persona := PersonaCardCatalog.card_for_shape(&"dream")
	PersonaCardCatalog.sync_selection(&"")
	assert_false(state.unlock_store(&"bookstore", dream_persona).ok)
	assert_eq(dream_persona.location, CardItemState.Location.HAND)
	var kaleidoscope := state.grant_item(&"kaleidoscope", &"test")
	assert_true(state.unlock_store(&"bookstore", kaleidoscope).ok)
	assert_null(state.card_by_instance_id(kaleidoscope.instance_id))


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
