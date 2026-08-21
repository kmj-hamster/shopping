extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	GameState.reset_game()


func test_formal_opening_has_no_tasks_and_starts_with_tin_frog_and_expedition_entry() -> void:
	var main := await _spawn_main()
	assert_eq(main.task_dock.bookmark_buttons.size(), 0)
	assert_eq(main.task_dock.archive_buttons.size(), 1)
	assert_eq(main.state.task_instances.size(), 0)
	assert_eq(main.state.inventory.size(), 1)
	assert_eq(main.state.inventory[0].definition_id, &"tin_frog")
	assert_true(main.hand_bar.card_views.has(main.state.inventory[0].instance_id))
	for shape_id in CardPropertySet.SHAPES:
		var persona_card := PersonaCardCatalog.card_for_shape(shape_id)
		assert_true(main.hand_bar.card_views.has(persona_card.instance_id))
	assert_eq(main.hand_bar.card_views.size(), 5)
	assert_eq(main.map_screen.store_hotspots.size(), 5)
	assert_true((main.map_screen.store_hotspots[&"toy"] as Control).visible)
	for hidden_store_id in [&"fast_food", &"flower", &"record", &"bookstore"]:
		assert_false((main.map_screen.store_hotspots[hidden_store_id] as Control).visible)
	assert_not_null(main.map_screen.expedition_button)
	assert_eq(main.map_screen.expedition_button.tooltip_text, "")


func test_store_hotspots_use_locked_closed_and_hover_open_door_art() -> void:
	var main := await _spawn_main()
	var hotspot := main.map_screen.store_hotspots[&"toy"] as QuestStoreHotspot
	assert_eq(QuestStoreHotspot.HOTSPOT_SIZE, Vector2(66, 95))
	assert_eq(hotspot.size, QuestStoreHotspot.HOTSPOT_SIZE)
	assert_eq(
		hotspot.texture_normal.resource_path,
		"res://resources/ui/map/store-door-locked.png",
	)
	assert_eq(hotspot.texture_hover, hotspot.texture_normal)
	assert_eq(hotspot.texture_pressed, hotspot.texture_normal)
	assert_eq(hotspot.self_modulate, QuestStoreHotspot.LOCKED_MODULATE)
	assert_eq(
		hotspot.name_label.text,
		TranslationServer.translate(QuestArcCatalog.store_by_id(&"toy").display_name_key),
	)
	assert_lte(hotspot.name_label.position.y + hotspot.name_label.size.y, 0.0)
	hotspot._on_hover_changed(true)
	assert_true(hotspot.name_label.visible)
	hotspot._on_hover_changed(false)
	assert_false(hotspot.name_label.visible)

	main.state.unlocked_store_ids[&"toy"] = true
	main.map_screen.refresh()
	assert_eq(
		hotspot.texture_normal.resource_path,
		"res://resources/ui/map/store-door-closed.png",
	)
	assert_eq(
		hotspot.texture_hover.resource_path,
		"res://resources/ui/map/store-door-open.png",
	)
	assert_eq(hotspot.texture_pressed, hotspot.texture_hover)
	assert_eq(hotspot.self_modulate, Color.WHITE)


func test_unlock_defers_new_store_doors_until_the_map_is_hidden() -> void:
	var state := QuestGameState.new()
	var map := QuestMapScreen.new()
	map.setup(state)
	add_child_autofree(map)
	await get_tree().process_frame
	var toy_door := map.store_hotspots[&"toy"] as QuestStoreHotspot
	var fast_food_door := map.store_hotspots[&"fast_food"] as QuestStoreHotspot
	var flower_door := map.store_hotspots[&"flower"] as QuestStoreHotspot
	assert_true(toy_door.visible)
	assert_false(fast_food_door.visible)
	assert_false(flower_door.visible)

	map._on_unlock_confirmed(&"toy", state.inventory[0])
	assert_true(state.is_store_unlocked(&"toy"))
	assert_true(toy_door.visible)
	assert_false(fast_food_door.visible)
	assert_false(flower_door.visible)
	assert_true(map.defer_new_store_hotspots_until_hidden)

	map.visible = false
	assert_false(map.defer_new_store_hotspots_until_hidden)
	assert_true(fast_food_door.visible)
	assert_true(flower_door.visible)


func test_map_entrances_follow_doorplace_reference() -> void:
	var main := await _spawn_main()
	var expected_store_anchors := {
		&"toy": Vector2(0.656, 0.316),
		&"fast_food": Vector2(0.93, 0.753),
		&"flower": Vector2(0.672, 0.753),
		&"record": Vector2(0.181, 0.316),
		&"bookstore": Vector2(0.199, 0.753),
	}
	for store_id in expected_store_anchors:
		var hotspot := main.map_screen.store_hotspots[store_id] as QuestStoreHotspot
		var expected_anchor := expected_store_anchors[store_id] as Vector2
		assert_almost_eq(hotspot.anchor_left, expected_anchor.x, 0.001)
		assert_almost_eq(hotspot.anchor_top, expected_anchor.y, 0.001)

	var expedition_button := main.map_screen.expedition_button
	assert_almost_eq(expedition_button.anchor_left, 0.384, 0.001)
	assert_almost_eq(expedition_button.anchor_top, 0.864, 0.001)
	assert_almost_eq(expedition_button.anchor_right, 0.574, 0.001)
	assert_almost_eq(expedition_button.anchor_bottom, 0.959, 0.001)


func test_clicking_the_same_locked_store_door_toggles_its_popup_closed() -> void:
	var main := await _spawn_main()
	main.map_screen._on_store_pressed(&"toy")
	var popup := main.map_screen.location_popup
	assert_not_null(popup)
	assert_true(popup.visible)
	assert_eq(popup.store_id, &"toy")

	main.map_screen._on_store_pressed(&"toy")
	assert_null(main.map_screen.location_popup)
	assert_false(popup.visible)


func test_room_001_archive_uses_a_task_sized_draggable_popup() -> void:
	var main := await _spawn_main()
	main.task_dock._set_expanded(true)
	var archive_button := main.task_dock.archive_buttons[&"room_001_mall"] as Button
	assert_not_null(archive_button)
	assert_null(archive_button.get_node_or_null("QuestUnderline"))
	archive_button.pressed.emit()
	await get_tree().process_frame

	var popup := main.task_dock.archive_window
	assert_not_null(popup)
	assert_same(popup.get_parent(), main.task_popup_layer)
	assert_eq(popup.size, QuestArchiveWindow.WINDOW_SIZE)
	assert_eq(QuestArchiveWindow.WINDOW_SIZE, PaperActivityPopup.PAPER_SIZE)
	assert_same(popup.drag_bounds_control, main.task_popup_layer)
	assert_eq(
		popup.paper_background.texture.resource_path,
		"res://resources/ui/archive/archive-paper.png",
	)
	assert_eq(
		popup.close_button.texture_normal.resource_path,
		"res://resources/ui/archive/archive-close.png",
	)
	assert_eq(popup.title_label.position, QuestArchiveWindow.TITLE_RECT.position)
	assert_eq(
		popup.title_label.autowrap_mode,
		TextServer.AUTOWRAP_WORD_SMART,
	)
	assert_eq(
		popup.title_label.get_theme_font_size("font_size"),
		QuestArchiveWindow.TITLE_FONT_SIZE,
	)
	assert_lte(
		QuestArchiveWindow.TITLE_RECT.end.x,
		QuestArchiveWindow.CLOSE_RECT.position.x - 24.0,
	)
	assert_eq(popup.body_viewport.position, QuestArchiveWindow.BODY_TEXT_RECT.position)
	assert_almost_eq(
		popup.body_viewport.size.x,
		QuestArchiveWindow.BODY_TEXT_RECT.size.x,
		0.001,
	)
	assert_almost_eq(
		popup.body_viewport.size.y,
		QuestArchiveWindow.BODY_TEXT_RECT.size.y,
		0.001,
	)
	assert_eq(
		QuestArchiveWindow.BODY_TEXT_RECT.position.x
			- QuestArchiveWindow.BODY_BORDER_RECT.position.x,
		float(QuestArchiveWindow.BODY_FONT_SIZE * 2),
	)
	assert_eq(
		QuestArchiveWindow.BODY_TEXT_RECT.position.y
			- QuestArchiveWindow.BODY_BORDER_RECT.position.y,
		float(QuestArchiveWindow.BODY_FONT_SIZE),
	)
	assert_eq(popup.title_label.text, "Room 001 新千年商场")
	assert_true(popup.body_label.text.begins_with("罕有调查员报告其存在"))
	assert_eq(popup.body_label.get_theme_color("font_color"), QuestArchiveWindow.TEXT_COLOR)
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	await get_tree().process_frame
	assert_eq(popup.title_label.text, "Room 001 Next Millennium Mall")
	assert_true(popup.body_label.text.begins_with("Few investigators"))
	assert_eq(
		popup.body_label.get_theme_font_size("font_size"),
		QuestArchiveWindow.BODY_EN_FONT_SIZE,
	)
	popup._begin_dragging_at(popup.global_position + Vector2(18, 18))
	assert_true(popup.dragging)
	popup._move_to_canvas_position(
		main.task_popup_layer.global_position + main.task_popup_layer.size + Vector2(200, 200)
	)
	popup._stop_dragging()
	var bounds_rect := main.task_popup_layer.get_global_rect()
	var popup_rect := popup.get_global_rect()
	assert_gte(popup_rect.position.x, bounds_rect.position.x - 0.001)
	assert_gte(popup_rect.position.y, bounds_rect.position.y - 0.001)
	assert_lte(popup_rect.end.x, bounds_rect.end.x + 0.001)
	assert_lte(popup_rect.end.y, bounds_rect.end.y + 0.001)

	var background_click := InputEventMouseButton.new()
	background_click.button_index = MOUSE_BUTTON_LEFT
	background_click.pressed = true
	background_click.position = Vector2(1, 1)
	main.map_screen.background_input.gui_input.emit(background_click)
	assert_null(main.task_dock.archive_window)

	archive_button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(main.task_dock.archive_window)
	main.task_dock.archive_window.close_button.pressed.emit()
	assert_null(main.task_dock.archive_window)


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
		assert_almost_eq(
			shop.owner_portrait.anchor_bottom,
			1.125 if store_id == &"fast_food" else 1.10,
			0.001,
		)
		assert_gt(
			shop.owner_portrait.get_global_rect().end.y,
			main.content_viewport_region.get_global_rect().end.y,
		)
		assert_gt(main.global_frame.z_index, shop.owner_portrait.z_index)


func test_shop_owners_keep_the_shared_dialogue_voice_effect() -> void:
	var main := await _spawn_main()
	var expected_paths := [
		"res://resources/audio/dialogue/robot_blip_a.wav",
		"res://resources/audio/dialogue/robot_blip_b.wav",
	]
	for store_id in [&"toy", &"fast_food", &"flower"]:
		var owner := QuestArcCatalog.owner_for_store(store_id)
		assert_not_null(owner, store_id)
		assert_eq(owner.dialogue_voice_streams.size(), 2, store_id)
		for index in expected_paths.size():
			assert_eq(owner.dialogue_voice_streams[index].resource_path, expected_paths[index])
		main._show_shop_immediate(store_id)
		await get_tree().process_frame
		var shop := main.current_screen as QuestShopScreen
		shop._stop_owner_dialogue_voice()
		var voice_index := shop.owner_dialogue_voice_index
		var player := shop.owner_dialogue_voice_players[
			voice_index % shop.owner_dialogue_voice_players.size()
		] as AudioStreamPlayer
		shop._play_owner_dialogue_voice()
		assert_eq(shop.owner_dialogue_voice_index, voice_index + 1)
		assert_true(player.playing)


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
