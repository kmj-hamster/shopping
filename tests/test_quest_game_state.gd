extends GutTest


func test_opening_money_gift_and_tin_frog_unlock_the_toy_shop() -> void:
	var state := QuestGameState.new()
	var remittance := state.task_instance_for_definition(&"remittance")
	assert_true(state.reveal_task_gift(remittance.instance_id).ok)
	assert_eq(state.wallet.money, 100)
	assert_true(remittance.gift_claimed)
	assert_true(state.dismiss_claimed_gift_task(remittance.instance_id))

	var intro := state.task_instance_for_definition(&"tin_boy_gift")
	assert_true(state.reveal_task_gift(intro.instance_id).ok)
	var claim := state.claim_task_gift(intro.instance_id)
	assert_true(claim.ok)
	var frog := claim.card as CardItemState
	assert_true(state.dismiss_claimed_gift_task(intro.instance_id))
	var unlock := state.unlock_store(&"toy", frog)
	assert_true(unlock.ok)
	assert_null(state.card_by_instance_id(frog.instance_id))
	assert_true(state.is_store_unlocked(&"toy"))
	assert_not_null(state.task_instance_for_definition(&"tin_boy_toy"))
	assert_not_null(state.task_instance_for_definition(&"self_care"))
	assert_not_null(state.task_instance_for_definition(&"girl_order"))


func test_next_night_is_blocked_until_self_care_is_confirmed() -> void:
	var state := QuestGameState.new()
	var blocked := state.begin_next_day()
	assert_false(blocked.ok)
	assert_eq(blocked.reason, QuestGameState.RESULT_REQUIRED_TASK_INCOMPLETE)
	_unlock_toy_shop(state)
	blocked = state.begin_next_day()
	assert_false(blocked.ok)
	var self_care := state.task_instance_for_definition(&"self_care")
	var car := state.grant_item(&"plastic_car", &"test")
	assert_true(state.assign_card(self_care.instance_id, &"self_care_item", car).ok)
	assert_true(state.confirm_task(self_care.instance_id).ok)
	assert_true(state.begin_next_day().ok)


func test_self_care_grows_each_persona_and_queues_first_reveals() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"dreamwalker"] = 0
	state.protagonist_persona_counts[&"mourner"] = 0
	_unlock_toy_shop(state)
	var self_care := state.task_instance_for_definition(&"self_care")
	var kaleidoscope := state.grant_item(&"kaleidoscope", &"test")
	assert_true(state.assign_card(self_care.instance_id, &"self_care_item", kaleidoscope).ok)
	assert_true(state.confirm_task(self_care.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_eq(int(state.protagonist_persona_counts[&"dreamwalker"]), 1)
	assert_eq(int(state.protagonist_persona_counts[&"mourner"]), 1)
	assert_true(&"dreamwalker" in state.pending_persona_reveal_ids)
	assert_true(&"mourner" in state.pending_persona_reveal_ids)
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.finish_arc().ok)
	assert_true(state.has_pending_task_offers())
	assert_eq(
		StringName(state.pending_task_offer_rounds[-1].kind),
		QuestGameState.OFFER_KIND_SELF_CARE,
	)


func test_self_care_growth_adds_only_one_when_the_item_is_stronger() -> void:
	var state := QuestGameState.new()
	_unlock_toy_shop(state)
	state.protagonist_persona_counts[&"dreamwalker"] = 1
	var self_care := state.task_instance_for_definition(&"self_care")
	var rose := state.grant_item(&"midnight_rose", &"test")
	assert_true(state.assign_card(self_care.instance_id, &"self_care_item", rose).ok)
	assert_true(state.confirm_task(self_care.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_eq(int(state.protagonist_persona_counts[&"dreamwalker"]), 2)


func test_self_care_no_longer_inherits_category_bans_from_previous_nights() -> void:
	var state := QuestGameState.new()
	_unlock_toy_shop(state)
	var first_task := state.task_instance_for_definition(&"self_care")
	var orchid := state.grant_item(&"plastic_orchid", &"test")
	assert_true(state.assign_card(first_task.instance_id, &"self_care_item", orchid).ok)
	assert_true(state.confirm_task(first_task.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.finish_arc().ok)

	state.pending_task_offer_rounds = [{
		"kind": QuestGameState.OFFER_KIND_SELF_CARE,
		"candidate_ids": [&"self_care_play"],
	}]
	var selected := state.choose_current_task_offer(&"self_care_play")
	assert_true(selected.ok)
	var second_task := state.task_instance(int(selected.task_instance_id))
	var toy := state.grant_item(&"plastic_car", &"test")
	assert_true(state.can_assign_card_to_task(second_task.instance_id, &"item", toy))
	var effective := state.effective_task_rule(
		second_task,
		QuestArcCatalog.task_by_id(&"self_care_play").slot_rules[0],
	)
	assert_false(&"toy" in effective.forbidden_any)
	assert_false(&"flower" in effective.forbidden_any)
	assert_eq(int(state.self_care_type_available_days[&"toy"]), state.day + 3)


func test_remittance_repeats_on_nights_one_and_eight_without_stacking() -> void:
	var state := QuestGameState.new()
	assert_eq(_active_task_count(state, &"remittance"), 1)
	state.day = 8
	state.activate_scheduled_tasks(8)
	assert_eq(_active_task_count(state, &"remittance"), 1)
	var old_remittance := state.task_instance_for_definition(&"remittance")
	assert_true(state.reveal_task_gift(old_remittance.instance_id).ok)
	assert_true(state.dismiss_claimed_gift_task(old_remittance.instance_id))
	state.day = 15
	state.activate_scheduled_tasks(15)
	assert_eq(_active_task_count(state, &"remittance"), 1)


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
	assert_eq(slot.item_id, &"plastic_car")


func _unlock_toy_shop(state: QuestGameState) -> void:
	var frog := state.grant_item(&"tin_frog", &"test")
	assert_true(state.unlock_store(&"toy", frog).ok)


func _active_task_count(state: QuestGameState, definition_id: StringName) -> int:
	return state.active_tasks().filter(
		func(instance: TaskInstanceState) -> bool:
			return instance.definition_id == definition_id
	).size()
