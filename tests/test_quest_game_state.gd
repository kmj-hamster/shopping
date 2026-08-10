extends GutTest


func test_arc_applies_ppt_girl_reward_and_advances_the_night() -> void:
	var state := QuestGameState.new()
	var task := state.task_instance_for_definition(&"girl_order")
	var fries := state.inventory[0]
	assert_true(state.assign_card(task.instance_id, &"food", fries).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	var applied := state.apply_arc_effects()
	assert_true(applied.ok)
	assert_eq(applied.money_gained, 12)
	assert_eq(state.wallet.money, 42)
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.finish_arc().ok)
	assert_eq(state.day, 2)
	assert_eq(state.task_history[&"girl_order"], &"salty")


func test_self_care_updates_reverie_persona() -> void:
	var state := QuestGameState.new()
	var task := state.task_instance_for_definition(&"self_care")
	var cola := state.grant_item(&"cola", &"test")
	assert_true(state.assign_card(task.instance_id, &"drink", cola).ok)
	assert_true(state.confirm_task(task.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_eq(state.protagonist_aspect_counts[&"reverie"], 4)
	assert_eq(state.protagonist_aspect_counts[&"reminiscence"], 3)


func test_owner_or_task_is_ready_with_exactly_one_branch() -> void:
	var state := QuestGameState.new()
	state.interact_with_store_owner(&"flower")
	var task := state.task_instance_for_definition(&"flower_owner_request")
	var agave := state.grant_item(&"agave", &"test")
	assert_true(state.assign_card(task.instance_id, &"nourish", agave).ok)
	var evaluation := state.task_evaluation(task.instance_id)
	assert_true(evaluation.is_ready)
	assert_eq((evaluation.outcome as TaskOutcomeDefinition).id, &"blooming")


func test_checkout_rejects_cart_above_balance_without_mutating_stock() -> void:
	var state := QuestGameState.new()
	state.wallet.money = 5
	var transaction := state.transaction_for_store(&"flower")
	var agave_slot := transaction.shelf_slots[1]
	assert_eq(agave_slot.item_id, &"agave")
	transaction.toggle_shelf_slot(agave_slot.slot_id)
	var result := state.checkout_store(&"flower")
	assert_false(result.ok)
	assert_eq(result.reason, CardShopTransaction.RESULT_INSUFFICIENT_FUNDS)
	assert_eq(agave_slot.item_id, &"agave")
	assert_eq(state.wallet.money, 5)


func test_synthesis_completion_emits_one_merged_hand_delta() -> void:
	var state := QuestGameState.new()
	var sunflower := _card_by_definition(state, &"sunflower")
	var soft_gauze := _card_by_definition(state, &"soft_gauze")
	assert_true(state.assign_synthesis_base(sunflower).ok)
	assert_true(state.assign_synthesis_fuel(soft_gauze).ok)
	assert_true(state.select_synthesis_persona(&"reverie"))
	var evaluated_snapshot := state.synthesis_evaluation_snapshot()
	assert_true(state.select_synthesis_candidate(&"recipe_midnight_rose"))
	assert_same(state.synthesis_evaluation_snapshot(), evaluated_snapshot)
	var deltas: Array[QuestStateDelta] = []
	state.state_delta.connect(func(delta: QuestStateDelta) -> void: deltas.append(delta))

	var result := state.begin_synthesis()
	assert_true(result.ok)
	assert_eq(deltas.size(), 1)
	var delta := deltas[0]
	assert_true(delta.hand_removed_instance_ids.has(sunflower.instance_id))
	assert_true(delta.hand_removed_instance_ids.has(soft_gauze.instance_id))
	assert_true(delta.hand_added_instance_ids.has(result.output.instance_id))


func test_synthesis_draft_changes_do_not_emit_persistent_state_changed() -> void:
	var state := QuestGameState.new()
	var counts := {"persistent": 0, "synthesis_delta": 0}
	state.state_changed.connect(func() -> void: counts.persistent += 1)
	state.state_delta.connect(func(delta: QuestStateDelta) -> void:
		if delta.affects_synthesis():
			counts.synthesis_delta += 1
	)
	var sunflower := _card_by_definition(state, &"sunflower")
	var soft_gauze := _card_by_definition(state, &"soft_gauze")

	assert_true(state.assign_synthesis_base(sunflower).ok)
	assert_true(state.assign_synthesis_fuel(soft_gauze).ok)
	assert_true(state.select_synthesis_persona(&"reverie"))
	assert_true(state.select_synthesis_candidate(&"recipe_midnight_rose"))
	assert_eq(counts.persistent, 0)
	assert_eq(counts.synthesis_delta, 4)

	assert_true(state.begin_synthesis().ok)
	assert_eq(counts.persistent, 1)


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null
