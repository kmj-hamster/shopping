extends GutTest


func test_manifest_contains_twelve_daily_and_nine_self_care_pool_entries() -> void:
	var daily_count := 0
	var self_care_count := 0
	for raw_task in QuestArcCatalog.manifest().tasks:
		var definition := raw_task as TaskDefinition
		if definition.selection_pool == TaskDefinition.SelectionPool.DAILY:
			daily_count += 1
		elif definition.selection_pool == TaskDefinition.SelectionPool.SELF_CARE:
			self_care_count += 1
	assert_eq(daily_count, 12)
	assert_eq(self_care_count, 9)
	assert_true(QuestArcCatalog.manifest().validation_errors().is_empty())


func test_offer_rounds_respect_the_four_task_cap_and_do_not_repeat_rejected_cards() -> void:
	var state := QuestGameState.new()
	_unlock_toy_shop(state)
	state.day = 2
	var offers := state.prepare_task_offers_for_day()
	assert_eq(state.active_daily_task_count(), 2)
	assert_eq(offers.size(), 3)
	assert_eq(StringName(offers[0].kind), QuestGameState.OFFER_KIND_DAILY)
	assert_eq(StringName(offers[1].kind), QuestGameState.OFFER_KIND_DAILY)
	assert_eq(StringName(offers[2].kind), QuestGameState.OFFER_KIND_SELF_CARE)
	var seen_daily_ids: Dictionary = {}
	for offer_index in 2:
		for raw_id in offers[offer_index].candidate_ids:
			var candidate_id := StringName(raw_id)
			if candidate_id == QuestGameState.DEEP_NIGHT_JOB_ID:
				continue
			assert_false(seen_daily_ids.has(candidate_id))
			seen_daily_ids[candidate_id] = true


func test_deep_night_job_pays_immediately_without_adding_a_task() -> void:
	var state := QuestGameState.new()
	state.day = 2
	state.pending_task_offer_rounds = [{
		"kind": QuestGameState.OFFER_KIND_DAILY,
		"candidate_ids": [QuestGameState.DEEP_NIGHT_JOB_ID],
	}]
	var previous_count := state.active_daily_task_count()
	var result := state.choose_current_task_offer(QuestGameState.DEEP_NIGHT_JOB_ID)
	assert_true(result.ok)
	assert_eq(int(result.money_reward), 12)
	assert_eq(state.wallet.money, 12)
	assert_eq(state.active_daily_task_count(), previous_count)
	assert_false(state.has_pending_task_offers())


func test_unfinished_daily_task_expires_after_three_nights_and_returns_its_card() -> void:
	var state := QuestGameState.new()
	state.day = 2
	var daily := _select_directly(state, QuestGameState.OFFER_KIND_DAILY, &"daily_rooftop_thermos")
	var drink := state.grant_item(&"cola", &"test")
	assert_true(state.assign_card(daily.instance_id, &"item", drink).ok)
	state.day = 4
	_confirm_opening_self_care(state, &"ratty_doll")
	var begin := state.begin_next_day()
	assert_true(begin.ok)
	assert_eq(int(begin.expired_task_count), 1)
	assert_true(state.apply_arc_effects().ok)
	assert_true(daily.settled)
	assert_eq(drink.location, CardItemState.Location.HAND)
	assert_eq(int(state.task_pool_available_days[&"daily_rooftop_thermos"]), 7)
	assert_eq(StringName(state.task_history[&"daily_rooftop_thermos"]), &"expired")


func test_completed_daily_task_observes_the_seven_night_cooldown() -> void:
	var state := QuestGameState.new()
	state.day = 2
	var daily := _select_directly(state, QuestGameState.OFFER_KIND_DAILY, &"daily_rooftop_thermos")
	var drink := state.grant_item(&"cola", &"test")
	assert_true(state.assign_card(daily.instance_id, &"item", drink).ok)
	assert_true(state.confirm_task(daily.instance_id).ok)
	_confirm_opening_self_care(state, &"ratty_doll")
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_eq(int(state.task_pool_available_days[&"daily_rooftop_thermos"]), 9)


func test_self_care_candidates_require_a_fully_matching_accessible_item_and_cool_by_type() -> void:
	var state := QuestGameState.new()
	state.day = 2
	var book := state.grant_item(&"mirror_and_lamp", &"test")
	var candidates := state._eligible_pooled_tasks(TaskDefinition.SelectionPool.SELF_CARE)
	assert_true(candidates.any(
		func(definition: TaskDefinition) -> bool: return definition.id == &"self_care_read"
	))
	assert_not_null(book)
	state.inventory.erase(book)
	candidates = state._eligible_pooled_tasks(TaskDefinition.SelectionPool.SELF_CARE)
	assert_false(candidates.any(
		func(definition: TaskDefinition) -> bool: return definition.id == &"self_care_read"
	))
	state.inventory.append(book)
	var selected := _select_directly(
		state, QuestGameState.OFFER_KIND_SELF_CARE, &"self_care_read"
	)
	assert_not_null(selected)
	assert_eq(int(state.self_care_type_available_days[&"book"]), 5)


func test_todo_countdown_updates_from_three_to_two_without_widening_the_title_hit_area() -> void:
	var state := QuestGameState.new()
	state.day = 2
	var daily := _select_directly(state, QuestGameState.OFFER_KIND_DAILY, &"daily_rooftop_thermos")
	var dock := QuestTaskDock.new()
	dock.setup(state)
	add_child_autoqfree(dock)
	await get_tree().process_frame
	var bookmark := dock.bookmark_buttons[daily.instance_id] as Button
	var countdown := bookmark.get_node("NightCountdown") as Label
	assert_eq(countdown.text, "3")
	assert_eq(countdown.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_lt(bookmark.size.x, QuestTaskDock.TASK_TEXT_MAX_WIDTH)
	state.day = 3
	dock.refresh()
	assert_eq(countdown.text, "2")


func test_offer_overlay_prebuilds_three_cards_and_reuses_them_between_rounds() -> void:
	var state := QuestGameState.new()
	state.day = 2
	state.pending_task_offer_rounds = [{
		"kind": QuestGameState.OFFER_KIND_DAILY,
		"candidate_ids": [
			&"daily_midnight_radio",
			&"daily_rain_librarian",
			&"daily_rooftop_thermos",
		],
	}, {
		"kind": QuestGameState.OFFER_KIND_DAILY,
		"candidate_ids": [
			&"daily_moth_rehearsal",
			&"daily_paper_crown",
			&"daily_last_festival",
		],
	}]
	var overlay := QuestTaskOfferOverlay.new()
	overlay.setup(state)
	add_child_autoqfree(overlay)
	await get_tree().process_frame
	overlay.show_current_offer()
	assert_true(overlay.visible)
	assert_eq(overlay.cards_row.get_child_count(), 3)
	assert_eq(
		overlay.heading_label.text,
		TranslationServer.translate(&"quest.ui.offer.daily.heading"),
	)
	var original_buttons := overlay.cards_row.get_children()
	overlay._select_candidate(&"daily_rain_librarian")
	assert_true(overlay.visible)
	assert_not_null(state.task_instance_for_definition(&"daily_rain_librarian"))
	for index in original_buttons.size():
		assert_same(overlay.cards_row.get_child(index), original_buttons[index])
	assert_eq(
		(overlay.offer_card_views[0].title as Label).text,
		TranslationServer.translate(&"task.daily.moth_rehearsal.name"),
	)


func _select_directly(
	state: QuestGameState,
	kind: StringName,
	task_id: StringName,
) -> TaskInstanceState:
	state.pending_task_offer_rounds = [{"kind": kind, "candidate_ids": [task_id]}]
	var result := state.choose_current_task_offer(task_id)
	assert_true(result.ok)
	return state.task_instance(int(result.task_instance_id))


func _confirm_opening_self_care(state: QuestGameState, item_id: StringName) -> void:
	var task := state.activate_task(&"self_care")
	assert_not_null(task)
	var item := state.grant_item(item_id, &"test")
	assert_true(state.assign_card(task.instance_id, &"self_care_item", item).ok)
	assert_true(state.confirm_task(task.instance_id).ok)


func _unlock_toy_shop(state: QuestGameState) -> void:
	var frog := state.grant_item(&"tin_frog", &"test")
	assert_true(state.unlock_store(&"toy", frog).ok)
