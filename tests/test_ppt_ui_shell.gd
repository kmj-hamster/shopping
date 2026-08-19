extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.LEGACY_MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	GameState.reset_game()


func test_main_uses_the_centered_art_shell_and_unified_hand() -> void:
	var main := await _spawn_main()
	assert_eq(main.theme, QuestMain.ZH_UI_THEME)
	var ui_font := main.theme.default_font as FontVariation
	assert_not_null(ui_font)
	assert_eq(ui_font.base_font, load("res://resources/fonts/VT323-Regular.ttf"))
	assert_true(main.theme.default_font.has_char("A".unicode_at(0)))
	assert_true(main.theme.default_font.has_char("中".unicode_at(0)))
	assert_null(main.get_node_or_null("PersistentSidebar"))
	assert_not_null(main.art_canvas)
	assert_same(main.art_canvas.get_parent(), main)
	assert_same(main.content_viewport_region.get_parent(), main.art_canvas)
	assert_not_null(main.find_child("ContentViewportFrame", true, false))
	assert_same(main.task_popup_layer.get_parent(), main.content_viewport_region)
	assert_not_null(main.find_child("ContentViewport", true, false))
	assert_not_null(main.find_child("SynthesisBagButton", true, false))
	assert_eq(
		main.protagonist_button.texture_normal.resource_path,
		"res://resources/character/bag-head.png",
	)
	assert_eq(
		main.protagonist_button.texture_hover.resource_path,
		"res://resources/character/bag-light.png",
	)
	assert_almost_eq(
		main.protagonist_button.anchor_left, QuestMain.PROTAGONIST_ANCHOR_LEFT, 0.001
	)
	assert_almost_eq(
		main.protagonist_button.anchor_top, QuestMain.PROTAGONIST_ANCHOR_TOP, 0.001
	)
	assert_almost_eq(
		main.protagonist_button.anchor_right, QuestMain.PROTAGONIST_ANCHOR_RIGHT, 0.001
	)
	assert_almost_eq(
		main.protagonist_button.anchor_bottom,
		QuestMain.PROTAGONIST_ANCHOR_BOTTOM,
		0.001,
	)
	assert_almost_eq(
		main.protagonist_button.anchor_right - main.protagonist_button.anchor_left,
		(1.025 - 0.78) * 0.8,
		0.001,
	)
	assert_almost_eq(
		main.protagonist_button.anchor_bottom - main.protagonist_button.anchor_top,
		(1.08 - 0.60) * 0.8,
		0.001,
	)
	assert_not_null(main.protagonist_button.texture_click_mask)
	var bag_click_mask := main.protagonist_button.texture_click_mask
	var bag_mask_size := bag_click_mask.get_size()
	assert_false(bag_click_mask.get_bit(0, int(bag_mask_size.y / 2)))
	assert_true(bag_click_mask.get_bit(
		int(bag_mask_size.x / 2), int(bag_mask_size.y / 2)
	))
	assert_eq(main.protagonist_button.tooltip_text, "")
	assert_gt(
		main.protagonist_button.get_global_rect().end.y,
		main.art_canvas.get_global_rect().end.y,
	)
	assert_null(main.money_label)
	assert_null(main.day_label)
	assert_not_null(main.next_day_button)
	assert_not_null(main.find_child("LanguageButton", true, false))
	assert_not_null(main.find_child("ClearSaveButton", true, false))
	assert_not_null(main.get_node_or_null("DebugButtonRow"))
	assert_eq(main.language_button.get_parent(), main.debug_button_row)
	assert_eq(main.clear_save_button.get_parent(), main.debug_button_row)
	assert_eq(main.next_day_button.get_parent(), main.debug_button_row)
	assert_eq(main.synthesis_background_button.get_parent(), main.debug_button_row)
	assert_eq(main.next_day_button.custom_minimum_size.x, 64.0)
	assert_eq(main.synthesis_background_button.custom_minimum_size.x, 78.0)
	assert_eq(main.next_day_button.get_theme_font_size("font_size"), 11)
	assert_lt(main.debug_button_row.anchor_left, 0.02)
	assert_gt(main.debug_button_row.anchor_top, 0.90)
	assert_gt(main.debug_button_row.anchor_bottom, 0.98)
	assert_true(main.clear_save_button.pressed.is_connected(
		Callable(main, "_on_clear_save_pressed")
	))
	assert_true(main.next_day_button.pressed.is_connected(
		Callable(main, "_on_next_day_pressed")
	))
	assert_true(main.synthesis_background_button.pressed.is_connected(
		Callable(main, "_on_synthesis_background_pressed")
	))
	assert_not_null(main.forbidden_cursor_texture)
	assert_eq(main.global_frame.texture.resource_path, QuestMain.FRAME_TEXTURE_PATHS[&"map"])
	assert_eq(main.global_shadow.texture.resource_path, "res://resources/ui/shell/shadow-global.png")
	assert_eq(main.global_shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_gt(main.task_popup_layer.z_index, main.global_shadow.z_index)
	assert_almost_eq(main.content_viewport_region.anchor_left, QuestMain.CONTENT_LEFT, 0.001)
	assert_almost_eq(main.content_viewport_region.anchor_top, QuestMain.CONTENT_TOP, 0.001)
	assert_almost_eq(main.content_viewport_region.anchor_right, QuestMain.CONTENT_RIGHT, 0.001)
	assert_almost_eq(main.content_viewport_region.anchor_bottom, QuestMain.CONTENT_BOTTOM, 0.001)
	assert_false(main.content_viewport_region.clip_contents)
	assert_false(main.screen_host.clip_contents)
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq(main.hand_bar.offset_top, QuestMain.HAND_VERTICAL_OFFSET)
	assert_eq(main.hand_bar.offset_bottom, QuestMain.HAND_VERTICAL_OFFSET)
	var first_hand_card := main.hand_bar.card_views.values()[0] as CardHandCard
	assert_almost_eq(
		first_hand_card.get_global_rect().end.y,
		main.art_canvas.get_global_rect().end.y,
		1.0,
	)
	var map_background := main.current_screen.get_node("MapBackground") as TextureRect
	_assert_background_overscans_frame(map_background)
	assert_eq((main.current_screen as QuestMapScreen).store_hotspots.size(), 2)
	assert_eq(main.task_dock.bookmark_column.get_child_count(), 4)
	assert_eq(
		main.task_dock.receipt_day_label.get_theme_color("font_color"),
		QuestTaskDock.NIGHT_VALUE_COLOR,
	)
	assert_eq(
		main.task_dock.receipt_day_label.text,
		str(main.state.day),
	)
	assert_eq(
		main.task_dock.receipt_money_label.text,
		str(main.state.wallet.money),
	)
	assert_eq(
		main.task_dock.receipt_money_label.horizontal_alignment,
		HORIZONTAL_ALIGNMENT_CENTER,
	)
	assert_eq(
		main.task_dock.receipt_background.texture.resource_path,
		QuestTaskDock.TODO_COLLAPSED_PATH,
	)
	assert_false(main.task_dock.is_expanded)
	assert_false(main.task_dock.bookmark_column.visible)
	assert_false(main.task_dock.page_navigation.visible)
	assert_null(main.task_dock.find_child("TodoTaskScroll", true, false))
	for bookmark in main.task_dock.bookmark_column.get_children():
		var bookmark_button := bookmark as Button
		assert_eq(bookmark_button.tooltip_text, "")
		assert_true(bookmark_button.clip_text)
		assert_eq(bookmark_button.get_theme_font_size("font_size"), 11)
		assert_eq(bookmark_button.get_theme_color("font_color"), UiPalette.INK_COLOR)
		assert_true(bookmark_button.get_theme_stylebox("normal") is StyleBoxEmpty)
		assert_lt(bookmark_button.size.y, QuestTaskDock.TASK_LINE_HEIGHT)
	assert_eq(main.hand_bar.card_views.size(), 10)
	var fries_card := main.hand_bar.card_views.values()[0] as CardHandCard
	assert_eq(fries_card.definition.id, &"fries")
	assert_eq(fries_card.title_label.get_theme_color("font_color"), UiPalette.INK_COLOR)
	assert_not_null(fries_card.item_image.texture)
	assert_eq(fries_card.custom_minimum_size, CardHandCard.CARD_SIZE)


func test_english_locale_uses_baker_signet_with_six_percent_tracking_live() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window

	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	await get_tree().process_frame
	assert_eq(main.theme, QuestMain.EN_UI_THEME)
	assert_eq(main.task_dock.receipt_money_label.text, str(main.state.wallet.money))
	var theme_font := main.theme.default_font as FontVariation
	assert_not_null(theme_font)
	assert_eq(theme_font.base_font.resource_path, "res://resources/fonts/baker-signet-bt.ttf")
	var title_font := popup.title_label.get_theme_font("font") as FontVariation
	assert_not_null(title_font)
	assert_eq(title_font.base_font.resource_path, "res://resources/fonts/baker-signet-bt.ttf")
	assert_eq(
		title_font.spacing_glyph,
		maxi(1, roundi(
			popup.title_label.get_theme_font_size("font_size")
			* QuestMain.ENGLISH_TRACKING_RATIO
		)),
	)

	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	await get_tree().process_frame
	assert_eq(main.theme, QuestMain.ZH_UI_THEME)
	assert_false(popup.title_label.has_theme_font_override("font"))


func test_dynamic_pure_black_text_is_replaced_with_night_ink() -> void:
	var main := await _spawn_main()
	var label := Label.new()
	label.text = "Ink"
	label.add_theme_color_override("font_color", Color.BLACK)
	main.add_child(label)
	await get_tree().process_frame
	assert_eq(label.get_theme_color("font_color"), UiPalette.INK_COLOR)


func test_flower_shop_starts_as_scene_and_opens_shelf_on_request() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	assert_not_null(shop)
	_assert_background_overscans_frame(shop.get_node("StoreBackground") as TextureRect)
	assert_false(shop.shelf_popup.visible)
	assert_not_null(shop.get_node_or_null("StoreOwnerPortrait"))
	assert_not_null(shop.find_child("ShelfButton", true, false))
	assert_not_null(shop.find_child("TalkButton", true, false))
	assert_not_null(shop.find_child("LeaveButton", true, false))
	assert_null(shop.title_label)
	assert_lt(shop.shelf_popup.anchor_right, shop.owner_portrait.anchor_left)
	assert_lte(shop.shelf_popup.anchor_bottom, shop.dialogue_panel.anchor_top)
	assert_almost_eq(shop.shelf_popup.anchor_left, 0.18, 0.001)
	assert_almost_eq(shop.shelf_popup.anchor_right, 0.475, 0.001)
	assert_gt(
		shop.shelf_popup.get_global_rect().position.x,
		main.task_dock.receipt_host.get_global_rect().end.x + 16.0,
	)
	assert_lt(shop.owner_portrait.anchor_right, shop.navigation_column.anchor_left)
	assert_almost_eq(shop.owner_portrait.anchor_left, 0.595, 0.001)
	assert_almost_eq(shop.owner_portrait.anchor_top, 0.18, 0.001)
	assert_almost_eq(shop.owner_portrait.anchor_bottom, 1.035, 0.001)
	assert_gt(main.global_frame.z_index, shop.owner_portrait.z_index)
	assert_eq(shop.shelf_nav_button.custom_minimum_size, Vector2(82, 38))
	assert_almost_eq(shop.owner_name_label.anchor_left, 0.10, 0.001)
	assert_almost_eq(shop.owner_dialogue_label.anchor_left, 0.055, 0.001)
	assert_true(shop.dialogue_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert_almost_eq(shop.dialogue_glass.anchor_top, 0.20, 0.001)
	assert_eq(shop.dialogue_glass.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(
		shop.owner_dialogue_label.get_theme_color("font_color"),
		QuestShopScreen.DIALOGUE_TEXT_COLOR,
	)
	assert_eq(
		shop.owner_name_label.get_theme_color("font_color"),
		QuestShopScreen.DIALOGUE_TEXT_COLOR,
	)
	assert_eq(shop.owner_dialogue_voice_players.size(), 3)
	assert_eq(shop.owner_dialogue_label.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_true(shop.shelf_popup.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert_eq(shop.shelf_back_buffer.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_true(shop.shelf_glass.material is ShaderMaterial)
	assert_eq(
		(shop.shelf_glass.material as ShaderMaterial).shader.resource_path,
		"res://resources/shaders/frosted_dialogue.gdshader",
	)
	assert_eq(shop.shelf_grid.columns, 3)
	assert_null(shop.find_child("ShelfPage1", true, false))
	shop._toggle_shelf_popup()
	assert_true(shop.shelf_popup.visible)
	assert_true(shop.shelf_back_buffer.visible)
	assert_eq(shop.shelf_buttons.size(), 6)
	assert_eq(shop.shelf_views.size(), 6)
	assert_true(shop.shelf_views[0].card is CardHandCard)
	assert_true((shop.shelf_views[0].card as CardHandCard).visible)
	assert_false((shop.shelf_views[2].card as CardHandCard).visible)


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


func test_shop_dialogue_uses_fixed_two_line_pages() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var panel_height := shop.dialogue_panel.size.y
	shop.owner_dialogue_char_seconds = 10.0
	shop._present_owner_dialogue(
		"这是一段用于验证店主对白固定为两行并在内容过长时等待玩家点击后翻页的长文本。".repeat(5),
		true,
	)
	assert_eq(
		shop.owner_dialogue_label.max_lines_visible,
		QuestShopScreen.DIALOGUE_MAX_VISIBLE_LINES,
	)
	assert_true(shop.dialogue_panel.clip_contents)
	assert_gt(shop.owner_dialogue_pages.size(), 1)
	assert_lte(
		shop.owner_dialogue_label.get_line_count(),
		QuestShopScreen.DIALOGUE_MAX_VISIBLE_LINES,
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	shop._on_dialogue_panel_gui_input(click)
	assert_false(shop.owner_dialogue_is_typing)
	assert_eq(shop.owner_dialogue_page_index, 0)
	shop._on_dialogue_panel_gui_input(click)
	assert_true(shop.owner_dialogue_is_typing)
	assert_eq(shop.owner_dialogue_page_index, 1)
	assert_eq(shop.owner_dialogue_label.text, shop.owner_dialogue_pages[1])
	assert_lte(
		shop.owner_dialogue_label.get_line_count(),
		QuestShopScreen.DIALOGUE_MAX_VISIBLE_LINES,
	)
	assert_almost_eq(shop.dialogue_panel.size.y, panel_height, 0.01)


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


func test_shop_reuses_six_fixed_shelf_views_when_content_refreshes() -> void:
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
	shop._refresh_owner_dialogue(true)
	assert_eq(shop.shelf_grid.get_child_count(), CardShopTransaction.PAGE_SIZE)
	for view_index in shop.shelf_views.size():
		assert_same(shop.shelf_views[view_index].root, roots[view_index])
		assert_same(shop.shelf_views[view_index].button, buttons[view_index])
	transaction.shelf_slots[0].clear()
	shop._refresh_shelf()
	assert_eq(shop.shelf_grid.get_child_count(), CardShopTransaction.PAGE_SIZE)
	assert_false((shop.shelf_views[0].card as CardHandCard).visible)
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
	assert_true(transaction.has_selection())
	assert_true(shop.checkout_button.visible)
	assert_false(shop.owner_dialogue_override_key.is_empty())
	shop.leave_requested.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestMapScreen)
	assert_false(transaction.has_selection())


func test_checkout_closes_the_top_right_popup() -> void:
	var main := await _spawn_main()
	main.state.wallet.money = 30
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	shop._on_shelf_pressed(transaction.shelf_slots[0].slot_id)
	assert_true(main.detail_popup.visible)
	shop._on_checkout_pressed()
	assert_false(main.detail_popup.visible)
	assert_false(main.rule_detail_popup.visible)


func test_opening_synthesis_clears_shop_checkout_and_comment_before_returning_to_map() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := main.state.transaction_for_store(&"flower")
	shop._on_shelf_pressed(transaction.shelf_slots[0].slot_id)
	assert_true(transaction.has_selection())
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestSynthesisInterface)
	assert_false(transaction.has_selection())
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestMapScreen)
	var previous_shop := main.shop_screens[&"flower"] as QuestShopScreen
	assert_false(previous_shop.checkout_button.visible)
	assert_true(previous_shop.owner_dialogue_override_key.is_empty())
	assert_true(previous_shop.owner_dialogue_item_name.is_empty())


func test_locked_location_uses_confirmed_popup_then_enters_shop() -> void:
	var main := await _spawn_main()
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	assert_not_null(map.location_popup)
	assert_true(map.location_popup is PaperActivityPopup)
	assert_same(map.location_popup.drag_bounds_control, map)
	assert_almost_eq(map.location_popup.anchor_left, PaperActivityPopup.PAPER_ANCHOR_LEFT, 0.001)
	assert_almost_eq(map.location_popup.anchor_right, PaperActivityPopup.PAPER_ANCHOR_RIGHT, 0.001)
	assert_almost_eq(map.location_popup.anchor_top, PaperActivityPopup.PAPER_ANCHOR_TOP, 0.001)
	assert_almost_eq(map.location_popup.anchor_bottom, PaperActivityPopup.PAPER_ANCHOR_BOTTOM, 0.001)
	assert_almost_eq(
		map.location_popup.position.y,
		map.size.y * PaperActivityPopup.PAPER_ANCHOR_TOP,
		0.5,
	)
	assert_almost_eq(
		map.location_popup.size.y,
		maxf(
			map.size.y * (
				PaperActivityPopup.PAPER_ANCHOR_BOTTOM - PaperActivityPopup.PAPER_ANCHOR_TOP
			),
			map.location_popup.get_combined_minimum_size().y,
		),
		0.5,
	)
	assert_lte(map.location_popup.size.y, map.size.y * 0.65)
	assert_eq(
		map.location_popup.title_label.horizontal_alignment,
		HORIZONTAL_ALIGNMENT_LEFT,
	)
	assert_eq(
		map.location_popup.body_label.horizontal_alignment,
		HORIZONTAL_ALIGNMENT_LEFT,
	)
	assert_eq(map.location_popup.slots_row.alignment, BoxContainer.ALIGNMENT_CENTER)
	assert_eq(map.location_popup.slots_row.get_child_count(), 1)
	assert_true(map.location_popup.action_button.disabled)
	assert_eq(map.location_popup.feedback_label.text, "")
	assert_not_null(map.location_popup.action_button.get_theme_stylebox("disabled"))
	assert_eq(
		map.location_popup.slot_prompt_label.text,
		TranslationServer.translate(map.location_popup.unlock_definition.slot_rule.display_name_key),
	)
	assert_eq(
		map.location_popup.slots_row.size_flags_vertical,
		Control.SIZE_SHRINK_CENTER,
	)
	assert_null(main.focused_rule)
	assert_false(main.rule_detail_popup.visible)
	var hand_order_before: Array[int] = []
	for child in main.hand_bar.card_row.get_children():
		if child is Control and child.get_child_count() > 0:
			var view := child.get_child(0) as CardHandCard
			if view != null:
				hand_order_before.append(view.card.instance_id)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map.location_popup.unlock_slot._on_gui_input(click)
	assert_same(main.focused_rule, map.location_popup.unlock_definition.slot_rule)
	assert_true(main.rule_detail_popup.visible)
	assert_eq(main.rule_detail_popup.required_row.get_child_count(), 1)
	var jasmine_view := main.hand_bar.card_views[jasmine.instance_id] as CardHandCard
	assert_true(jasmine_view.rule_match_highlighted)
	assert_almost_eq(jasmine_view.position.y, -QuestHandBar.RULE_MATCH_LIFT, 0.01)
	var hand_order_after: Array[int] = []
	for child in main.hand_bar.card_row.get_children():
		if child is Control and child.get_child_count() > 0:
			var view := child.get_child(0) as CardHandCard
			if view != null:
				hand_order_after.append(view.card.instance_id)
	assert_eq(hand_order_after, hand_order_before)
	assert_true(main.task_dock.task_window == null or main.task_dock.task_window is PaperActivityPopup)
	var preallocated_card_view := map.location_popup.unlock_slot.card_view
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": jasmine},
	)
	assert_same(map.location_popup.unlock_slot.card_view, preallocated_card_view)
	assert_true(preallocated_card_view.visible)
	assert_eq(map.location_popup.unlock_slot.size, QuestTaskSlot.CARD_SIZE)
	assert_null(map.location_popup.unlock_slot.find_child("RemoveStagedCardButton"))
	assert_false(main.hand_bar.card_views.has(jasmine.instance_id))
	assert_false(map.location_popup.action_button.disabled)
	assert_eq(map.location_popup.feedback_label.text, "")
	map.location_popup._on_action_pressed()
	await get_tree().process_frame
	assert_true(main.state.is_store_unlocked(&"record"))
	assert_false(main.state.inventory.has(jasmine))
	assert_true(main.current_screen is QuestShopScreen)
	assert_eq((main.current_screen as QuestShopScreen).store_id, &"record")
	assert_false(main.rule_detail_popup.visible)


func test_task_rule_panel_shows_written_bonus_only() -> void:
	var main := await _spawn_main()
	var girl_task := main.state.active_tasks().filter(
		func(task: TaskInstanceState) -> bool: return task.definition_id == &"girl_order"
	)[0] as TaskInstanceState
	var definition := QuestArcCatalog.task_by_id(girl_task.definition_id)
	main._show_item(QuestArcCatalog.item_by_id(&"jasmine"))
	assert_true(main.detail_popup.visible)
	main._on_rule_focused(definition.slot_rules[0])
	assert_true(main.rule_detail_popup.visible)
	assert_false(main.detail_popup.visible)
	assert_eq(main.rule_detail_popup.panel.offset_left, ItemDetailPopup.DETAIL_LEFT)
	assert_eq(main.rule_detail_popup.panel.offset_top, ItemDetailPopup.DETAIL_TOP)
	assert_eq(main.rule_detail_popup.panel.offset_right, ItemDetailPopup.DETAIL_RIGHT)
	assert_eq(main.rule_detail_popup.panel.offset_bottom, ItemDetailPopup.DETAIL_BOTTOM)
	assert_eq(ItemDetailPopup.DETAIL_LEFT, -680.0)
	assert_eq(
		main.rule_detail_popup.property_description.get_theme_font_size("font_size"),
		ItemDetailPopup.DESCRIPTION_FONT_SIZE,
	)
	assert_eq(
		main.rule_detail_popup.panel.scale,
		Vector2.ONE * ItemDetailPopup.RIGHT_POPUP_SCALE,
	)
	assert_almost_eq(
		main.rule_detail_popup.panel.pivot_offset.x,
		main.rule_detail_popup.panel.size.x,
		0.01,
	)
	assert_eq(
		main.rule_detail_popup.property_panel.scale,
		Vector2.ONE * ItemDetailPopup.RIGHT_POPUP_SCALE,
	)
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
	var required_copy := required_chip.get_child(1) as Label
	assert_not_null(required_icon)
	assert_eq(required_icon.custom_minimum_size.x, required_icon.custom_minimum_size.y)
	assert_almost_eq(
		required_icon.custom_minimum_size.x,
		float(QuestRuleDetailPopup.RULE_LINE_HEIGHT),
		0.01,
	)
	assert_eq(
		required_copy.text,
		TranslationServer.translate(&"demo.ui.rule.must"),
	)
	assert_eq(
		required_copy.get_theme_font_size("font_size"),
		QuestRuleDetailPopup.RULE_CONDITION_FONT_SIZE,
	)
	assert_true(required_icon.get_child(0) is TextureRect)
	assert_eq(
		(required_icon.get_child(0) as TextureRect).texture,
		load("res://resources/ui/property-food.png"),
	)
	var bonus_chip := main.rule_detail_popup.bonus_row.get_child(0) as HBoxContainer
	var bonus_icon := bonus_chip.get_child(0) as Button
	var bonus_copy := bonus_chip.get_child(1) as Label
	assert_true(bonus_icon.get_child(0) is TextureRect)
	assert_eq(
		bonus_copy.text,
		TranslationServer.translate(&"demo.ui.rule.bonus"),
	)
	assert_eq(
		bonus_copy.get_theme_font_size("font_size"),
		QuestRuleDetailPopup.RULE_CONDITION_FONT_SIZE,
	)
	assert_eq(
		(bonus_reward_view as Label).get_theme_font_size("font_size"),
		QuestRuleDetailPopup.RULE_CONDITION_FONT_SIZE,
	)
	assert_null(main.rule_detail_popup.find_child("RequiredHeading", true, false))
	assert_null(main.rule_detail_popup.find_child("BonusHeading", true, false))
	assert_eq(
		(bonus_icon.get_child(0) as TextureRect).texture,
		load("res://resources/ui/property-salty.png"),
	)
	main.rule_detail_popup._show_property(&"food")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.rule_detail_popup.property_panel.visible)
	assert_not_null(main.rule_detail_popup.property_icon_image.texture)
	var first_rule_property_font_size := (
		main.rule_detail_popup.property_description.get_theme_font_size("font_size")
	)
	assert_eq(first_rule_property_font_size, ItemDetailPopup.DESCRIPTION_FONT_SIZE)
	assert_eq(
		main.rule_detail_popup.property_name.get_theme_font_size("font_size"),
		ItemDetailPopup.TITLE_FONT_SIZE,
	)
	var rule_property_icon_frame := (
		main.rule_detail_popup.property_icon_image.get_parent().get_parent()
		as PanelContainer
	)
	assert_eq(rule_property_icon_frame.custom_minimum_size, Vector2(82, 82))
	assert_eq(rule_property_icon_frame.custom_minimum_size.x, rule_property_icon_frame.custom_minimum_size.y)
	main.rule_detail_popup._show_property(&"food")
	assert_false(main.rule_detail_popup.property_panel.visible)
	main.rule_detail_popup._show_property(&"food")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		main.rule_detail_popup.property_description.get_theme_font_size("font_size"),
		first_rule_property_font_size,
	)
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
	main._show_item(QuestArcCatalog.item_by_id(&"jasmine"))
	assert_true(main.detail_popup.visible)
	assert_false(main.rule_detail_popup.visible)


func test_task_popup_uses_horizontal_letter_and_slot_columns() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	assert_not_null(popup)
	assert_same(popup.get_parent(), main.task_popup_layer)
	assert_same(popup.drag_bounds_control, main.task_popup_layer)
	assert_almost_eq(popup.anchor_left, PaperActivityPopup.PAPER_ANCHOR_LEFT, 0.001)
	assert_almost_eq(popup.anchor_right, PaperActivityPopup.PAPER_ANCHOR_RIGHT, 0.001)
	assert_almost_eq(popup.anchor_top, PaperActivityPopup.PAPER_ANCHOR_TOP, 0.001)
	assert_almost_eq(popup.anchor_bottom, PaperActivityPopup.PAPER_ANCHOR_BOTTOM, 0.001)
	assert_almost_eq(
		popup.position.y,
		main.task_popup_layer.size.y * PaperActivityPopup.PAPER_ANCHOR_TOP,
		0.5,
	)
	var anchored_height := main.task_popup_layer.size.y * (
		PaperActivityPopup.PAPER_ANCHOR_BOTTOM - PaperActivityPopup.PAPER_ANCHOR_TOP
	)
	assert_almost_eq(popup.size.y, anchored_height, 0.1)
	assert_lte(popup.size.y, main.task_popup_layer.size.y)
	assert_eq(
		popup.paper_background.texture.resource_path,
		"res://resources/ui/quest/task-paper.png",
	)
	assert_eq(
		popup.close_button.texture_normal.resource_path,
		"res://resources/ui/quest/task-close.png",
	)
	assert_eq(popup.title_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(popup.body_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(popup.body_label.vertical_alignment, VERTICAL_ALIGNMENT_TOP)
	assert_same(popup.letter_panel.get_parent(), popup.content_row)
	assert_true(popup.letter_panel.is_ancestor_of(popup.text_column))
	assert_same(popup.interaction_column.get_parent(), popup.content_row)
	assert_lt(popup.letter_panel.global_position.x, popup.interaction_column.global_position.x)
	assert_same(popup.body_viewport.get_parent(), popup.text_column)
	assert_same(popup.slots_row.get_parent(), popup.interaction_column)
	assert_eq(popup.body_margin.get_theme_constant("margin_left"), 0)
	assert_eq(popup.body_margin.get_theme_constant("margin_right"), 0)
	assert_true(popup.body_viewport.clip_contents)
	assert_same(popup.body_page_row.get_parent(), popup.content_row)
	assert_null(popup.get_node_or_null("BodyPageLabel"))
	assert_eq(popup.body_page_spacer.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_almost_eq(
		popup.body_viewport.custom_minimum_size.y,
		PaperActivityPopup.BODY_HEIGHT,
		0.01,
	)
	assert_eq(popup.lower_spacer.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_eq(popup.slots_row.alignment, BoxContainer.ALIGNMENT_CENTER)
	assert_eq(popup.slots_row.size_flags_vertical, Control.SIZE_SHRINK_CENTER)
	assert_eq(popup.slots_row.get_child_count(), 1)
	assert_true(popup.action_button.disabled)
	assert_same(popup.action_button.get_parent(), popup.interaction_footer_row)
	assert_almost_eq(
		popup.action_button.get_global_rect().get_center().x,
		popup.slots_row.get_global_rect().get_center().x,
		0.5,
	)
	assert_gte(
		popup.action_button.get_global_rect().position.y,
		popup.slots_row.get_global_rect().end.y,
	)
	var slot := popup.slot_views.values()[0] as QuestTaskSlot
	_assert_slot_contains_no_instruction_copy(slot)
	var fries := main.state.inventory[0] as CardItemState
	var hand_card_size := (main.hand_bar.card_views[fries.instance_id] as CardHandCard).size
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	assert_true(main.state.assign_card(task.instance_id, definition.slot_rules[0].id, fries).ok)
	popup.refresh()
	await get_tree().process_frame
	var filled_slot := popup.slot_views.values()[0] as QuestTaskSlot
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
	assert_eq(popup.action_button.text, "")
	assert_eq(
		popup.action_button.icon.resource_path,
		"res://resources/ui/quest/task-confirm.png",
	)
	popup._on_action_pressed()
	assert_true(task.confirmed)
	assert_true(popup.action_button.disabled)
	assert_eq(
		popup.action_button.icon.resource_path,
		"res://resources/ui/quest/task-completed.png",
	)
	assert_eq(popup.feedback_label.text, "")


func test_shared_paper_popup_pages_long_body_without_growing_the_window() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var initial_height := popup.size.y
	var long_copy := ""
	for index in 40:
		long_copy += "This is page copy %d. " % index
	popup.set_body_copy(long_copy, PaperActivityPopup.BODY_HEIGHT, 4)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(popup.body_pages.size(), 1)
	assert_eq(popup.body_page_index, 0)
	assert_true(popup.body_previous_button.disabled)
	assert_false(popup.body_next_button.disabled)
	var first_page := popup.body_label.text
	popup._on_next_body_page_pressed()
	assert_eq(popup.body_page_index, 1)
	assert_ne(popup.body_label.text, first_page)
	assert_false(popup.body_previous_button.disabled)
	assert_almost_eq(popup.size.y, initial_height, 0.5)


func _assert_background_overscans_frame(background: TextureRect) -> void:
	assert_not_null(background)
	assert_almost_eq(background.offset_left, -QuestMain.BACKGROUND_OVERSCAN, 0.01)
	assert_almost_eq(background.offset_top, -QuestMain.BACKGROUND_OVERSCAN, 0.01)
	assert_almost_eq(background.offset_right, QuestMain.BACKGROUND_OVERSCAN, 0.01)
	assert_almost_eq(background.offset_bottom, QuestMain.BACKGROUND_OVERSCAN, 0.01)


func test_task_popup_drags_from_paper_and_stays_inside_content_viewport() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var start := popup.position
	var grab_point := popup.body_viewport.get_global_rect().get_center()
	popup._begin_dragging_at(grab_point)
	assert_true(popup.dragging)

	var first_delta := Vector2(48, 24)
	popup._move_to_canvas_position(grab_point + first_delta)
	assert_almost_eq(popup.position.x, start.x + first_delta.x, 0.5)
	assert_almost_eq(popup.position.y, start.y + first_delta.y, 0.5)
	popup._stop_dragging()
	assert_false(popup.dragging)

	grab_point = popup.body_viewport.get_global_rect().get_center()
	popup._begin_dragging_at(grab_point)
	popup._move_to_canvas_position(grab_point + Vector2(10_000, 10_000))
	var maximum := main.task_popup_layer.size - popup.size
	assert_almost_eq(popup.position.x, maximum.x, 0.5)
	assert_almost_eq(popup.position.y, maximum.y, 0.5)
	popup._stop_dragging()

	grab_point = popup.body_viewport.get_global_rect().get_center()
	popup._begin_dragging_at(grab_point)
	popup._move_to_canvas_position(grab_point - Vector2(10_000, 10_000))
	assert_almost_eq(popup.position.x, 0.0, 0.5)
	assert_almost_eq(popup.position.y, 0.0, 0.5)
	popup._stop_dragging()
	assert_false(popup.dragging)
	assert_true(main.task_popup_layer.get_global_rect().encloses(popup.get_global_rect()))


func test_task_popup_can_drag_again_after_assignment_refresh() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var grab_point := popup.body_viewport.get_global_rect().get_center()
	popup._begin_dragging_at(grab_point)
	popup._move_to_canvas_position(grab_point + Vector2(42, 0))
	popup._stop_dragging()
	assert_false(popup.dragging)

	var fries := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"fries"
	)[0] as CardItemState
	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	await get_tree().process_frame
	assert_same(main.task_dock.task_window, popup)
	var after_refresh := popup.position
	grab_point = popup.body_viewport.get_global_rect().get_center()
	popup._begin_dragging_at(grab_point)
	assert_true(popup.dragging)
	popup._move_to_canvas_position(grab_point + Vector2(36, 0))
	popup._stop_dragging()
	assert_false(popup.dragging)
	assert_almost_eq(popup.position.x, after_refresh.x + 36.0, 0.5)


func test_task_popup_interactive_slot_does_not_start_window_drag() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var slot := popup.slot_views[&"food"] as QuestTaskSlot
	var start := popup.position
	assert_eq(popup.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(popup.drag_handle.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(popup.body_viewport.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(slot.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(popup.action_button.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(popup.gui_input.is_connected(popup._on_popup_gui_input))
	slot._on_gui_input(InputEventMouseButton.new())
	assert_false(popup.dragging)
	assert_eq(popup.position, start)


func test_clicking_task_slot_highlights_and_lifts_without_reordering() -> void:
	var main := await _spawn_main()
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	main.state.reorder_hand_card(jasmine, 0)
	await get_tree().process_frame
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	var slot := popup.slot_views.values()[0] as QuestTaskSlot
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var order_before: Array[int] = []
	for child in main.hand_bar.card_row.get_children():
		if child is Control and child.get_child_count() > 0:
			var view := child.get_child(0) as CardHandCard
			if view != null:
				order_before.append(view.card.instance_id)
	slot._on_gui_input(click)
	var order_after: Array[int] = []
	for child in main.hand_bar.card_row.get_children():
		if child is Control and child.get_child_count() > 0:
			var view := child.get_child(0) as CardHandCard
			if view != null:
				order_after.append(view.card.instance_id)
	assert_eq(order_after, order_before)
	var left_wrapper := main.hand_bar.card_row.get_child(0) as Control
	var left_card := left_wrapper.get_child(0) as CardHandCard
	assert_eq(left_card.definition.id, &"jasmine")
	assert_false(left_card.rule_match_highlighted)
	var fries := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"fries"
	)[0] as CardItemState
	var fries_view := main.hand_bar.card_views[fries.instance_id] as CardHandCard
	assert_true(fries_view.rule_match_highlighted)
	assert_almost_eq(fries_view.position.y, -QuestHandBar.RULE_MATCH_LIFT, 0.01)
	var jasmine_view := main.hand_bar.card_views[jasmine.instance_id] as CardHandCard
	assert_false(jasmine_view.rule_match_highlighted)
	assert_almost_eq(jasmine_view.position.y, 0.0, 0.01)
	main._on_rule_focused(null)
	left_wrapper = main.hand_bar.card_row.get_child(0) as Control
	left_card = left_wrapper.get_child(0) as CardHandCard
	assert_eq(left_card.definition.id, &"jasmine")
	assert_almost_eq(left_card.position.y, 0.0, 0.01)
	assert_almost_eq(fries_view.position.y, 0.0, 0.01)


func test_task_and_location_popups_close_on_background_click() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	main.task_dock._toggle_task(task.instance_id)
	await get_tree().process_frame
	var task_popup := main.task_dock.task_window
	var background_click := InputEventMouseButton.new()
	background_click.button_index = MOUSE_BUTTON_LEFT
	background_click.pressed = true
	background_click.position = Vector2(1.0, 1.0)
	assert_false(task_popup.get_global_rect().has_point(background_click.position))
	var map := main.current_screen as QuestMapScreen
	map.background_input.gui_input.emit(background_click)
	assert_null(main.task_dock.task_window)

	map._on_store_pressed(&"record")
	await get_tree().process_frame
	var location_popup := map.location_popup
	assert_false(location_popup.get_global_rect().has_point(background_click.position))
	map.background_input.gui_input.emit(background_click)
	assert_null(map.location_popup)


func test_blank_background_closes_top_right_details_in_every_primary_screen() -> void:
	var main := await _spawn_main()
	var definition := QuestArcCatalog.item_by_id(&"fries")
	var background_click := InputEventMouseButton.new()
	background_click.button_index = MOUSE_BUTTON_LEFT
	background_click.pressed = true
	background_click.position = Vector2(1.0, 1.0)

	main._show_item(definition)
	assert_true(main.detail_popup.visible)
	var map := main.current_screen as QuestMapScreen
	map.background_input.gui_input.emit(background_click)
	assert_false(main.detail_popup.visible)

	main._show_shop_immediate(&"toy")
	main._show_item(definition)
	assert_true(main.detail_popup.visible)
	var shop := main.current_screen as QuestShopScreen
	shop.background_input.gui_input.emit(background_click)
	assert_false(main.detail_popup.visible)

	main._show_synthesis_immediate()
	main._show_item(definition)
	assert_true(main.detail_popup.visible)
	var synthesis := main.current_screen as QuestSynthesisInterface
	synthesis.background_input.gui_input.emit(background_click)
	assert_false(main.detail_popup.visible)


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
	var replacement := main.state.grant_item(&"fries", &"test")
	var replacement_data := {"kind": &"card_item", "card": replacement}
	assert_true(slot._can_drop_data(Vector2.ZERO, replacement_data))
	slot._drop_data(Vector2.ZERO, replacement_data)
	assert_same(slot.card_view, preallocated_card_view)
	assert_same(slot.card_view.card, replacement)
	assert_eq(fries.location, CardItemState.Location.HAND)
	assert_true(main.hand_bar.card_views.has(fries.instance_id))
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


func test_self_and_owner_tasks_use_deferred_actions_and_owner_rule_titles() -> void:
	var main := await _spawn_main()
	var self_task := main.state.task_instance_for_definition(&"self_care")
	main.task_dock._toggle_task(self_task.instance_id)
	await get_tree().process_frame
	assert_eq(
		main.task_dock.task_window.action_button.icon.resource_path,
		"res://resources/ui/quest/task-confirm.png",
	)
	main.task_dock._close_task()
	main.state.interact_with_store_owner(&"flower")
	await get_tree().process_frame
	var owner_task := main.state.task_instance_for_definition(&"flower_owner_request")
	var scissors := main.state.grant_item(&"scissors", &"test")
	assert_true(main.state.assign_card(owner_task.instance_id, &"trim", scissors).ok)
	main.task_dock._toggle_task(owner_task.instance_id)
	await get_tree().process_frame
	var popup := main.task_dock.task_window
	assert_false(popup.action_button.disabled)
	assert_eq(popup.action_button.text, "")
	assert_eq(
		popup.action_button.icon.resource_path,
		"res://resources/ui/quest/task-confirm.png",
	)
	assert_eq(popup.feedback_label.text, "")
	var owner_slots := popup.slot_views.values()
	assert_eq(owner_slots.size(), 2)
	assert_same(owner_slots[0], owner_slots[1])
	assert_same(owner_slots[0], popup.submission_slot)
	assert_eq(popup.slots_row.get_child_count(), 1)
	_assert_slot_contains_no_instruction_copy(popup.submission_slot)
	assert_true(popup.get_global_rect().encloses(popup.submission_slot.get_global_rect()))
	var owner_definition := QuestArcCatalog.task_by_id(owner_task.definition_id)
	var owner_rule := owner_definition.slot_rules[0] as CardSlotRule
	var expected_prompts := PackedStringArray()
	for raw_rule in owner_definition.slot_rules:
		var rule := raw_rule as CardSlotRule
		expected_prompts.append(TranslationServer.translate(rule.display_name_key))
		assert_same(popup.slot_views[rule.id], popup.submission_slot)
	assert_eq(popup.slot_prompt_label.text, " / ".join(expected_prompts))
	assert_gt(popup.slot_prompt_label.global_position.y, popup.submission_slot.global_position.y)
	var alternative_item := main.state.grant_item(&"agave", &"test")
	assert_true(popup.submission_slot._can_drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": alternative_item},
	))
	popup.submission_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": alternative_item},
	)
	assert_eq(scissors.location, CardItemState.Location.HAND)
	assert_same(popup.submission_slot.card_view.card, alternative_item)
	owner_rule = popup.submission_slot.rule
	popup.submission_slot.rule_focused.emit(owner_rule)
	assert_eq(
		main.rule_detail_popup.title_label.text,
		TranslationServer.translate(owner_rule.display_name_key),
	)
	assert_eq(
		main.rule_detail_popup.title_label.get_theme_font_size("font_size"),
		QuestRuleDetailPopup.OWNER_RULE_TITLE_FONT_SIZE,
	)
	assert_eq(
		main.rule_detail_popup.title_label.text_overrun_behavior,
		TextServer.OVERRUN_TRIM_ELLIPSIS,
	)
	popup._on_action_pressed()
	assert_true(owner_task.confirmed)
	assert_false(main.state.owner_states.has(&"flower_owner"))
	assert_true(scissors in main.state.inventory)
	assert_true(alternative_item in main.state.inventory)


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
	var grab_position := Vector2(17, 63)
	var preview_carrier := view._build_drag_preview(grab_position)
	var preview := preview_carrier.get_child(0) as CardHandCard
	assert_eq(preview_carrier.z_index, 4096)
	assert_false(preview_carrier.z_as_relative)
	assert_eq(preview.position, -grab_position)
	preview_carrier.position = Vector2(400, 300)
	assert_eq(preview_carrier.position + preview.position, Vector2(400, 300) - grab_position)
	view.return_animation_seconds = 0.0
	view._begin_drag_visual()
	assert_false(view.visible)
	view._end_drag_visual(false)
	assert_true(view.visible)
	preview_carrier.free()


func test_screen_transition_canvas_covers_hovered_cards_and_drag_return_preview() -> void:
	var main := await _spawn_main()
	var view := main.hand_bar.card_views.values()[0] as CardHandCard
	main.hand_bar._on_card_hovered(view.card.instance_id)
	assert_eq(view.z_index, QuestHandBar.HOVER_Z_INDEX)
	assert_gt(view.z_index, 400)
	assert_same(main.screen_transition_overlay.get_parent(), main.screen_transition_layer)
	assert_eq(
		main.screen_transition_layer.layer,
		QuestMain.SCREEN_TRANSITION_CANVAS_LAYER,
	)
	assert_eq(main.drag_return_layer.layer, QuestMain.DRAG_RETURN_CANVAS_LAYER)
	assert_gt(main.screen_transition_layer.layer, main.drag_return_layer.layer)


func test_failed_drag_reuses_the_global_return_preview() -> void:
	var main := await _spawn_main()
	var view := main.hand_bar.card_views.values()[0] as CardHandCard
	var return_layer := main.drag_return_layer
	var return_card := main.drag_return_card
	view.return_animation_seconds = 1.0
	view._begin_drag_visual()
	view._end_drag_visual(false)
	assert_true(view.return_animation_active)
	assert_false(view.visible)
	assert_true(return_card.visible)
	assert_same(main.drag_return_layer, return_layer)
	assert_same(main.drag_return_card, return_card)
	main._cancel_card_return_animation()
	assert_true(view.visible)
	assert_false(return_card.visible)
	view._begin_drag_visual()
	view._end_drag_visual(false)
	assert_same(main.drag_return_layer, return_layer)
	assert_same(main.drag_return_card, return_card)
	assert_eq(return_layer.get_child_count(), 1)
	main._cancel_card_return_animation()


func test_item_detail_icons_append_without_overlap_and_close_outside() -> void:
	var main := await _spawn_main()
	main._show_item(QuestArcCatalog.item_by_id(&"mirror_shard"))
	await get_tree().process_frame
	assert_eq(main.detail_popup.detail_panel.offset_left, ItemDetailPopup.DETAIL_LEFT)
	assert_eq(main.detail_popup.detail_panel.offset_top, ItemDetailPopup.DETAIL_TOP)
	assert_eq(main.detail_popup.detail_panel.offset_right, ItemDetailPopup.DETAIL_RIGHT)
	assert_eq(main.detail_popup.detail_panel.offset_bottom, ItemDetailPopup.DETAIL_BOTTOM)
	assert_eq(
		main.detail_popup.title_label.get_theme_font_size("font_size"),
		ItemDetailPopup.TITLE_FONT_SIZE,
	)
	assert_eq(
		main.detail_popup.description_label.get_theme_font_size("font_size"),
		ItemDetailPopup.DESCRIPTION_FONT_SIZE,
	)
	var original_description := main.detail_popup.description_label.text
	main.detail_popup.description_label.text = "响应式说明文字".repeat(12)
	await get_tree().process_frame
	main.detail_popup._fit_description_font()
	var fitted_description_size := main.detail_popup.description_label.get_theme_font_size(
		"font_size"
	)
	assert_lt(fitted_description_size, ItemDetailPopup.DESCRIPTION_FONT_SIZE)
	assert_gte(fitted_description_size, ItemDetailPopup.DESCRIPTION_MIN_FONT_SIZE)
	assert_lte(
		main.detail_popup.description_label.get_line_count(),
		ItemDetailPopup.DESCRIPTION_MAX_LINES,
	)
	main.detail_popup.description_label.text = original_description
	main.detail_popup._fit_description_font()
	assert_eq(
		main.detail_popup.property_description.get_theme_font_size("font_size"),
		ItemDetailPopup.DESCRIPTION_FONT_SIZE,
	)
	assert_eq(
		main.detail_popup.detail_panel.scale,
		Vector2.ONE * ItemDetailPopup.RIGHT_POPUP_SCALE,
	)
	assert_almost_eq(
		main.detail_popup.detail_panel.pivot_offset.x,
		main.detail_popup.detail_panel.size.x,
		0.01,
	)
	assert_eq(
		main.detail_popup.property_panel.scale,
		Vector2.ONE * ItemDetailPopup.RIGHT_POPUP_SCALE,
	)
	assert_not_null(main.detail_popup.item_image.texture)
	var item_frame := main.detail_popup.item_image.get_parent() as PanelContainer
	assert_eq(item_frame.size, Vector2(82, 82))
	assert_eq(item_frame.size.x, item_frame.size.y)
	assert_gt(main.detail_popup.description_label.get_parent().size.y, item_frame.size.y)
	var property_band := main.detail_popup.detail_panel.find_child(
		"PropertyBand", true, false
	) as MarginContainer
	assert_not_null(property_band)
	assert_eq(
		property_band.custom_minimum_size.y,
		float(ItemDetailPopup.PROPERTY_ICON_SIDE + 4),
	)
	assert_gt(property_band.size.x, main.detail_popup.description_label.size.x)
	var item_summary_row := main.detail_popup.detail_panel.find_child(
		"ItemSummaryRow", true, false
	) as HBoxContainer
	assert_not_null(item_summary_row)
	assert_eq(
		item_summary_row.custom_minimum_size.y,
		float(ItemDetailPopup.ITEM_SUMMARY_HEIGHT),
	)
	var panel_style := main.detail_popup.detail_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(panel_style.bg_color.a, 0.5, 0.001)
	assert_false(property_band.has_theme_stylebox_override("panel"))
	var property_panel_style := (
		main.detail_popup.property_panel.get_theme_stylebox("panel") as StyleBoxFlat
	)
	assert_almost_eq(property_panel_style.bg_color.a, 0.5, 0.001)
	var lamp_view := main.detail_popup.property_views[&"nightwalker"] as Dictionary
	var property_root := lamp_view.root as Control
	var property_button := lamp_view.button as Button
	var property_value := lamp_view.value as Label
	assert_not_null(property_button)
	assert_not_null(property_value)
	assert_eq(
		main.detail_popup.property_row.get_theme_constant("separation"),
		ItemDetailPopup.PROPERTY_GROUP_GAP,
	)
	assert_eq(
		(property_root as HBoxContainer).get_theme_constant("separation"),
		ItemDetailPopup.PROPERTY_ICON_VALUE_GAP,
	)
	assert_eq(property_root.get_child_count(), 2)
	assert_same(property_root.get_child(0), property_button)
	assert_same(property_root.get_child(1), property_value)
	assert_eq(
		property_button.custom_minimum_size,
		Vector2.ONE * ItemDetailPopup.PROPERTY_ICON_SIDE,
	)
	assert_eq(
		property_value.custom_minimum_size.x,
		float(ItemDetailPopup.PROPERTY_VALUE_MIN_WIDTH),
	)
	assert_eq(
		property_value.get_theme_font_size("font_size"),
		ItemDetailPopup.PROPERTY_VALUE_FONT_SIZE,
	)
	assert_almost_eq(property_button.size.x, property_button.size.y, 0.01)
	assert_true(property_button.get_child_count() > 0)
	var base_icon := property_button.get_child(0) as TextureRect
	assert_not_null(base_icon)
	assert_not_null(base_icon.texture)
	main.detail_popup._show_property(&"nightwalker")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.detail_popup.detail_panel.visible)
	assert_true(main.detail_popup.property_panel.visible)
	assert_eq(
		main.detail_popup.property_description.text,
		TranslationServer.translate(ItemDetailPopup.property_description_key(&"nightwalker")),
	)
	assert_eq(
		main.detail_popup.property_icon_image.texture.resource_path,
		"res://resources/ui/property-lamp.svg",
	)
	var first_item_property_font_size := (
		main.detail_popup.property_description.get_theme_font_size("font_size")
	)
	assert_eq(first_item_property_font_size, ItemDetailPopup.DESCRIPTION_FONT_SIZE)
	assert_eq(
		main.detail_popup.property_name.get_theme_font_size("font_size"),
		ItemDetailPopup.TITLE_FONT_SIZE,
	)
	var property_icon_frame := (
		main.detail_popup.property_icon_image.get_parent().get_parent() as PanelContainer
	)
	assert_eq(property_icon_frame.size, Vector2(82, 82))
	var property_icon_style := property_icon_frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(property_icon_style.bg_color, Color("090b0c", 0.995))
	var actual_detail_visual_bottom := (
		main.detail_popup.detail_panel.offset_top
		+ maxf(
			main.detail_popup.detail_panel.size.y,
			main.detail_popup.detail_panel.get_combined_minimum_size().y,
		) * ItemDetailPopup.RIGHT_POPUP_SCALE
	)
	assert_almost_eq(
		main.detail_popup.property_panel.offset_top,
		actual_detail_visual_bottom
		+ ItemDetailPopup.PROPERTY_GAP * ItemDetailPopup.RIGHT_POPUP_SCALE,
		0.1,
	)
	var property_click := InputEventMouseButton.new()
	property_click.button_index = MOUSE_BUTTON_LEFT
	property_click.pressed = true
	property_click.position = property_button.get_global_rect().get_center()
	main.detail_popup._input(property_click)
	assert_true(main.detail_popup.property_panel.visible)
	main.detail_popup._show_property(&"nightwalker")
	assert_false(main.detail_popup.property_panel.visible)
	main.detail_popup._show_property(&"nightwalker")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.detail_popup.property_panel.visible)
	assert_eq(
		main.detail_popup.property_description.get_theme_font_size("font_size"),
		first_item_property_font_size,
	)
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(10, 400)
	main.detail_popup._input(outside_click)
	assert_false(main.detail_popup.property_panel.visible)
	assert_true(main.detail_popup.detail_panel.visible)
	main._show_item(QuestArcCatalog.item_by_id(&"fries"))
	main._show_item(QuestArcCatalog.item_by_id(&"mirror_shard"))
	assert_same((main.detail_popup.property_views[&"nightwalker"] as Dictionary).root, property_root)
	assert_same((main.detail_popup.property_views[&"nightwalker"] as Dictionary).button, property_button)


func test_synthesis_bag_property_opens_primary_top_right_popup() -> void:
	var main := await _spawn_main()
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	await get_tree().process_frame
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(&"base", jasmine))
	await get_tree().process_frame
	var homecomer_button := synthesis.persona_buttons[&"homecomer"] as Button
	assert_true(homecomer_button.visible)
	assert_eq(homecomer_button.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_false(homecomer_button.toggle_mode)
	homecomer_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.detail_popup.visible)
	assert_true(main.detail_popup.detail_panel.visible)
	assert_false(main.detail_popup.property_panel.visible)
	assert_false(main.rule_detail_popup.visible)
	assert_eq(main.detail_popup.primary_property_id, &"homecomer")
	assert_null(main.detail_popup.current_definition)
	assert_eq(main.detail_popup.detail_panel.offset_top, ItemDetailPopup.DETAIL_TOP)
	assert_eq(
		main.detail_popup.title_label.text,
		TranslationServer.translate(ItemDetailPopup.property_name_key(&"homecomer")),
	)
	assert_eq(
		main.detail_popup.description_label.text,
		TranslationServer.translate(ItemDetailPopup.property_description_key(&"homecomer")),
	)
	assert_eq(
		main.detail_popup.item_image.texture.resource_path,
		"res://resources/ui/property-pillow.svg",
	)
	homecomer_button.pressed.emit()
	assert_false(main.detail_popup.visible)


func test_synthesis_is_a_material_first_dedicated_space() -> void:
	var main := await _spawn_main()
	var cola := main.state.grant_item(&"cola") as CardItemState
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	await get_tree().process_frame
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_not_null(synthesis)
	assert_eq(synthesis.material_slots.size(), 3)
	assert_true(synthesis.candidate_buttons.values().all(
		func(button: Button) -> bool: return not button.visible
	))
	assert_true(synthesis.stage_card(&"base", jasmine))
	var soft_gauze := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"soft_gauze"
	)[0] as CardItemState
	assert_true(synthesis.stage_card(&"helper", soft_gauze))
	assert_true(synthesis.stage_card(
		&"persona", PersonaMaskCatalog.card_for_persona(&"dreamwalker")
	))
	await get_tree().process_frame
	assert_true(synthesis.candidate_buttons.has(&"recipe_midnight_rose"))
	assert_true(synthesis.action_button.disabled)
	synthesis._on_candidate_pressed(&"recipe_midnight_rose")
	assert_false(synthesis.action_button.disabled)
	synthesis._on_action_pressed()
	await get_tree().process_frame
	assert_false(main.state.inventory.has(jasmine))
	assert_true(main.state.inventory.any(
		func(card: CardItemState) -> bool: return card.definition_id == &"midnight_rose"
	))
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.NARRATIVE)
	assert_eq(main.state.synthesis_base_instance_id, 0)


func test_debug_button_toggles_synthesis_bag_and_deep_blue_backgrounds() -> void:
	var main := await _spawn_main()
	main._show_synthesis_immediate()
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_false(main.synthesis_uses_image_background)
	assert_false(synthesis.background_image.visible)
	assert_true(synthesis.star_chart.background_visible)
	assert_eq(
		main.synthesis_background_button.text,
		TranslationServer.translate(&"debug.ui.synthesis_background.blue")
	)
	main.synthesis_background_button.pressed.emit()
	assert_true(main.synthesis_uses_image_background)
	assert_true(synthesis.background_image.visible)
	assert_false(synthesis.star_chart.background_visible)
	assert_eq(
		synthesis.background_image.texture.resource_path,
		QuestSynthesisInterface.BAG_BACKGROUND_PATH,
	)
	assert_eq(
		main.synthesis_background_button.text,
		TranslationServer.translate(&"debug.ui.synthesis_background.bag")
	)
	main.synthesis_background_button.pressed.emit()
	assert_false(main.synthesis_uses_image_background)
	assert_false(synthesis.background_image.visible)
	assert_true(synthesis.star_chart.background_visible)


func test_synthesis_result_flip_reuses_views_without_freeing_signal_emitter() -> void:
	var main := await _spawn_main()
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	await get_tree().process_frame
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(&"base", jasmine))
	var soft_gauze := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"soft_gauze"
	)[0] as CardItemState
	assert_true(synthesis.stage_card(&"helper", soft_gauze))
	assert_true(main.state.select_synthesis_persona(&"dreamwalker"))
	synthesis._on_candidate_pressed(&"recipe_midnight_rose")
	synthesis._on_action_pressed()
	assert_not_null(synthesis.pending_output)
	synthesis._show_result()
	var back := synthesis.result_back_button
	var card_view := synthesis.result_card_view
	assert_eq(synthesis.result_holder.get_child_count(), 2)
	assert_true(back.visible)
	assert_false(card_view.visible)
	back.pressed.emit()
	assert_true(is_instance_valid(back))
	assert_same(synthesis.result_back_button, back)
	assert_same(synthesis.result_card_view, card_view)
	assert_eq(synthesis.result_holder.get_child_count(), 2)
	assert_false(back.visible)
	assert_true(card_view.visible)
	assert_same(card_view.card, synthesis.pending_output)


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


func test_protagonist_button_returns_from_synthesis_to_map_even_when_entered_from_shop() -> void:
	var main := await _spawn_main()
	main._show_shop(&"flower")
	await get_tree().process_frame
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestSynthesisInterface)
	main.protagonist_button.pressed.emit()
	await get_tree().process_frame
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq(main.global_frame.texture.resource_path, QuestMain.FRAME_TEXTURE_PATHS[&"map"])


func test_primary_screens_are_reused_across_navigation() -> void:
	var main := await _spawn_main()
	main.bgm_director.fade_seconds = 0.0
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_EMPTY)
	assert_eq(main.global_frame.texture.resource_path, QuestMain.FRAME_TEXTURE_PATHS[&"map"])
	var shared_empty_player := main.bgm_director.active_player
	var map := main.current_screen as QuestMapScreen
	main._show_shop(&"flower")
	await get_tree().process_frame
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_EMPTY)
	assert_eq(main.global_frame.texture.resource_path, QuestMain.FRAME_TEXTURE_PATHS[&"flower"])
	assert_same(main.bgm_director.active_player, shared_empty_player)
	var shop := main.current_screen as QuestShopScreen
	main._show_map()
	await get_tree().process_frame
	assert_same(main.current_screen, map)
	assert_eq(main.global_frame.texture.resource_path, QuestMain.FRAME_TEXTURE_PATHS[&"map"])
	main._show_shop(&"flower")
	await get_tree().process_frame
	assert_same(main.current_screen, shop)
	main._show_synthesis()
	await get_tree().process_frame
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_DEBUSSY)
	assert_false(main.global_frame.visible)
	assert_false(main.task_dock.visible)
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_same(synthesis.get_parent(), main.art_canvas)
	main._return_from_synthesis()
	await get_tree().process_frame
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_EMPTY)
	assert_same(main.current_screen, map)
	assert_true(main.global_frame.visible)
	assert_true(main.task_dock.visible)
	assert_eq(main.global_frame.texture.resource_path, QuestMain.FRAME_TEXTURE_PATHS[&"map"])
	main._show_synthesis()
	await get_tree().process_frame
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_DEBUSSY)
	assert_same(main.current_screen, synthesis)
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.DRAFT)
	assert_true(synthesis.draft_layer.visible)
	assert_false(synthesis.narrative_overlay.visible)
	assert_false(synthesis.result_layer.visible)


func test_hud_and_map_ignore_unrelated_state_deltas() -> void:
	var main := await _spawn_main()
	var map := main.current_screen as QuestMapScreen
	var initial_hud_refreshes := main.debug_hud_refresh_count
	var initial_map_refreshes := map.debug_refresh_count
	var task := main.state.task_instance_for_definition(&"girl_order")
	var fries := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"fries"
	)[0] as CardItemState
	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	assert_eq(main.debug_hud_refresh_count, initial_hud_refreshes)
	assert_eq(map.debug_refresh_count, initial_map_refreshes)

	var jasmine := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"jasmine"
	)[0] as CardItemState
	assert_true(main.state.unlock_store(&"record", jasmine).ok)
	assert_eq(main.debug_hud_refresh_count, initial_hud_refreshes)
	assert_eq(map.debug_refresh_count, initial_map_refreshes + 1)

	var transaction := main.state.transaction_for_store(&"flower")
	main.state.wallet.money = 30
	assert_true(transaction.toggle_shelf_slot(transaction.shelf_slots[0].slot_id).ok)
	var money_before := main.state.wallet.money
	assert_true(main.state.checkout_store(&"flower").ok)
	assert_lt(main.state.wallet.money, money_before)
	assert_eq(main.debug_hud_refresh_count, initial_hud_refreshes + 1)
	assert_eq(map.debug_refresh_count, initial_map_refreshes + 1)


func test_arc_uses_item_strip_reward_summary_and_click_advance() -> void:
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"girl_order")
	var fries := main.state.inventory[0] as CardItemState
	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	assert_true(main.state.confirm_task(task.instance_id).ok)
	assert_true(main.state.begin_next_day().ok)
	main.arc_fade_seconds = 0.0
	main.arc_typewriter_char_seconds = 0.0
	main.bgm_director.fade_seconds = 0.0
	main._run_arc()
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_DREAM)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.arc_overlay.visible)
	assert_eq(main.arc_image.texture, QuestArcCatalog.item_by_id(&"fries").image)
	assert_true(main.arc_used_card.visible)
	assert_eq(main.arc_used_card.definition.id, &"fries")
	assert_eq(main.arc_used_card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_almost_eq(main.arc_used_card.modulate.a, 0.48, 0.001)
	assert_true(main.arc_reward_label.text.contains("12"))
	var task_definition := QuestArcCatalog.task_by_id(task.definition_id)
	assert_true(main.arc_task_source_row.visible)
	assert_almost_eq(main.arc_task_source_row.modulate.a, 0.68, 0.001)
	assert_eq(
		main.arc_task_source_tag_label.text,
		TranslationServer.translate(&"quest.ui.arc.task_source"),
	)
	assert_eq(
		main.arc_task_source_name_label.text,
		TranslationServer.translate(task_definition.display_name_key),
	)
	assert_lt(
		main.arc_task_source_name_label.get_theme_font_size("font_size"),
		main.arc_result_label.get_theme_font_size("font_size"),
	)
	assert_true(main.arc_cursor_label.visible)
	for index in 8:
		main._on_arc_advance_requested()
		await get_tree().process_frame
		if not main.transition_in_progress:
			break
	assert_false(main.transition_in_progress)
	assert_false(main.arc_task_source_row.visible)
	assert_eq(main.state.day, 2)
	assert_eq(main.bgm_director.active_track_id, QuestBgmDirector.TRACK_EMPTY)


func test_small_next_day_button_runs_the_real_confirmed_task_arc() -> void:
	var main := await _spawn_main()
	var original_day := main.state.day
	var original_money := main.state.wallet.money
	var task := main.state.task_instance_for_definition(&"girl_order")
	var fries := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.definition_id == &"fries"
	)[0] as CardItemState
	assert_true(main.state.assign_card(task.instance_id, &"food", fries).ok)
	assert_true(main.state.confirm_task(task.instance_id).ok)
	main.arc_fade_seconds = 0.0
	main.arc_typewriter_char_seconds = 0.0
	main.bgm_director.fade_seconds = 0.0
	main.next_day_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.arc_overlay.visible)
	assert_false(main.hand_bar.visible)
	assert_true(main.transition_in_progress)
	assert_true(main.arc_waiting_for_click)
	assert_true(main.arc_task_source_row.visible)
	assert_eq(main.arc_used_card.definition.id, &"fries")
	assert_not_null(main.state.pending_arc)
	assert_eq(main.state.pending_arc.entries.size(), 1)
	assert_true(main.state.pending_arc.effects_applied)
	assert_true(task.settled)
	assert_eq(main.state.day, original_day)
	assert_eq(main.state.wallet.money, original_money + 12)
	main._on_arc_advance_requested()
	await get_tree().process_frame
	assert_eq(
		main.arc_day_label.text,
		TranslationServer.translate(&"quest.ui.arc.new_day") % (original_day + 1)
	)
	main._on_arc_advance_requested()
	for index in 6:
		await get_tree().process_frame
		if not main.transition_in_progress:
			break
	assert_false(main.transition_in_progress)
	assert_eq(main.state.day, original_day + 1)
	assert_eq(main.state.wallet.money, original_money + 12)
	assert_null(main.state.pending_arc)


func test_closing_location_popup_returns_unconfirmed_card() -> void:
	var main := await _spawn_main()
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	var popup := map.location_popup
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": jasmine},
	)
	map.location_popup.closed.emit()
	await get_tree().process_frame
	assert_null(map.location_popup)
	assert_true(main.hand_bar.card_views.has(jasmine.instance_id))
	assert_false(main.state.is_store_unlocked(&"record"))
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	assert_same(map.location_popup, popup)
	assert_null(map.location_popup.unlock_slot.pending_card)
	assert_true(map.location_popup.visible)


func test_location_slot_replaces_draft_and_dragging_to_hand_clears_it() -> void:
	var main := await _spawn_main()
	var first := main.state.grant_item(&"jasmine", &"test") as CardItemState
	var second := main.state.grant_item(&"jasmine", &"test") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	var slot := map.location_popup.unlock_slot
	_assert_slot_contains_no_instruction_copy(slot)
	var card_view := slot.card_view
	slot._drop_data(Vector2.ZERO, {"kind": &"card_item", "card": first})
	assert_true(main.hand_bar.temporarily_hidden_card_ids.has(first.instance_id))

	var replacement_data := {"kind": &"card_item", "card": second}
	assert_true(slot._can_drop_data(Vector2.ZERO, replacement_data))
	slot._drop_data(Vector2.ZERO, replacement_data)
	assert_same(slot.card_view, card_view)
	assert_same(slot.pending_card, second)
	assert_false(main.hand_bar.temporarily_hidden_card_ids.has(first.instance_id))
	assert_true(main.hand_bar.card_views.has(first.instance_id))
	assert_true(main.hand_bar.temporarily_hidden_card_ids.has(second.instance_id))

	slot.card_view.inspect_requested.emit(QuestArcCatalog.item_by_id(second.definition_id))
	assert_same(main.detail_popup.current_definition, QuestArcCatalog.item_by_id(&"jasmine"))
	assert_true(main.detail_popup.visible)
	assert_false(main.rule_detail_popup.visible)

	slot.card_view._begin_drag_visual()
	main.hand_bar._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": second},
	)
	slot.card_view._end_drag_visual(true)
	await get_tree().process_frame
	assert_null(slot.pending_card)
	assert_false(slot.card_view.visible)
	assert_false(main.hand_bar.temporarily_hidden_card_ids.has(second.instance_id))
	assert_true(main.hand_bar.card_views.has(second.instance_id))


func test_switching_spaces_clears_location_popup_draft() -> void:
	var main := await _spawn_main()
	var jasmine := main.state.grant_item(&"jasmine") as CardItemState
	await get_tree().process_frame
	var map := main.current_screen as QuestMapScreen
	map._on_store_pressed(&"record")
	await get_tree().process_frame
	map.location_popup.unlock_slot._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": jasmine},
	)
	assert_true(main.hand_bar.temporarily_hidden_card_ids.has(jasmine.instance_id))
	main._show_synthesis()
	await get_tree().process_frame
	assert_true(main.hand_bar.temporarily_hidden_card_ids.is_empty())
	assert_eq(jasmine.location, CardItemState.Location.HAND)
	assert_false(main.state.is_store_unlocked(&"record"))


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _assert_slot_contains_no_instruction_copy(slot: QuestTaskSlot) -> void:
	var stack := slot.get_child(0) as Control
	assert_eq(stack.get_child_count(), 1)
	assert_same(stack.get_child(0), slot.card_holder)
	assert_eq(slot.card_holder.get_child_count(), 1)
	assert_same(slot.card_holder.get_child(0), slot.card_view)
