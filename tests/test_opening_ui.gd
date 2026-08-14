extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_opening_ui_has_two_letters_no_items_and_only_three_visible_stores() -> void:
	var main := await _spawn_main()
	assert_eq(main.task_dock.bookmark_buttons.size(), 2)
	assert_true(main.hand_bar.card_views.is_empty())
	assert_eq(main.map_screen.store_hotspots.size(), 5)
	assert_true((main.map_screen.store_hotspots[&"toy"] as Button).visible)
	assert_true((main.map_screen.store_hotspots[&"fast_food"] as Button).visible)
	assert_true((main.map_screen.store_hotspots[&"flower"] as Button).visible)
	assert_false((main.map_screen.store_hotspots[&"record"] as Button).visible)
	assert_false((main.map_screen.store_hotspots[&"bookstore"] as Button).visible)
	for hotspot in main.map_screen.store_hotspots.values():
		assert_eq((hotspot as Button).tooltip_text, "")
	main.hand_bar.show_tab(QuestHandBar.TAB_MASKS)
	assert_true(main.hand_bar.card_views.is_empty())
	assert_false(main.state.select_synthesis_persona(&"clarity"))


func test_money_letter_flips_to_plus_one_hundred_and_disappears_on_close() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"remittance")
	main.task_dock._toggle_task(task.instance_id)
	var slot := main.task_dock.task_window.gift_slot
	assert_true(slot.back_button.visible)
	slot._on_back_pressed()
	await get_tree().process_frame
	assert_eq(main.state.wallet.money, 100)
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


func test_todo_receipt_stays_open_above_a_scrollable_task_list() -> void:
	var main := await _spawn_main()
	var dock := main.task_dock
	assert_false(dock.is_expanded)
	assert_false(dock.task_scroll.visible)
	dock._toggle_receipt()
	assert_true(dock.is_expanded)
	assert_true(dock.task_scroll.visible)
	assert_eq(dock.receipt_host.size, Vector2(264, 477))
	assert_almost_eq(dock.task_scroll.get_v_scroll_bar().self_modulate.a, 0.0, 0.001)
	var task := main.state.active_tasks()[0] as TaskInstanceState
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
	var dialogue_style := shop.dialogue_panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(dialogue_style)
	assert_eq(dialogue_style.texture.resource_path, "res://resources/ui/shell/shop-dialogue-toy.png")
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


func test_persona_first_acquisition_reveals_each_new_mask_after_arc() -> void:
	var main := await _spawn_main()
	var state := main.state
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
	assert_eq(main.hand_bar.card_views.size(), 2)


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
