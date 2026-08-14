extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_opening_ui_has_letters_pagination_tests_unlock_cards_and_three_visible_stores() -> void:
	var main := await _spawn_main()
	assert_eq(main.task_dock.bookmark_buttons.size(), 6)
	assert_eq(main.state.inventory.size(), 12)
	for persona_id in CardPropertySet.PERSONAS:
		var persona_card := PersonaMaskCatalog.card_for_persona(persona_id)
		assert_true(main.hand_bar.card_views.has(persona_card.instance_id))
	for card in main.state.inventory:
		assert_true(main.hand_bar.card_views.has(card.instance_id))
	assert_eq(main.hand_bar.card_views.size(), 16)
	assert_eq(main.map_screen.store_hotspots.size(), 5)
	assert_true((main.map_screen.store_hotspots[&"toy"] as Button).visible)
	assert_true((main.map_screen.store_hotspots[&"fast_food"] as Button).visible)
	assert_true((main.map_screen.store_hotspots[&"flower"] as Button).visible)
	assert_false((main.map_screen.store_hotspots[&"record"] as Button).visible)
	assert_false((main.map_screen.store_hotspots[&"bookstore"] as Button).visible)
	for hotspot in main.map_screen.store_hotspots.values():
		assert_eq((hotspot as Button).tooltip_text, "")
	main.hand_bar.show_tab(QuestHandBar.TAB_MASKS)
	assert_eq(main.hand_bar.card_views.size(), 16)
	assert_false(main.state.select_synthesis_persona(&"nightwalker"))


func test_money_letter_flips_to_plus_one_hundred_and_disappears_on_close() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"remittance")
	main.task_dock._toggle_task(task.instance_id)
	var slot := main.task_dock.task_window.gift_slot
	assert_true(slot.back_button.visible)
	slot._on_back_pressed()
	await get_tree().process_frame
	assert_eq(main.state.wallet.money, 100)
	assert_eq(
		main.task_dock.receipt_money_label.text,
		TranslationServer.translate(&"demo.ui.money") % 100,
	)
	assert_true(slot.money_face.visible)
	assert_eq(slot.money_label.text, "+100")
	main.task_dock._close_task()
	await get_tree().process_frame
	assert_null(main.state.task_instance_for_definition(&"remittance"))


func test_opening_task_popups_stay_inside_content_frame() -> void:
	var main := await _spawn_main()
	for task in main.state.active_tasks():
		main.task_dock._toggle_task(task.instance_id)
		await get_tree().process_frame
		var popup := main.task_dock.task_window
		assert_same(popup.get_parent(), main.task_popup_layer)
		assert_same(popup.drag_bounds_control, main.task_popup_layer)
		assert_true(
			main.task_popup_layer.get_global_rect().encloses(popup.get_global_rect()),
			"%s must stay inside ContentViewportFrame" % task.definition_id,
		)


func test_opening_task_popups_fit_the_720p_content_region() -> void:
	var popup_bounds := Control.new()
	popup_bounds.size = Vector2(
		1280.0 * (QuestMain.CONTENT_RIGHT - QuestMain.CONTENT_LEFT),
		720.0 * (QuestMain.CONTENT_BOTTOM - QuestMain.CONTENT_TOP),
	)
	add_child_autoqfree(popup_bounds)
	for task in GameState.quest_state.active_tasks():
		var popup := QuestTaskWindow.new()
		popup.theme = load("res://resources/fonts/shancha_ui_theme.tres")
		popup.setup(GameState.quest_state, task.instance_id)
		popup_bounds.add_child(popup)
		popup.set_drag_bounds_control(popup_bounds)
		await get_tree().process_frame
		assert_true(
			popup_bounds.get_global_rect().encloses(popup.get_global_rect()),
			"%s must fit the minimum supported content region: bounds=%s popup=%s"
			% [task.definition_id, popup_bounds.get_global_rect(), popup.get_global_rect()],
		)
		popup_bounds.remove_child(popup)
		popup.free()


func test_todo_receipt_uses_narrow_text_rows_and_fixed_page_navigation() -> void:
	var main := await _spawn_main()
	var dock := main.task_dock
	assert_false(dock.is_expanded)
	assert_false(dock.bookmark_column.visible)
	assert_false(dock.page_navigation.visible)
	assert_null(dock.get_node_or_null("TodoReceipt/TodoTaskScroll"))
	assert_eq(dock.receipt_host.size, Vector2(264, 477))
	assert_eq(dock.receipt_background.size, Vector2(264, 186))
	assert_eq(dock.receipt_host.mouse_filter, Control.MOUSE_FILTER_STOP)
	var click_in_folded_air := InputEventMouseButton.new()
	click_in_folded_air.button_index = MOUSE_BUTTON_LEFT
	click_in_folded_air.position = Vector2(100, 450)
	click_in_folded_air.pressed = true
	dock._on_receipt_gui_input(click_in_folded_air)
	assert_true(dock.is_expanded)
	assert_true(dock.bookmark_column.visible)
	assert_true(dock.page_navigation.visible)
	assert_eq(dock.receipt_host.size, Vector2(264, 477))
	assert_eq(dock.receipt_background.size, Vector2(264, 477))
	assert_eq(dock.receipt_money_label.position.y, 23.0)
	assert_eq(dock.receipt_title.position.y, 55.0)
	assert_eq(dock.bookmark_column.position.y, 100.0)
	assert_eq(dock.page_navigation.position.y, 324.0)
	assert_gt(
		dock.page_navigation.position.y,
		dock.bookmark_column.position.y + QuestTaskDock.TASKS_PER_PAGE * QuestTaskDock.TASK_LINE_HEIGHT,
	)
	assert_eq(
		dock.page_previous_button.get_theme_color("font_hover_color"),
		dock.receipt_title.get_theme_color("font_color"),
	)
	assert_eq(
		dock.page_previous_button.get_theme_color("font_disabled_color"),
		dock.receipt_title.get_theme_color("font_color"),
	)
	assert_eq(dock.page_previous_button.get_theme_font_size("font_size"), 18)
	assert_true(dock.page_previous_button.disabled)
	assert_false(dock.page_next_button.disabled)
	var task := main.state.active_tasks()[0] as TaskInstanceState
	var bookmark := dock.bookmark_buttons[task.instance_id] as Button
	assert_eq(bookmark.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_lt(bookmark.size.x, QuestTaskDock.TASK_TEXT_MAX_WIDTH)
	assert_eq(bookmark.size.y, QuestTaskDock.TASK_HIT_HEIGHT)
	assert_true(bookmark.get_theme_stylebox("normal") is StyleBoxEmpty)
	assert_true(bookmark.get_theme_stylebox("hover") is StyleBoxEmpty)
	dock._set_bookmark_hovered(bookmark, true)
	assert_eq(bookmark.get_theme_color("font_color"), QuestTaskDock.TASK_HOVER_COLOR)
	assert_gt(QuestTaskDock.TASK_HOVER_COLOR.b, QuestTaskDock.TASK_HOVER_COLOR.r)
	assert_eq(bookmark.get_theme_constant("outline_size"), 3)
	dock._set_bookmark_hovered(bookmark, false)
	assert_eq(bookmark.get_theme_color("font_color"), UiPalette.INK_COLOR)
	assert_eq(bookmark.get_theme_constant("outline_size"), 0)
	for index in 4:
		main.state.task_instances.append(TaskInstanceState.new(100 + index, &"remittance", 1))
	dock.refresh()
	assert_false(dock.page_next_button.disabled)
	var visible_bookmark_count := 0
	for button_variant in dock.bookmark_buttons.values():
		var button := button_variant as Button
		if button != null and button.visible:
			visible_bookmark_count += 1
	assert_eq(visible_bookmark_count, QuestTaskDock.TASKS_PER_PAGE)
	dock.page_next_button.pressed.emit()
	assert_eq(dock.task_page_index, 1)
	assert_false(dock.page_previous_button.disabled)
	assert_true(dock.page_next_button.disabled)
	dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	assert_true(dock.is_expanded)
	assert_true(dock.task_window.visible)
	assert_gt(main.task_popup_layer.z_index, dock.z_index)


func test_toy_unlock_enters_shop_activates_three_tasks_and_shows_restock_timer() -> void:
	var main := await _spawn_main()
	var frog := main.state.grant_item(&"tin_frog", &"test")
	main.map_screen._on_unlock_confirmed(&"toy", frog)
	await get_tree().process_frame
	assert_true(main.current_screen is QuestShopScreen)
	var shop := main.current_screen as QuestShopScreen
	assert_eq(shop.store_id, &"toy")
	assert_eq(
		(shop.get_node("StoreBackground") as TextureRect).texture.resource_path,
		"res://resources/background/toystore.png",
	)
	assert_eq(
		shop.owner_portrait.texture.resource_path,
		"res://resources/character/balloon-head.png",
	)
	assert_eq(shop.shelf_nav_button.icon.resource_path, "res://resources/ui/shell/shop-shelf.png")
	assert_eq(shop.talk_nav_button.icon.resource_path, "res://resources/ui/shell/shop-talk.png")
	assert_eq(shop.leave_nav_button.icon.resource_path, "res://resources/ui/shell/shop-back.png")
	assert_true(shop.dialogue_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert_eq(shop.dialogue_back_buffer.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_true(shop.dialogue_glass.material is ShaderMaterial)
	assert_eq(
		(shop.dialogue_glass.material as ShaderMaterial).shader.resource_path,
		"res://resources/shaders/frosted_dialogue.gdshader",
	)
	assert_null(shop.owner_name_background.material)
	assert_true(main.state.has_visited_store(&"toy"))
	assert_not_null(main.state.task_instance_for_definition(&"tin_boy_toy"))
	assert_not_null(main.state.task_instance_for_definition(&"self_care"))
	assert_not_null(main.state.task_instance_for_definition(&"girl_order"))
	assert_eq(
		shop.restock_label.text,
		TranslationServer.translate(&"opening.ui.shop.restock") % 3,
	)
	assert_not_null(main.screen_transition_overlay)
	for shelf_button in shop.shelf_buttons.values():
		assert_eq((shelf_button as Button).tooltip_text, "")


func test_fast_food_bookstore_and_record_shop_show_lowered_owner_portraits() -> void:
	var main := await _spawn_main()
	var expected_portraits := {
		&"fast_food": "res://resources/character/rat-head.png",
		&"bookstore": "res://resources/character/manga-head.png",
		&"record": "res://resources/character/phonograph-head.png",
	}
	for store_id in expected_portraits:
		main._show_shop_immediate(store_id)
		await get_tree().process_frame
		var shop := main.current_screen as QuestShopScreen
		assert_true(shop.owner_portrait.visible, store_id)
		assert_eq(shop.owner_portrait.texture.resource_path, expected_portraits[store_id])
		assert_almost_eq(shop.owner_portrait.anchor_bottom, 1.10, 0.001)
		assert_gt(
			shop.owner_portrait.get_global_rect().end.y,
			main.content_viewport_region.get_global_rect().end.y,
		)
		assert_gt(main.global_frame.z_index, shop.owner_portrait.z_index)
		if store_id in [&"bookstore", &"record"]:
			assert_false(shop.talk_nav_button.visible)
			assert_false(shop.dialogue_panel.visible)


func test_persona_first_acquisition_reveals_each_new_mask_after_arc() -> void:
	var main := await _spawn_main()
	var state := main.state
	state.protagonist_persona_counts[&"dreamwalker"] = 0
	state.protagonist_persona_counts[&"mourner"] = 0
	var frog := state.grant_item(&"tin_frog", &"test")
	assert_true(state.unlock_store(&"toy", frog).ok)
	var self_care := state.task_instance_for_definition(&"self_care")
	var kaleidoscope := state.grant_item(&"kaleidoscope", &"test")
	assert_true(state.assign_card(self_care.instance_id, &"self_care_item", kaleidoscope).ok)
	assert_true(state.confirm_task(self_care.instance_id).ok)
	assert_true(state.begin_next_day().ok)
	assert_true(state.apply_arc_effects().ok)
	assert_true(state.mark_arc_entry_shown())
	assert_true(state.finish_arc().ok)

	main._run_pending_persona_reveals()
	assert_true(main.persona_reveal_overlay.visible)
	assert_true(main.persona_reveal_back.visible)
	main._flip_persona_reveal()
	assert_true(main.persona_reveal_card.visible)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._on_persona_reveal_input(click)
	assert_true(main.persona_reveal_back.visible)
	main._flip_persona_reveal()
	main._on_persona_reveal_input(click)
	assert_false(main.persona_reveal_overlay.visible)
	assert_true(state.pending_persona_reveal_ids.is_empty())
	main.hand_bar.show_tab(QuestHandBar.TAB_MASKS)
	assert_eq(main.hand_bar.card_views.size(), main.state.inventory.size() + 4)


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
