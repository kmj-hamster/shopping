extends GutTest


func test_bag_toggles_one_persistent_task_window() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var interface := await _spawn_interface(commerce)

	assert_false(interface.task_window.visible)
	assert_eq(interface.root.find_children("TaskWindow", "SlotTaskWindow", true, false).size(), 1)
	interface.toggle_task_window()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(interface.task_window.visible)
	assert_lt(interface.task_window.size.y, 520.0)
	interface.toggle_task_window()
	assert_false(interface.task_window.visible)
	assert_eq(interface.root.find_children("TaskWindow", "SlotTaskWindow", true, false).size(), 1)


func test_assigned_card_leaves_hand_and_appears_in_daily_slot() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var card := _buy_hash_brown(commerce)
	var interface := await _spawn_interface(commerce)
	assert_has(interface.hand_bar.card_views, card.instance_id)
	var slot := interface.task_window.slot_views[&"hungry"] as CardTaskSlot
	var drag_data := {"kind": &"card_item", "card": card, "source": &"hand"}

	assert_true(slot._can_drop_data(Vector2.ZERO, drag_data))
	slot._drop_data(Vector2.ZERO, drag_data)
	await get_tree().process_frame

	assert_does_not_have(interface.hand_bar.card_views, card.instance_id)
	slot = interface.task_window.slot_views[&"hungry"] as CardTaskSlot
	assert_eq(slot.card_holder.get_child_count(), 1)


func test_switching_tabs_preserves_assignments_without_creating_more_windows() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var card := _buy_hash_brown(commerce)
	var interface := await _spawn_interface(commerce)
	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", card).ok)

	interface.task_window._select_tab(SlotTaskWindow.TAB_RECIPES)
	assert_eq(interface.task_window.current_activity_id, &"recipe_night_radio")
	interface.task_window._select_tab(SlotTaskWindow.TAB_DAILY)
	assert_eq(interface.task_window.current_activity_id, &"wish_hungry")
	assert_eq(commerce.activity_state.card_for_slot(&"wish_hungry", &"hungry"), card)
	assert_eq(interface.root.find_children("TaskWindow", "SlotTaskWindow", true, false).size(), 1)


func test_hand_drop_returns_activity_card_to_global_hand() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var card := _buy_hash_brown(commerce)
	var interface := await _spawn_interface(commerce)
	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", card).ok)
	var drag_data := {"kind": &"card_item", "card": card, "source": &"activity_slot"}

	assert_true(interface.hand_bar._can_drop_data(Vector2.ZERO, drag_data))
	interface.hand_bar._drop_data(Vector2.ZERO, drag_data)
	await get_tree().process_frame

	assert_eq(card.location, CardItemState.Location.HAND)
	assert_has(interface.hand_bar.card_views, card.instance_id)
	assert_null(commerce.activity_state.card_for_slot(&"wish_hungry", &"hungry"))


func test_daily_action_confirms_locks_and_then_cancels_selection() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var card := _buy_hash_brown(commerce)
	var interface := await _spawn_interface(commerce)
	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", card).ok)
	await get_tree().process_frame

	assert_false(interface.task_window.action_button.disabled)
	interface.task_window._on_action_pressed()
	await get_tree().process_frame

	assert_true(commerce.activity_state.is_daily_confirmed(&"wish_hungry"))
	assert_eq(
		interface.task_window.action_button.text,
		TranslationServer.translate(&"slot.task.cancel_confirm"),
	)
	var slot := interface.task_window.slot_views[&"hungry"] as CardTaskSlot
	var card_view := slot.card_holder.get_child(0) as CardHandCard
	assert_false(card_view.drag_enabled)

	interface.task_window._on_action_pressed()
	await get_tree().process_frame
	assert_false(commerce.activity_state.is_daily_confirmed(&"wish_hungry"))
	assert_eq(
		interface.task_window.action_button.text,
		TranslationServer.translate(&"slot.task.confirm"),
	)


func _spawn_interface(commerce: SlotCommerceState) -> SlotPlayerInterface:
	var interface := SlotPlayerInterface.new()
	interface.commerce = commerce
	add_child_autoqfree(interface)
	await get_tree().process_frame
	return interface


func _buy_hash_brown(commerce: SlotCommerceState) -> CardItemState:
	var transaction := commerce.transaction_for_store(SlotDemoCatalog.STORE_FAST_FOOD)
	assert_true(transaction.select_shelf_slot(transaction.shelf_slots[0].slot_id).ok)
	var result := commerce.checkout_store(SlotDemoCatalog.STORE_FAST_FOOD)
	assert_true(result.ok)
	return result.purchased[0] as CardItemState
