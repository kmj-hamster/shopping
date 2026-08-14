extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.LEGACY_MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_flower_shop_purchase_moves_jasmine_into_center_hand() -> void:
	GameState.quest_state.wallet.money = 30
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := GameState.quest_state.transaction_for_store(&"flower")
	var jasmine_slot := transaction.shelf_slots[0]
	assert_eq(jasmine_slot.item_id, &"jasmine")
	shop._on_shelf_pressed(jasmine_slot.slot_id)
	assert_true(transaction.has_selection())
	shop._on_checkout_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameState.quest_state.wallet.money, 20)
	assert_eq(GameState.quest_state.inventory.size(), 7)
	var jasmine := _card_by_definition(GameState.quest_state, &"jasmine")
	assert_not_null(jasmine)
	assert_true(main.hand_bar.card_views.has(jasmine.instance_id))
	assert_eq(
		main.hand_bar.card_views.size(),
		GameState.quest_state.inventory.size() + PersonaMaskCatalog.MASK_PERSONAS.size(),
	)


func test_shop_replaces_the_single_checkout_selection() -> void:
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
	assert_true(transaction.has_selection())
	assert_eq(transaction.selected_shelf_slot_id, second.slot_id)
	assert_false(transaction.is_selected(first.slot_id))
	assert_true(transaction.is_selected(second.slot_id))


func test_shop_selection_is_local_but_checkout_changes_global_state() -> void:
	var state := GameState.quest_state
	state.wallet.money = 30
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


func test_flower_owner_request_confirms_anywhere_and_settles_in_the_arc() -> void:
	var state := GameState.quest_state
	var interaction := state.interact_with_store_owner(&"flower")
	assert_true(interaction.ok)
	var task := state.task_instance_for_definition(&"flower_owner_request")
	assert_not_null(task)
	assert_eq(state.transaction_for_store(&"flower").unlocked_page_count, 2)
	var scissors := state.grant_item(&"scissors", &"test")
	assert_true(state.assign_card(task.instance_id, &"trim", scissors).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	assert_true(task.confirmed)
	assert_eq(task.resolved_outcome_id, &"trimmed")
	assert_false(state.owner_states.has(&"flower_owner"))
	assert_true(scissors in state.inventory)
	assert_true(state.begin_next_day().ok)
	assert_eq(state.pending_arc.entries.size(), 1)
	assert_eq(state.pending_arc.entries[0].task_definition_id, &"flower_owner_request")
	assert_eq(state.pending_arc.entries[0].outcome_id, &"trimmed")
	assert_eq(
		state.pending_arc.entries[0].result_text_key,
		&"demo.task.flower_owner.result.trimmed",
	)
	assert_true(state.apply_arc_effects().ok)
	assert_eq(state.owner_states[&"flower_owner"], &"trimmed")
	assert_true(task.settled)
	assert_false(scissors in state.inventory)


func test_new_synthesis_consumes_base_but_not_persona_and_creates_rose() -> void:
	var state := GameState.quest_state
	var jasmine := _card_by_definition(state, &"jasmine")
	var soft_gauze := _card_by_definition(state, &"soft_gauze")
	var reverie_before: int = int(state.protagonist_persona_counts[&"dreamwalker"])
	assert_true(state.assign_synthesis_base(jasmine).ok)
	assert_true(state.assign_synthesis_helper(soft_gauze).ok)
	assert_true(state.select_synthesis_persona(&"dreamwalker"))
	assert_true(state.select_synthesis_candidate(&"recipe_midnight_rose"))
	var result := state.begin_synthesis()
	assert_true(result.ok)
	assert_null(state.card_by_instance_id(jasmine.instance_id))
	assert_null(state.card_by_instance_id(soft_gauze.instance_id))
	assert_eq(state.protagonist_persona_counts[&"dreamwalker"], reverie_before)
	assert_not_null(_card_by_definition(state, &"midnight_rose"))


func test_worn_teddy_can_be_used_for_both_second_step_recipes() -> void:
	var state := GameState.quest_state
	var toy := _card_by_definition(state, &"toy_block")
	var soft_gauze_cards := state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"soft_gauze"
	)
	assert_eq(soft_gauze_cards.size(), 2)
	assert_true(state.assign_synthesis_base(toy).ok)
	assert_true(state.assign_synthesis_helper(soft_gauze_cards[0]).ok)
	assert_true(state.select_synthesis_persona(&"homecomer"))
	assert_true(state.select_synthesis_candidate(&"recipe_worn_teddy"))
	var first_step := state.begin_synthesis()
	assert_true(first_step.ok)
	assert_true(state.synthesis_persona_id.is_empty())
	var worn := first_step.output as CardItemState
	assert_not_null(worn)
	assert_true(state.assign_synthesis_base(worn).ok)
	assert_true(state.assign_synthesis_helper(soft_gauze_cards[1]).ok)
	assert_true(state.select_synthesis_persona(&"homecomer"))
	assert_true(state.select_synthesis_candidate(&"recipe_baby_teddy"))
	assert_true(state.begin_synthesis().ok)
	assert_not_null(_card_by_definition(state, &"baby_teddy"))

	worn = state.grant_item(&"worn_teddy", &"test")
	var mirror_shard := _card_by_definition(state, &"mirror_shard")
	assert_true(state.assign_synthesis_base(worn).ok)
	assert_true(state.assign_synthesis_helper(mirror_shard).ok)
	assert_true(state.select_synthesis_persona(&"mourner"))
	assert_true(state.select_synthesis_candidate(&"recipe_pale_teddy"))
	assert_true(state.begin_synthesis().ok)
	assert_not_null(_card_by_definition(state, &"pale_teddy"))


func test_jasmine_unlocks_record_shop_and_is_consumed() -> void:
	var state := GameState.quest_state
	var jasmine := state.grant_item(&"jasmine", &"test")
	var result := state.unlock_store(&"record", jasmine)
	assert_true(result.ok)
	assert_true(state.is_store_unlocked(&"record"))
	assert_null(state.card_by_instance_id(jasmine.instance_id))


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
