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


func test_item_clicks_share_one_manual_close_detail_popup_across_hand_and_slot() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var sunflower := _add_card(commerce, &"flower_sunflower", 100)
	var hash_brown := _add_card(commerce, &"fast_hash_brown", 101)
	var interface := await _spawn_interface(commerce)
	var popup := interface.item_detail_popup
	var hand_view := interface.hand_bar.card_views[sunflower.instance_id] as CardHandCard

	_click_card(hand_view)
	assert_true(popup.visible)
	assert_eq(popup.current_definition.id, &"flower_sunflower")
	assert_eq(interface.root.find_children("ItemDetailPopup", "ItemDetailPopup", true, false).size(), 1)

	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", hash_brown).ok)
	await get_tree().process_frame
	var slot := interface.task_window.slot_views[&"hungry"] as CardTaskSlot
	var slotted_view := slot.card_holder.get_child(0) as CardHandCard
	_click_card(slotted_view)
	assert_true(popup.visible)
	assert_eq(popup.current_definition.id, &"fast_hash_brown")
	assert_eq(interface.root.find_children("ItemDetailPopup", "ItemDetailPopup", true, false).size(), 1)

	popup.close_button.pressed.emit()
	assert_false(popup.visible)


func test_property_icon_hover_opens_and_hides_its_explanation_panel() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var interface := await _spawn_interface(commerce)
	var popup := interface.item_detail_popup
	popup.show_item(SlotDemoCatalog.item_by_id(&"flower_sunflower"))
	var lamp_badge := popup.property_badges[CardPropertySet.ASPECT_LAMP] as Button

	lamp_badge.mouse_entered.emit()
	assert_true(popup.property_popup.visible)
	assert_eq(
		popup.property_popup_name.text,
		TranslationServer.translate(&"slot.aspect.lamp"),
	)
	assert_eq(
		popup.property_popup_description.text,
		TranslationServer.translate(&"slot.aspect.lamp.description"),
	)
	lamp_badge.mouse_exited.emit()
	assert_false(popup.property_popup.visible)


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


func test_card_drag_uses_a_full_card_visual_and_removes_the_source_from_view() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var card := _buy_hash_brown(commerce)
	var following_card := _add_card(commerce, &"toy_glass_marble", 100)
	var interface := await _spawn_interface(commerce)
	var source := interface.hand_bar.card_views[card.instance_id] as CardHandCard
	var following := interface.hand_bar.card_views[following_card.instance_id] as CardHandCard
	var following_position := following.position
	var grab_position := Vector2(31, 24)
	var preview := source._build_drag_preview(grab_position)
	add_child_autoqfree(preview)
	await get_tree().process_frame

	assert_eq(preview.card, card)
	assert_eq(preview.definition, source.definition)
	assert_false(preview.drag_enabled)
	assert_eq(preview.custom_minimum_size, source.custom_minimum_size)
	assert_eq(preview.title_label.text, source.title_label.text)
	assert_eq(preview.aspect_label.text, source.aspect_label.text)
	assert_eq(preview.position, -grab_position)

	source._begin_drag_visual()
	await get_tree().process_frame
	assert_true(source.visible)
	assert_eq(source.self_modulate.a, 0.0)
	assert_eq(following.position, following_position)
	source._end_drag_visual(false)
	assert_eq(source.self_modulate.a, 1.0)


func test_successful_move_keeps_old_card_visual_hidden_until_state_refresh() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var card := _buy_hash_brown(commerce)
	var interface := await _spawn_interface(commerce)
	var source := interface.hand_bar.card_views[card.instance_id] as CardHandCard

	source._begin_drag_visual()
	assert_true(commerce.activity_state.assign_card(&"wish_hungry", &"hungry", card).ok)
	source._end_drag_visual(true)

	assert_eq(source.self_modulate.a, 0.0)
	await get_tree().process_frame
	assert_does_not_have(interface.hand_bar.card_views, card.instance_id)


func test_dropping_a_hand_card_reorders_it_only_after_release() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var first := _add_card(commerce, &"fast_hash_brown", 101)
	var second := _add_card(commerce, &"toy_glass_marble", 102)
	var third := _add_card(commerce, &"record_fluorescent_single", 103)
	var interface := await _spawn_interface(commerce)
	var second_view := interface.hand_bar.card_views[second.instance_id] as CardHandCard
	var third_view := interface.hand_bar.card_views[third.instance_id] as CardHandCard
	var third_position := third_view.position
	var drag_data := {"kind": &"card_item", "card": second, "source": &"hand"}

	second_view._begin_drag_visual()
	await get_tree().process_frame
	assert_eq(third_view.position, third_position)
	assert_eq(commerce.inventory[0], first)
	assert_true(interface.hand_bar._can_drop_data(Vector2.ZERO, drag_data))
	interface.hand_bar._drop_data(Vector2.ZERO, drag_data)
	second_view._end_drag_visual(true)
	await get_tree().process_frame

	assert_eq(commerce.inventory[0], second)
	assert_eq(commerce.inventory[1], first)
	assert_eq(commerce.inventory[2], third)


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


func test_recipe_keeps_running_while_window_is_closed_and_returns_output_to_hand() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var sound := _add_card(commerce, &"record_fluorescent_single", 100)
	var shell := _add_card(commerce, &"toy_glass_marble", 101)
	var tuning := _add_card(commerce, &"fast_hash_brown", 102)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"sound", sound
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"shell", shell
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"tuning", tuning
	).ok)
	var interface := await _spawn_interface(commerce)
	interface.toggle_task_window()
	interface.task_window._select_tab(SlotTaskWindow.TAB_RECIPES)
	await get_tree().process_frame

	assert_false(interface.task_window.action_button.disabled)
	interface.task_window._on_action_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(commerce.active_synthesis)
	assert_true(interface.task_window.synthesis_progress.visible)
	var sound_slot := interface.task_window.slot_views[&"sound"] as CardTaskSlot
	var sound_view := sound_slot.card_holder.get_child(0) as CardHandCard
	assert_false(sound_view.drag_enabled)

	interface.toggle_task_window()
	assert_false(interface.task_window.visible)
	interface._process(2.5)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(commerce.active_synthesis)
	assert_eq(commerce.inventory.size(), 1)
	assert_eq(commerce.inventory[0].definition_id, &"craft_clear_receiver")
	assert_has(interface.hand_bar.card_views, commerce.inventory[0].instance_id)
	interface.toggle_task_window()
	await get_tree().process_frame
	assert_true(interface.task_window.visible)
	assert_string_contains(
		interface.task_window.result_label.text,
		str(TranslationServer.translate(
			SlotDemoCatalog.item_by_id(&"craft_clear_receiver").display_name_key
		)),
	)


func test_unlocked_owner_request_consumes_bear_and_keeps_completed_result_visible() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	commerce.set_owner_level(&"balloon", 2)
	var bear := _add_card(commerce, &"craft_comfort_bear", 100)
	assert_true(commerce.activity_state.assign_card(
		&"request_balloon_hug", &"hug", bear
	).ok)
	var interface := await _spawn_interface(commerce)
	interface.toggle_task_window()
	interface.task_window._select_tab(SlotTaskWindow.TAB_REQUESTS)
	await get_tree().process_frame

	assert_eq(interface.task_window.current_activity_id, &"request_balloon_hug")
	assert_false(interface.task_window.action_button.disabled)
	interface.task_window._on_action_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(commerce.is_request_completed(&"request_balloon_hug"))
	assert_true(commerce.inventory.is_empty())
	assert_eq(commerce.story_flags[&"balloon_hug"], &"comfort")
	assert_true(interface.task_window.action_button.disabled)
	assert_eq(
		interface.task_window.action_button.text,
		TranslationServer.translate(&"slot.request.delivered"),
	)
	assert_eq(
		interface.task_window.result_label.text,
		TranslationServer.translate(&"slot.request.balloon_hug.result.comfort"),
	)
	assert_true(
		(interface.task_window.activity_tabs.get_child(0) as Button).text.begins_with("✓")
	)
	assert_eq(
		interface.root.find_children("TaskWindow", "SlotTaskWindow", true, false).size(),
		1,
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


func _add_card(
	commerce: SlotCommerceState,
	definition_id: StringName,
	instance_id: int,
) -> CardItemState:
	var card := CardItemState.new(instance_id, definition_id)
	commerce.inventory.append(card)
	return card


func _click_card(view: CardHandCard) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	view._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	view._gui_input(release)
