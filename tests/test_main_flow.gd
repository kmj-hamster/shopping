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
	assert_eq(GameState.quest_state.inventory.size(), 2)
	assert_not_null(_card_by_definition(GameState.quest_state, &"sunflower"))
	assert_eq(main.hand_bar.card_views.size(), 2)


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


func test_only_ppt_recipe_turns_cola_and_sunflower_into_scissors() -> void:
	var state := GameState.quest_state
	var cola := state.grant_item(&"cola", &"test")
	var sunflower := state.grant_item(&"sunflower", &"test")
	assert_true(state.assign_synthesis_card(&"metal", cola).ok)
	assert_true(state.assign_synthesis_card(&"lamp", sunflower).ok)
	assert_true(state.synthesis_evaluation().is_complete)
	assert_true(state.begin_synthesis().ok)
	var result := state.advance_synthesis(1.0)
	assert_true(result.completed)
	assert_null(state.card_by_instance_id(cola.instance_id))
	assert_null(state.card_by_instance_id(sunflower.instance_id))
	assert_not_null(_card_by_definition(state, &"scissors"))


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
