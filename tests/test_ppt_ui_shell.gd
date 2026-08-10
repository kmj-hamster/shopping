extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_main_uses_responsive_ppt_regions_and_demo_content() -> void:
	var main := await _spawn_main()
	assert_eq(main.theme, load("res://resources/fonts/shancha_ui_theme.tres"))
	assert_true(main.theme.default_font.has_char("A".unicode_at(0)))
	assert_true(main.theme.default_font.has_char("中".unicode_at(0)))
	assert_not_null(main.get_node_or_null("PersistentSidebar"))
	assert_not_null(main.get_node_or_null("ContentViewportFrame"))
	assert_not_null(main.find_child("ContentViewport", true, false))
	assert_not_null(main.get_node_or_null("ProtagonistPortrait"))
	assert_not_null(main.find_child("LanguageButton", true, false))
	assert_not_null(main.find_child("ClearSaveButton", true, false))
	assert_not_null(main.get_node_or_null("DebugButtonRow"))
	assert_eq(main.language_button.get_parent(), main.debug_button_row)
	assert_eq(main.clear_save_button.get_parent(), main.debug_button_row)
	assert_gt(main.debug_button_row.anchor_top, 0.90)
	assert_true(main.clear_save_button.pressed.is_connected(
		Callable(main, "_on_clear_save_pressed")
	))
	assert_not_null(main.forbidden_cursor_texture)
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq((main.current_screen as QuestMapScreen).store_hotspots.size(), 2)
	assert_eq(main.task_dock.bookmark_column.get_child_count(), 3)
	assert_true(main.task_dock.bookmark_column.clip_contents)
	for bookmark in main.task_dock.bookmark_column.get_children():
		var bookmark_button := bookmark as Button
		assert_eq(bookmark_button.tooltip_text, "")
		assert_true(bookmark_button.clip_text)
		assert_eq(bookmark_button.get_theme_font_size("font_size"), 12)
	assert_eq(main.hand_bar.card_views.size(), 6)
	var fries_card := main.hand_bar.card_views.values()[0] as CardHandCard
	assert_eq(fries_card.definition.id, &"fries")
	assert_not_null(fries_card.item_image.texture)
	assert_eq(fries_card.custom_minimum_size, CardHandCard.CARD_SIZE)


func test_flower_shop_starts_as_scene_and_opens_shelf_on_request() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	assert_not_null(shop)
	assert_false(shop.shelf_popup.visible)
	assert_not_null(shop.get_node_or_null("StoreOwnerPortrait"))
	assert_not_null(shop.find_child("ShelfButton", true, false))
	assert_not_null(shop.find_child("TalkButton", true, false))
	assert_not_null(shop.find_child("LeaveButton", true, false))
	assert_null(shop.title_label)
	assert_lt(shop.shelf_popup.anchor_right, shop.owner_portrait.anchor_left)
	assert_lt(shop.shelf_popup.anchor_right, shop.dialogue_panel.anchor_left)
	assert_lt(shop.owner_portrait.anchor_right, shop.navigation_column.anchor_left)
	assert_eq(shop.owner_dialogue_voice_players.size(), 3)
	assert_eq(shop.owner_dialogue_label.mouse_filter, Control.MOUSE_FILTER_PASS)
	shop._toggle_shelf_popup()
	assert_true(shop.shelf_popup.visible)
	assert_eq(shop.shelf_buttons.size(), 6)


func test_shop_dialogue_click_finishes_then_starts_the_next_line() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	shop.owner_dialogue_char_seconds = 10.0
	shop._present_owner_dialogue(TranslationServer.translate(&"demo.owner.flower.idle"), true)
	assert_true(shop.owner_dialogue_is_typing)
	assert_eq(shop.owner_dialogue_label.visible_characters, 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	shop._on_dialogue_panel_gui_input(click)
	assert_false(shop.owner_dialogue_is_typing)
	assert_eq(shop.owner_dialogue_label.visible_characters, -1)
	var completed_generation := shop.owner_dialogue_generation
	shop._on_dialogue_panel_gui_input(click)
	assert_true(shop.owner_dialogue_is_typing)
	assert_gt(shop.owner_dialogue_generation, completed_generation)


func test_each_shop_owner_can_configure_dialogue_voice_assets() -> void:
	var flower_owner := QuestArcCatalog.owner_for_store(&"flower")
	var record_owner := QuestArcCatalog.owner_for_store(&"record")
	for owner in [flower_owner, record_owner]:
		assert_not_null(owner)
		assert_eq(owner.dialogue_voice_streams.size(), 2)
		assert_eq(
			owner.dialogue_voice_streams[0].resource_path,
			"res://resources/audio/dialogue/robot_blip_a.wav",
		)
		assert_eq(
			owner.dialogue_voice_streams[1].resource_path,
			"res://resources/audio/dialogue/robot_blip_b.wav",
		)


func test_switching_shelf_selection_updates_existing_views_without_global_refresh() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	var available_slots := transaction.shelf_slots_for_page(1).filter(
		func(slot: ShelfSlotState) -> bool: return not slot.is_empty()
	)
	var first := available_slots[0] as ShelfSlotState
	var second := available_slots[1] as ShelfSlotState
	var first_button := shop.shelf_buttons[first.slot_id] as Button
	var second_button := shop.shelf_buttons[second.slot_id] as Button
	var hand_view := main.hand_bar.card_views.values()[0] as CardHandCard
	var bookmark := main.task_dock.bookmark_column.get_child(0) as Button
	var global_change_count := [0]
	main.state.state_changed.connect(func() -> void: global_change_count[0] += 1)
	shop._on_shelf_pressed(first.slot_id)
	var first_comment := shop.owner_dialogue_label.text
	assert_eq(global_change_count[0], 0)
	assert_same(shop.shelf_buttons[first.slot_id], first_button)
	assert_true(first_button.button_pressed)
	assert_true(shop.checkout_button.visible)
	assert_eq(main.detail_popup.current_definition.id, first.item_id)
	shop._on_shelf_pressed(second.slot_id)
	assert_eq(global_change_count[0], 0)
	assert_same(shop.shelf_buttons[first.slot_id], first_button)
	assert_same(shop.shelf_buttons[second.slot_id], second_button)
	assert_false(first_button.button_pressed)
	assert_true(second_button.button_pressed)
	assert_eq(main.detail_popup.current_definition.id, second.item_id)
	assert_ne(shop.owner_dialogue_label.text, first_comment)
	await get_tree().process_frame
	assert_same(main.hand_bar.card_views.values()[0], hand_view)
	assert_same(main.task_dock.bookmark_column.get_child(0), bookmark)
	assert_same(shop.shelf_buttons[first.slot_id], first_button)
	assert_same(shop.shelf_buttons[second.slot_id], second_button)


func test_shop_reuses_six_fixed_shelf_views_for_dialogue_and_pages() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	var roots: Array[Control] = []
	var buttons: Array[Button] = []
	for view in shop.shelf_views:
		roots.append(view.root as Control)
		buttons.append(view.button as Button)
	shop.show_owner_result(&"demo.owner.flower.idle")
	assert_eq(shop.shelf_grid.get_child_count(), CardShopTransaction.PAGE_SIZE)
	for view_index in shop.shelf_views.size():
		assert_same(shop.shelf_views[view_index].root, roots[view_index])
		assert_same(shop.shelf_views[view_index].button, buttons[view_index])
	assert_true(transaction.unlock_page(2))
	shop._on_page_pressed(2)
	assert_eq(shop.current_page, 2)
	assert_eq(shop.shelf_grid.get_child_count(), CardShopTransaction.PAGE_SIZE)
	for view_index in shop.shelf_views.size():
		assert_same(shop.shelf_views[view_index].root, roots[view_index])
		assert_same(shop.shelf_views[view_index].button, buttons[view_index])


func test_leaving_shop_clears_pending_checkout_state() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	shop._on_shelf_pressed(transaction.shelf_slots[0].slot_id)
	assert_eq(transaction.cart_count(), 1)
	assert_true(shop.checkout_button.visible)
	assert_false(shop.owner_dialogue_override_key.is_empty())
	shop.leave_requested.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq(transaction.cart_count(), 0)


func test_checkout_closes_the_top_right_popup() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	shop._on_shelf_pressed(transaction.shelf_slots[0].slot_id)
	assert_true(main.detail_popup.visible)
	shop._on_checkout_pressed()
	assert_false(main.detail_popup.visible)
	assert_false(main.rule_detail_popup.visible)


func test_opening_synthesis_clears_shop_checkout_and_comment() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	shop._on_shelf_pressed(transaction.shelf_slots[0].slot_id)
	assert_eq(transaction.cart_count(), 1)
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestSynthesisInterface)
	assert_eq(transaction.cart_count(), 0)
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	var returned_shop := main.current_screen as QuestShopScreen
	assert_not_null(returned_shop)
	assert_false(returned_shop.checkout_button.visible)
	assert_true(returned_shop.owner_dialogue_override_key.is_empty())
	assert_true(returned_shop.owner_dialogue_item_name.is_empty())


func test_locked_location_uses_confirmed_popup_then_enters_shop() -> void:
	var main := await _spawn_main()
	var sunflower := main.state.grant_item(&"sunflower") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	assert_not_null(map.location_popup)
	assert_true(map.location_popup is PaperActivityPopup)
	assert_true(main.rule_detail_popup.visible)
	assert_eq(main.rule_detail_popup.required_row.get_child_count(), 1)
	assert_true(main.task_dock.task_window == null or main.task_dock.task_window is PaperActivityPopup)
	var preallocated_preview := map.location_popup.unlock_slot.preview
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": sunflower},
	)
	assert_same(map.location_popup.unlock_slot.preview, preallocated_preview)
	assert_true(preallocated_preview.visible)
	assert_false(main.hand_bar.card_views.has(sunflower.instance_id))
	assert_false(map.location_popup.action_button.disabled)
	map.location_popup._on_action_pressed()
	await get_tree().process_frame
	assert_true(main.state.is_store_unlocked(&"record"))
	assert_false(main.state.inventory.has(sunflower))
	assert_true(main.current_screen is QuestShopScreen)
	assert_eq((main.current_screen as QuestShopScreen).store_id, &"record")
	assert_false(main.rule_detail_popup.visible)


func test_task_rule_panel_shows_written_bonus_only() -> void:
	var main := await _spawn_main()
	var girl_task := main.state.active_tasks().filter(
		func(task: TaskInstanceState) -> bool: return task.definition_id == &"girl_order"
	)[0] as TaskInstanceState
	var definition := QuestArcCatalog.task_by_id(girl_task.definition_id)
	main._show_item(QuestArcCatalog.item_by_id(&"sunflower"))
	assert_true(main.detail_popup.visible)
	main._on_rule_focused(definition.slot_rules[0])
	assert_true(main.rule_detail_popup.visible)
	assert_false(main.detail_popup.visible)
	assert_eq(main.rule_detail_popup.panel.offset_left, ItemDetailPopup.DETAIL_LEFT)
	assert_eq(main.rule_detail_popup.panel.offset_top, ItemDetailPopup.DETAIL_TOP)
	assert_eq(main.rule_detail_popup.panel.offset_right, ItemDetailPopup.DETAIL_RIGHT)
	assert_eq(main.rule_detail_popup.panel.offset_bottom, ItemDetailPopup.DETAIL_BOTTOM)
	var rule_style := main.rule_detail_popup.panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(rule_style.bg_color.a, 0.5, 0.001)
	var rule_property_style := (
		main.rule_detail_popup.property_panel.get_theme_stylebox("panel") as StyleBoxFlat
	)
	assert_almost_eq(rule_property_style.bg_color.a, 0.5, 0.001)
	assert_eq(main.rule_detail_popup.required_row.get_child_count(), 1)
	assert_true(main.rule_detail_popup.bonus_section.visible)
	assert_eq(main.rule_detail_popup.bonus_row.get_child_count(), 2)
	var required_chip := main.rule_detail_popup.required_row.get_child(0) as HBoxContainer
	var bonus_property_view := main.rule_detail_popup.bonus_row.get_child(0) as Control
	var bonus_reward_view := main.rule_detail_popup.bonus_row.get_child(1) as Control
	var required_icon := required_chip.get_child(0) as Button
	assert_not_null(required_icon)
	assert_eq(required_icon.custom_minimum_size.x, required_icon.custom_minimum_size.y)
	assert_true(required_icon.get_child(0) is TextureRect)
	assert_eq(
		(required_icon.get_child(0) as TextureRect).texture,
		load("res://resources/ui/property-food.png"),
	)
	var bonus_chip := main.rule_detail_popup.bonus_row.get_child(0) as HBoxContainer
	var bonus_icon := bonus_chip.get_child(0) as Button
	assert_true(bonus_icon.get_child(0) is TextureRect)
	assert_eq(
		(bonus_icon.get_child(0) as TextureRect).texture,
		load("res://resources/ui/property-salty.png"),
	)
	main.rule_detail_popup._show_property(&"food")
	assert_true(main.rule_detail_popup.property_panel.visible)
	assert_not_null(main.rule_detail_popup.property_icon_image.texture)
	main.rule_detail_popup._show_property(&"food")
	assert_false(main.rule_detail_popup.property_panel.visible)
	main.rule_detail_popup._show_property(&"food")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(10, 400)
	main.rule_detail_popup._input(outside_click)
	assert_false(main.rule_detail_popup.visible)
	main._on_rule_focused(definition.slot_rules[0])
	assert_same(main.rule_detail_popup.required_row.get_child(0), required_chip)
	assert_same(main.rule_detail_popup.bonus_row.get_child(0), bonus_property_view)
	assert_same(main.rule_detail_popup.bonus_row.get_child(1), bonus_reward_view)
	main._show_item(QuestArcCatalog.item_by_id(&"sunflower"))
	assert_true(main.detail_popup.visible)
	assert_false(main.rule_detail_popup.visible)


func test_task_popup_is_small_centered_and_uses_centered_copy() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	assert_not_null(popup)
	assert_almost_eq(popup.anchor_left, 0.32, 0.001)
	assert_almost_eq(popup.anchor_right, 0.83, 0.001)
	assert_almost_eq(popup.anchor_top, 0.10, 0.001)
	assert_almost_eq(popup.anchor_bottom, 0.70, 0.001)
	assert_eq(popup.title_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(popup.body_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(popup.body_margin.get_theme_constant("margin_left"), 36)
	assert_eq(popup.body_margin.get_theme_constant("margin_right"), 36)
	var slot := popup.slots_row.get_children().filter(
		func(child: Node) -> bool: return child is QuestTaskSlot
	)[0] as QuestTaskSlot
	var fries := main.state.inventory[0] as CardItemState
	var hand_card_size := (main.hand_bar.card_views[fries.instance_id] as CardHandCard).size
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	assert_true(main.state.assign_card(task.instance_id, definition.slot_rules[0].id, fries).ok)
	popup.refresh()
	await get_tree().process_frame
	var filled_slot := popup.slots_row.get_children().filter(
		func(child: Node) -> bool: return child is QuestTaskSlot
	)[0] as QuestTaskSlot
	var filled_card := filled_slot.card_view
	assert_not_null(filled_card)
	assert_eq(hand_card_size, CardHandCard.CARD_SIZE)
	assert_eq(filled_slot.size, CardHandCard.CARD_SIZE)
	assert_eq(filled_card.size, CardHandCard.CARD_SIZE)
	assert_true(filled_slot._has_point(Vector2(-QuestTaskSlot.DROP_MARGIN.x + 1.0, 70.0)))
	assert_true(filled_slot._has_point(Vector2(
		filled_slot.size.x + QuestTaskSlot.DROP_MARGIN.x - 1.0,
		70.0,
	)))
	assert_false(filled_slot._has_point(Vector2(
		-QuestTaskSlot.DROP_MARGIN.x - 1.0,
		70.0,
	)))
	assert_eq(
		popup.action_button.text,
		TranslationServer.translate(&"quest.ui.task.deliver_tomorrow"),
	)
	popup._on_action_pressed()
	assert_true(task.confirmed)
	assert_eq(
		popup.action_button.text,
		TranslationServer.translate(&"quest.ui.task.deliver_tomorrow"),
	)
	assert_eq(popup.feedback_label.text, "")


func test_clicking_task_slot_moves_matching_cards_left_and_lifts_them() -> void:
	var main := await _spawn_main()
	var sunflower := main.state.grant_item(&"sunflower") as CardItemState
	main.state.reorder_hand_card(sunflower, 0)
	await get_tree().process_frame
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var slot := popup.slots_row.get_children().filter(
		func(child: Node) -> bool: return child is QuestTaskSlot
	)[0] as QuestTaskSlot
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	slot._on_gui_input(click)
	var left_wrapper := main.hand_bar.card_row.get_child(0) as Control
	var left_card := left_wrapper.get_child(0) as CardHandCard
	assert_eq(left_card.definition.id, &"fries")
	assert_true(left_card.rule_match_highlighted)
	assert_almost_eq(left_card.position.y, -QuestHandBar.RULE_MATCH_LIFT, 0.01)
	var sunflower_view := main.hand_bar.card_views[sunflower.instance_id] as CardHandCard
	assert_false(sunflower_view.rule_match_highlighted)
	assert_almost_eq(sunflower_view.position.y, 0.0, 0.01)
	main._on_rule_focused(null)
	left_wrapper = main.hand_bar.card_row.get_child(0) as Control
	left_card = left_wrapper.get_child(0) as CardHandCard
	assert_eq(left_card.definition.id, &"sunflower")
	assert_almost_eq(left_card.position.y, 0.0, 0.01)


func test_task_assignment_reuses_bookmark_popup_slot_and_card_view() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var slot := popup.slot_views[&"food"] as QuestTaskSlot
	var bookmark := main.task_dock.bookmark_buttons[task.instance_id] as Button
	var preallocated_card_view := slot.card_view
	var fries := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"fries"
	)[0] as CardItemState

	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	assert_same(main.task_dock.task_window, popup)
	assert_same(main.task_dock.bookmark_buttons[task.instance_id], bookmark)
	assert_same(popup.slot_views[&"food"], slot)
	assert_same(slot.card_view, preallocated_card_view)
	assert_same(slot.card_view.card, fries)
	assert_true(slot.card_view.visible)
	main.task_dock._toggle_task(task.instance_id)
	assert_null(main.task_dock.task_window)
	main.task_dock._toggle_task(task.instance_id)
	assert_same(main.task_dock.task_window, popup)
	assert_true(popup.visible)


func test_task_assignment_inside_shop_does_not_rebuild_shelf_views() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var original_shelf_buttons := shop.shelf_buttons.duplicate()
	var task := main.state.task_instance_for_definition(&"girl_order")
	var fries := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"fries"
	)[0] as CardItemState

	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	for slot_id in original_shelf_buttons:
		assert_same(shop.shelf_buttons[slot_id], original_shelf_buttons[slot_id])


func test_self_and_owner_tasks_use_contextual_actions_and_owner_rule_titles() -> void:
	var main := await _spawn_main()
	var self_task := main.state.task_instance_for_definition(&"self_care")
	main.task_dock._toggle_task(self_task.instance_id)
	await get_tree().process_frame
	assert_eq(
		main.task_dock.task_window.action_button.text,
		TranslationServer.translate(&"quest.ui.task.enjoy_tonight"),
	)
	main.task_dock._close_task()
	main.state.interact_with_store_owner(&"flower")
	await get_tree().process_frame
	var owner_task := main.state.task_instance_for_definition(&"flower_owner_request")
	main.task_dock._toggle_task(owner_task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	assert_true(popup.action_button.disabled)
	assert_eq(
		popup.feedback_label.text,
		TranslationServer.translate(&"quest.ui.task.owner_elsewhere"),
	)
	var owner_slots := popup.slots_row.get_children().filter(
		func(child: Node) -> bool: return child is QuestTaskSlot
	)
	for raw_slot in owner_slots:
		assert_false((raw_slot as QuestTaskSlot).caption_label.visible)
	var owner_definition := QuestArcCatalog.task_by_id(owner_task.definition_id)
	var owner_rule := owner_definition.slot_rules[0] as CardSlotRule
	(owner_slots[0] as QuestTaskSlot).rule_focused.emit(owner_rule)
	assert_eq(
		main.rule_detail_popup.title_label.text,
		TranslationServer.translate(owner_rule.display_name_key),
	)
	assert_eq(main.rule_detail_popup.title_label.get_theme_font_size("font_size"), 12)
	assert_eq(
		main.rule_detail_popup.title_label.text_overrun_behavior,
		TextServer.OVERRUN_TRIM_ELLIPSIS,
	)


func test_fries_detail_uses_ppt_food_and_salty_icons() -> void:
	var main := await _spawn_main()
	main._show_item(QuestArcCatalog.item_by_id(&"fries"))
	await get_tree().process_frame
	var food_button := main.detail_popup.property_buttons[&"food"] as Button
	var salty_button := main.detail_popup.property_buttons[&"salty"] as Button
	assert_eq(
		(food_button.get_child(0) as TextureRect).texture,
		load("res://resources/ui/property-food.png"),
	)
	assert_eq(
		(salty_button.get_child(0) as TextureRect).texture,
		load("res://resources/ui/property-salty.png"),
	)


func test_clicking_the_same_item_card_toggles_its_popup() -> void:
	var main := await _spawn_main()
	var fries := QuestArcCatalog.item_by_id(&"fries")
	main._show_item(fries)
	assert_true(main.detail_popup.visible)
	main._show_item(fries)
	assert_false(main.detail_popup.visible)
	main._show_item(fries)
	assert_true(main.detail_popup.visible)


func test_drag_source_disappears_and_preview_is_above_popups() -> void:
	var main := await _spawn_main()
	var view := main.hand_bar.card_views.values()[0] as CardHandCard
	var preview := view._build_drag_preview(Vector2.ZERO)
	assert_eq(preview.z_index, 4096)
	assert_false(preview.z_as_relative)
	view.return_animation_seconds = 0.0
	view._begin_drag_visual()
	assert_false(view.visible)
	view._end_drag_visual(false)
	assert_true(view.visible)
	preview.free()


func test_item_detail_icons_append_without_overlap_and_close_outside() -> void:
	var main := await _spawn_main()
	main._show_item(QuestArcCatalog.item_by_id(&"sunflower"))
	await get_tree().process_frame
	assert_eq(main.detail_popup.detail_panel.offset_left, ItemDetailPopup.DETAIL_LEFT)
	assert_eq(main.detail_popup.detail_panel.offset_top, ItemDetailPopup.DETAIL_TOP)
	assert_eq(main.detail_popup.detail_panel.offset_right, ItemDetailPopup.DETAIL_RIGHT)
	assert_eq(main.detail_popup.detail_panel.offset_bottom, ItemDetailPopup.DETAIL_BOTTOM)
	assert_not_null(main.detail_popup.item_image.texture)
	assert_almost_eq(
		main.detail_popup.item_image.get_parent().size.y,
		main.detail_popup.description_label.get_parent().size.y,
		1.0,
	)
	var property_band := main.detail_popup.detail_panel.find_child("PropertyBand", true, false) as PanelContainer
	assert_not_null(property_band)
	assert_gt(property_band.size.x, main.detail_popup.description_label.size.x)
	var panel_style := main.detail_popup.detail_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(panel_style.bg_color.a, 0.5, 0.001)
	var band_style := property_band.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(band_style.bg_color.a, 0.5, 0.001)
	var property_panel_style := (
		main.detail_popup.property_panel.get_theme_stylebox("panel") as StyleBoxFlat
	)
	assert_almost_eq(property_panel_style.bg_color.a, 0.5, 0.001)
	var lamp_view := main.detail_popup.property_views[&"lamp"] as Dictionary
	var property_root := lamp_view.root as Control
	var property_button := lamp_view.button as Button
	assert_not_null(property_button)
	assert_almost_eq(property_button.size.x, property_button.size.y, 0.01)
	assert_true(property_button.get_child_count() > 0)
	var base_icon := property_button.get_child(0) as TextureRect
	assert_not_null(base_icon)
	assert_not_null(base_icon.texture)
	main.detail_popup._show_property(&"lamp")
	await get_tree().process_frame
	assert_true(main.detail_popup.detail_panel.visible)
	assert_true(main.detail_popup.property_panel.visible)
	var actual_detail_bottom := (
		main.detail_popup.detail_panel.offset_top
		+ maxf(
			main.detail_popup.detail_panel.size.y,
			main.detail_popup.detail_panel.get_combined_minimum_size().y,
		)
	)
	assert_true(main.detail_popup.property_panel.offset_top >= actual_detail_bottom + 10.0)
	var property_click := InputEventMouseButton.new()
	property_click.button_index = MOUSE_BUTTON_LEFT
	property_click.pressed = true
	property_click.position = property_button.get_global_rect().get_center()
	main.detail_popup._input(property_click)
	assert_true(main.detail_popup.property_panel.visible)
	main.detail_popup._show_property(&"lamp")
	assert_false(main.detail_popup.property_panel.visible)
	main.detail_popup._show_property(&"lamp")
	assert_true(main.detail_popup.property_panel.visible)
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(10, 400)
	main.detail_popup._input(outside_click)
	assert_false(main.detail_popup.property_panel.visible)
	assert_true(main.detail_popup.detail_panel.visible)
	main._show_item(QuestArcCatalog.item_by_id(&"fries"))
	main._show_item(QuestArcCatalog.item_by_id(&"sunflower"))
	assert_same((main.detail_popup.property_views[&"lamp"] as Dictionary).root, property_root)
	assert_same((main.detail_popup.property_views[&"lamp"] as Dictionary).button, property_button)


func test_synthesis_is_a_material_first_dedicated_space() -> void:
	var main := await _spawn_main()
	var cola := main.state.grant_item(&"cola") as CardItemState
	var sunflower := main.state.grant_item(&"sunflower") as CardItemState
	await get_tree().process_frame
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_not_null(synthesis)
	assert_eq(synthesis.material_slots.size(), 2)
	assert_true(synthesis.candidate_buttons.values().all(
		func(button: Button) -> bool: return not button.visible
	))
	assert_true(synthesis.stage_card(&"base", sunflower))
	var soft_gauze := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"soft_gauze"
	)[0] as CardItemState
	assert_true(synthesis.stage_card(&"fuel", soft_gauze))
	assert_true(main.state.select_synthesis_persona(&"reverie"))
	await get_tree().process_frame
	assert_true(synthesis.candidate_buttons.has(&"recipe_midnight_rose"))
	assert_true(synthesis.action_button.disabled)
	synthesis._on_candidate_pressed(&"recipe_midnight_rose")
	assert_false(synthesis.action_button.disabled)
	synthesis._on_action_pressed()
	await get_tree().process_frame
	assert_false(main.state.inventory.has(sunflower))
	assert_true(main.state.inventory.any(
		func(card: CardItemState) -> bool: return card.definition_id == &"midnight_rose"
	))
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.NARRATIVE)
	assert_eq(main.state.synthesis_base_instance_id, 0)


func test_leaving_synthesis_discards_unconfirmed_placement() -> void:
	var main := await _spawn_main()
	var cola := main.state.grant_item(&"cola") as CardItemState
	await get_tree().process_frame
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(&"base", cola))
	assert_eq(cola.location, CardItemState.Location.ACTIVITY_SLOT)
	synthesis.leave_requested.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq(cola.location, CardItemState.Location.HAND)
	assert_eq(main.state.synthesis_base_instance_id, 0)


func test_protagonist_button_toggles_synthesis_back_to_previous_shop() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestSynthesisInterface)
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestShopScreen)
	assert_eq((main.current_screen as QuestShopScreen).store_id, &"flower")


func test_primary_screens_are_reused_across_navigation() -> void:
	var main := await _spawn_main()
	var map := main.current_screen as QuestMapScreen
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	main._show_map()
	await get_tree().process_frame
	assert_same(main.current_screen, map)
	main._show_shop(&"flower")
	await get_tree().process_frame
	assert_same(main.current_screen, shop)
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	main._return_from_synthesis()
	await get_tree().process_frame
	main._show_synthesis()
	await get_tree().process_frame
	assert_same(main.current_screen, synthesis)
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.DRAFT)
	assert_true(synthesis.draft_layer.visible)
	assert_false(synthesis.narrative_overlay.visible)
	assert_false(synthesis.result_layer.visible)


func test_arc_uses_item_strip_reward_summary_and_click_advance() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	var fries := main.state.inventory[0] as CardItemState
	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	assert_true(main.state.confirm_task(task.instance_id).ok)
	assert_true(main.state.begin_next_day().ok)
	main.arc_fade_seconds = 0.0
	main.arc_typewriter_char_seconds = 0.0
	main._run_arc()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.arc_overlay.visible)
	assert_eq(main.arc_image.texture, QuestArcCatalog.item_by_id(&"fries").image)
	assert_true(main.arc_reward_label.text.contains("12"))
	assert_true(main.arc_cursor_label.visible)
	for index in 8:
		main._on_arc_advance_requested()
		await get_tree().process_frame
		if not main.transition_in_progress:
			break
	assert_false(main.transition_in_progress)
	assert_eq(main.state.day, 2)


func test_closing_location_popup_returns_unconfirmed_card() -> void:
	var main := await _spawn_main()
	var sunflower := main.state.grant_item(&"sunflower") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	var popup := map.location_popup
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": sunflower},
	)
	map.location_popup.closed.emit()
	await get_tree().process_frame
	assert_null(map.location_popup)
	assert_true(main.hand_bar.card_views.has(sunflower.instance_id))
	assert_false(main.state.is_store_unlocked(&"record"))
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	assert_same(map.location_popup, popup)
	assert_null(map.location_popup.unlock_slot.pending_card)
	assert_true(map.location_popup.visible)


func test_switching_spaces_clears_location_popup_draft() -> void:
	var main := await _spawn_main()
	var sunflower := main.state.grant_item(&"sunflower") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": sunflower},
	)
	assert_true(main.hand_bar.temporarily_hidden_card_ids.has(sunflower.instance_id))
	main._show_synthesis()
	await get_tree().process_frame
	assert_true(main.hand_bar.temporarily_hidden_card_ids.is_empty())
	assert_eq(sunflower.location, CardItemState.Location.HAND)
	assert_false(main.state.is_store_unlocked(&"record"))


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
