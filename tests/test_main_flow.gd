extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_flower_shop_purchase_moves_sunflower_into_center_hand() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := GameState.quest_state.transaction_for_store(&"flower")
	var sunflower_slot := transaction.shelf_slots[0]
	assert_eq(sunflower_slot.item_id, &"sunflower")
	shop._on_shelf_pressed(sunflower_slot.slot_id)
	assert_eq(transaction.cart_count(), 1)
	shop._on_checkout_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameState.quest_state.wallet.money, 20)
	assert_eq(GameState.quest_state.inventory.size(), 7)
	assert_not_null(_card_by_definition(GameState.quest_state, &"sunflower"))
	assert_eq(main.hand_bar.card_views.size(), 7)


func test_shop_keeps_only_one_item_selected_for_checkout() -> void:
	var state := GameState.quest_state
	var transaction := state.transaction_for_store(&"flower")
	var available_slots := transaction.shelf_slots.filter(
		func(slot: ShelfSlotState) -> bool: return not slot.is_empty()
	)
	assert_true(available_slots.size() >= 2)
	var first := available_slots[0] as ShelfSlotState
	var second := available_slots[1] as ShelfSlotState
	assert_true(transaction.toggle_shelf_slot(first.slot_id).ok)
	assert_true(transaction.toggle_shelf_slot(second.slot_id).ok)
	assert_eq(transaction.cart_count(), 1)
	assert_false(transaction.is_selected(first.slot_id))
	assert_true(transaction.is_selected(second.slot_id))


func test_shop_selection_is_local_but_checkout_changes_global_state() -> void:
	var state := GameState.quest_state
	var transaction := state.transaction_for_store(&"flower")
	var slot := transaction.shelf_slots.filter(
		func(candidate: ShelfSlotState) -> bool: return not candidate.is_empty()
	)[0] as ShelfSlotState
	var global_change_count := [0]
	var selection_events: Array[Array] = []
	state.state_changed.connect(func() -> void: global_change_count[0] += 1)
	transaction.selection_changed.connect(
		func(previous_id: StringName, selected_id: StringName) -> void:
			selection_events.append([previous_id, selected_id])
	)
	assert_true(transaction.toggle_shelf_slot(slot.slot_id).ok)
	assert_eq(global_change_count[0], 0)
	assert_eq(selection_events, [[&"", slot.slot_id]])
	assert_true(state.checkout_store(&"flower").ok)
	assert_eq(global_change_count[0], 1)


func test_submitted_arc_task_is_permanently_locked() -> void:
	var state := GameState.quest_state
	var task := state.task_instance_for_definition(&"girl_order")
	var fries := _card_by_definition(state, &"fries")
	assert_true(state.assign_card(task.instance_id, &"food", fries).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	assert_true(task.confirmed)
	assert_false(state.cancel_task_confirmation(task.instance_id))
	assert_false(state.return_card_to_hand(fries))
	assert_eq(fries.location, CardItemState.Location.ACTIVITY_SLOT)


func test_flower_owner_request_requires_submission_inside_flower_shop() -> void:
	var state := GameState.quest_state
	var interaction := state.interact_with_store_owner(&"flower")
	assert_true(interaction.ok)
	var task := state.task_instance_for_definition(&"flower_owner_request")
	assert_not_null(task)
	assert_eq(state.transaction_for_store(&"flower").unlocked_page_count, 2)
	var scissors := state.grant_item(&"scissors", &"test")
	assert_true(state.assign_card(task.instance_id, &"trim", scissors).ok)
	assert_false(state.submit_owner_task(task.instance_id, &"record").ok)
	var result := state.submit_owner_task(task.instance_id, &"flower")
	assert_true(result.ok)
	assert_eq(result.outcome_id, &"trimmed")
	assert_eq(state.owner_states[&"flower_owner"], &"trimmed")


func test_new_synthesis_consumes_base_but_not_persona_and_creates_rose() -> void:
	var state := GameState.quest_state
	var sunflower := _card_by_definition(state, &"sunflower")
	var soft_gauze := _card_by_definition(state, &"soft_gauze")
	var reverie_before: int = int(state.protagonist_aspect_counts[&"reverie"])
	assert_true(state.assign_synthesis_base(sunflower).ok)
	assert_true(state.assign_synthesis_fuel(soft_gauze).ok)
	assert_true(state.select_synthesis_persona(&"reverie"))
	assert_true(state.select_synthesis_candidate(&"recipe_midnight_rose"))
	var result := state.begin_synthesis()
	assert_true(result.ok)
	assert_null(state.card_by_instance_id(sunflower.instance_id))
	assert_null(state.card_by_instance_id(soft_gauze.instance_id))
	assert_eq(state.protagonist_aspect_counts[&"reverie"], reverie_before)
	assert_not_null(_card_by_definition(state, &"midnight_rose"))


func test_worn_teddy_can_be_used_for_both_second_step_recipes() -> void:
	var state := GameState.quest_state
	var toy := _card_by_definition(state, &"toy_block")
	var soft_gauze_cards := state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"soft_gauze"
	)
	assert_eq(soft_gauze_cards.size(), 2)
	assert_true(state.assign_synthesis_base(toy).ok)
	assert_true(state.assign_synthesis_fuel(soft_gauze_cards[0]).ok)
	assert_true(state.select_synthesis_persona(&"ease"))
	assert_true(state.select_synthesis_candidate(&"recipe_worn_teddy"))
	var first_step := state.begin_synthesis()
	assert_true(first_step.ok)
	assert_true(state.synthesis_persona_id.is_empty())
	var worn := first_step.output as CardItemState
	assert_not_null(worn)
	assert_true(state.assign_synthesis_base(worn).ok)
	assert_true(state.assign_synthesis_fuel(soft_gauze_cards[1]).ok)
	assert_true(state.select_synthesis_persona(&"ease"))
	assert_true(state.select_synthesis_candidate(&"recipe_baby_teddy"))
	assert_true(state.begin_synthesis().ok)
	assert_not_null(_card_by_definition(state, &"baby_teddy"))

	worn = state.grant_item(&"worn_teddy", &"test")
	var mirror_shard := _card_by_definition(state, &"mirror_shard")
	assert_true(state.assign_synthesis_base(worn).ok)
	assert_true(state.assign_synthesis_fuel(mirror_shard).ok)
	assert_true(state.select_synthesis_persona(&"reminiscence"))
	assert_true(state.select_synthesis_candidate(&"recipe_pale_teddy"))
	assert_true(state.begin_synthesis().ok)
	assert_not_null(_card_by_definition(state, &"pale_teddy"))


func test_sunflower_unlocks_record_shop_and_is_consumed() -> void:
	var state := GameState.quest_state
	var sunflower := state.grant_item(&"sunflower", &"test")
	var result := state.unlock_store(&"record", sunflower)
	assert_true(result.ok)
	assert_true(state.is_store_unlocked(&"record"))
	assert_null(state.card_by_instance_id(sunflower.instance_id))


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null
