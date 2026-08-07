extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_main_uses_responsive_ppt_regions_and_demo_content() -> void:
	var main := await _spawn_main()
	assert_not_null(main.get_node_or_null("PersistentSidebar"))
	assert_not_null(main.get_node_or_null("ContentViewportFrame"))
	assert_not_null(main.find_child("ContentViewport", true, false))
	assert_not_null(main.get_node_or_null("ProtagonistPortrait"))
	assert_not_null(main.get_node_or_null("LanguageButton"))
	assert_lt(main.language_button.anchor_right, 0.05)
	assert_gt(main.language_button.anchor_top, 0.90)
	assert_not_null(main.forbidden_cursor_texture)
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq((main.current_screen as QuestMapScreen).store_hotspots.size(), 2)
	assert_eq(main.task_dock.bookmark_column.get_child_count(), 3)
	for bookmark in main.task_dock.bookmark_column.get_children():
		assert_eq((bookmark as Button).tooltip_text, "")
	assert_eq(main.hand_bar.card_views.size(), 1)
	var fries_card := main.hand_bar.card_views.values()[0] as CardHandCard
	assert_eq(fries_card.definition.id, &"fries")
	assert_not_null(fries_card.item_image.texture)
	assert_eq(fries_card.custom_minimum_size, Vector2(112, 128))


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
	shop._toggle_shelf_popup()
	assert_true(shop.shelf_popup.visible)
	assert_eq(shop.shelf_buttons.size(), 6)


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
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": sunflower},
	)
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
	main._on_rule_focused(definition.slot_rules[0])
	assert_true(main.rule_detail_popup.visible)
	assert_eq(main.rule_detail_popup.required_row.get_child_count(), 1)
	assert_true(main.rule_detail_popup.bonus_section.visible)
	assert_eq(main.rule_detail_popup.bonus_row.get_child_count(), 2)


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


func test_item_detail_is_a_wide_shallow_top_right_strip() -> void:
	var main := await _spawn_main()
	main._show_item(QuestArcCatalog.item_by_id(&"fries"))
	assert_eq(main.detail_popup.detail_panel.offset_left, -280.0)
	assert_eq(main.detail_popup.detail_panel.offset_top, 4.0)
	assert_eq(main.detail_popup.detail_panel.offset_right, -4.0)
	assert_eq(main.detail_popup.detail_panel.offset_bottom, 99.0)
	main.detail_popup._show_property(&"food")
	assert_true(main.detail_popup.detail_panel.visible)
	assert_true(main.detail_popup.property_panel.visible)
	assert_gt(
		main.detail_popup.property_panel.offset_top,
		main.detail_popup.detail_panel.offset_bottom,
	)


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
	assert_false(synthesis.candidate_button.visible)
	assert_true(synthesis.stage_card(sunflower))
	assert_true(synthesis.stage_card(cola))
	await get_tree().process_frame
	assert_true(synthesis.candidate_button.visible)
	assert_false(synthesis.action_button.disabled)
	synthesis._on_candidate_pressed()
	assert_true(synthesis.candidate_hint_panel.visible)
	synthesis.output_animation_seconds = 0.0
	synthesis._on_action_pressed()
	await get_tree().process_frame
	assert_false(main.state.inventory.has(cola))
	assert_false(main.state.inventory.has(sunflower))
	assert_true(main.state.inventory.any(
		func(card: CardItemState) -> bool: return card.definition_id == &"scissors"
	))
	assert_true(main.state.synthesis_assignments.is_empty())


func test_leaving_synthesis_discards_unconfirmed_placement() -> void:
	var main := await _spawn_main()
	var cola := main.state.grant_item(&"cola") as CardItemState
	await get_tree().process_frame
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(cola))
	assert_eq(cola.location, CardItemState.Location.ACTIVITY_SLOT)
	synthesis.leave_requested.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq(cola.location, CardItemState.Location.HAND)
	assert_true(main.state.synthesis_assignments.is_empty())


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
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": sunflower},
	)
	map.location_popup.closed.emit()
	await get_tree().process_frame
	assert_null(map.location_popup)
	assert_true(main.hand_bar.card_views.has(sunflower.instance_id))
	assert_false(main.state.is_store_unlocked(&"record"))


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
