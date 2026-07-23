extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_main_opens_map_and_navigates_to_toy_store() -> void:
	var main = await _spawn_main()
	assert_eq(main.current_view, &"map")
	assert_eq(main.current_screen.name, "MallMapScreen")

	main._on_shop_requested(DemoCatalog.STORE_TOY)
	await get_tree().process_frame

	assert_eq(main.current_view, &"shop")
	assert_eq(main.current_screen.name, "ToyShopScreen")


func test_buying_special_updates_map_goal_after_leaving() -> void:
	var main = await _spawn_main()
	main._show_shop()
	await get_tree().process_frame
	var shop = main.current_screen
	shop._on_product_add_requested(&"special_teddy")
	shop._on_checkout_pressed()
	await get_tree().process_frame
	assert_true(GameState.is_task_unlocked(&"teddy"))

	shop._on_leave_pressed()
	await get_tree().process_frame

	assert_eq(main.current_view, &"map")
	assert_eq(
		main.current_screen.goal_label.text,
		"□  " + TranslationServer.translate(&"map.goal.finish_teddy")
	)


func test_completed_teddy_event_returns_to_map_and_advances_stage() -> void:
	var original_locale := LocaleManager.current_locale
	LocaleManager.set_locale("zh_CN", false)
	var main = await _spawn_main()
	main._show_shop()
	await get_tree().process_frame
	var shop = main.current_screen
	shop._on_product_add_requested(&"special_teddy")
	for _index in 4:
		shop._on_product_add_requested(&"toy_blocks")
	shop._on_checkout_pressed()
	await get_tree().process_frame
	_fill_unlocked_teddy_board()

	shop._on_talk_pressed()
	await get_tree().process_frame

	assert_eq(GameState.world_stage, 1)
	assert_true(GameState.is_task_completed(&"teddy"))
	assert_eq(main.current_view, &"map")
	assert_eq(main.current_screen.notice_label.text, TranslationServer.translate(&"map.notice.teddy_complete"))

	LocaleManager.set_locale("en", false)
	assert_eq(main.current_screen.notice_label.text, "The first thing is done.")
	LocaleManager.set_locale(original_locale, false)


func _spawn_main():
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate()
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _fill_unlocked_teddy_board() -> void:
	var special: PuzzlePieceState
	var blocks: Array[PuzzlePieceState] = []
	for piece in GameState.pieces:
		if piece.definition.id == &"special_teddy":
			special = piece
		elif piece.definition.id == &"toy_blocks":
			blocks.append(piece)
	special.location = PuzzlePieceState.Location.BOARD
	special.grid_position = Vector2i(1, 1)
	var placements := [
		[Vector2i(0, 0), 1],
		[Vector2i(3, 0), 2],
		[Vector2i(0, 3), 2],
		[Vector2i(3, 3), 1],
	]
	for index in blocks.size():
		blocks[index].location = PuzzlePieceState.Location.BOARD
		blocks[index].grid_position = placements[index][0]
		blocks[index].rotation_steps = placements[index][1]
