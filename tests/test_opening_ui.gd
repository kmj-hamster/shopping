extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_formal_opening_has_no_tasks_and_starts_with_tin_frog_and_expedition_entry() -> void:
	var main := await _spawn_main()
	assert_eq(main.task_dock.bookmark_buttons.size(), 0)
	assert_eq(main.state.task_instances.size(), 0)
	assert_eq(main.state.inventory.size(), 1)
	assert_eq(main.state.inventory[0].definition_id, &"tin_frog")
	assert_true(main.hand_bar.card_views.has(main.state.inventory[0].instance_id))
	for persona_id in CardPropertySet.PERSONAS:
		var persona_card := PersonaMaskCatalog.card_for_persona(persona_id)
		assert_true(main.hand_bar.card_views.has(persona_card.instance_id))
	assert_eq(main.hand_bar.card_views.size(), 5)
	assert_eq(main.map_screen.store_hotspots.size(), 5)
	assert_not_null(main.map_screen.expedition_button)
	assert_eq(main.map_screen.expedition_button.tooltip_text, "")


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
