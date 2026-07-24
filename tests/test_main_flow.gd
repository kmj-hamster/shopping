extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_main_opens_map_with_bag_entry_and_navigates_to_shop() -> void:
	var main = await _spawn_main()
	assert_eq(main.current_view, &"map")
	assert_eq(main.current_screen.name, "MallMapScreen")
	assert_eq(main.current_screen.store_hotspots.size(), 6)
	assert_not_null(main.protagonist_interface)
	assert_not_null(main.protagonist_interface.bag_button.texture_normal)
	assert_not_null(main.protagonist_interface.bag_button.texture_hover)

	main._on_shop_requested(DemoCatalog.STORE_TOY)
	await get_tree().process_frame
	assert_eq(main.current_view, &"shop")
	assert_eq(main.current_screen.name, "ToyShopScreen")
	assert_eq(main.current_screen.store_id, DemoCatalog.STORE_TOY)
	assert_eq(main.protagonist_interface.view_context, &"shop")


func test_six_map_hotspots_do_not_overlap_and_recycling_uses_upper_left() -> void:
	var main = await _spawn_main()
	var hotspots: Array = main.current_screen.store_hotspots.values()
	for first_index in range(hotspots.size()):
		var first := hotspots[first_index] as Button
		var first_rect := Rect2(first.position, first.size)
		for second_index in range(first_index + 1, hotspots.size()):
			var second := hotspots[second_index] as Button
			var second_rect := Rect2(second.position, second.size)
			assert_false(
				first_rect.intersects(second_rect),
				"%s overlaps %s" % [first.name, second.name]
			)
	var recycling := main.current_screen.store_hotspots[DemoCatalog.STORE_RECYCLING] as Button
	assert_lt(recycling.position.x, 100.0)
	assert_lt(recycling.position.y, 260.0)


func test_recycling_hotspot_opens_dedicated_nonretail_screen() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_RECYCLING)
	await get_tree().process_frame
	assert_eq(main.current_view, &"shop")
	assert_eq(main.current_screen.name, "RecyclingShopScreen")
	assert_null(GameState.transaction_for_store(DemoCatalog.STORE_RECYCLING))
	assert_eq(main.current_screen.transaction, GameState.recycle_transaction)


func test_open_bookstore_uses_shared_shop_screen_and_its_own_stock() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_BOOK)
	await get_tree().process_frame
	assert_eq(main.current_view, &"shop")
	assert_eq(main.current_screen.transaction.store_id, DemoCatalog.STORE_BOOK)
	assert_eq(main.current_screen.store_name_label.text, TranslationServer.translate(&"store.book"))


func test_closed_store_stays_on_map_and_shows_next_open_day() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_RECORD)
	await get_tree().process_frame
	assert_eq(main.current_view, &"map")
	assert_true(main.current_screen.notice_label.visible)
	assert_string_contains(main.current_screen.notice_label.text, str(TranslationServer.translate(&"store.record")))
	assert_string_contains(main.current_screen.notice_label.text, str(TranslationServer.translate(&"weekday.tue")))


func test_daily_submission_unlocks_next_day_and_transition_consumes_daily_grid() -> void:
	var main = await _spawn_main()
	assert_false(main.current_screen.next_day_button.disabled)
	assert_eq(
		main.current_screen.next_day_button.tooltip_text,
		TranslationServer.translate(&"map.next_day.locked")
	)
	main.current_screen._on_next_day_pressed()
	assert_eq(GameState.day, 1)
	assert_true(main.current_screen.notice_panel.visible)
	assert_true(main.current_screen.notice_label.visible)
	assert_eq(
		main.current_screen.notice_label.text,
		TranslationServer.translate(&"map.next_day.locked")
	)
	assert_eq(main.current_screen.next_day_button.size.y, main.current_screen.schedule_button.size.y)
	_fill_daily_goal()
	assert_true(GameState.submit_daily_goal().ok)
	await get_tree().process_frame
	assert_false(main.current_screen.next_day_button.disabled)
	assert_false(main.current_screen.notice_panel.visible)
	main.protagonist_interface._on_bag_pressed()
	main.protagonist_interface.open_task(DemoCatalog.DAILY_TASK_ID)
	main.current_screen._on_next_day_pressed()
	await get_tree().process_frame
	assert_eq(GameState.day, 2)
	assert_eq(GameState.wallet.money, 200)
	assert_true(GameState.pieces.is_empty())
	assert_true(main.current_screen.transition_panel.visible)
	assert_true(GameState.is_store_open(DemoCatalog.STORE_RECORD))
	assert_false(main.protagonist_interface.protagonist_popup.visible)
	assert_true(main.protagonist_interface.task_popups.is_empty())


func test_next_day_from_shop_confirms_and_cancels_unpaid_cart() -> void:
	var main = await _spawn_main()
	_fill_daily_goal()
	assert_true(GameState.submit_daily_goal().ok)
	main._show_shop()
	await get_tree().process_frame
	var shop = main.current_screen
	shop._on_talk_pressed()
	var pending := shop.transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(pending, &"teddy", Vector2i.ZERO)
	main.protagonist_interface._on_bag_pressed()
	main.protagonist_interface.open_task(&"teddy")
	shop._on_next_day_pressed()
	assert_eq(GameState.day, 1)
	assert_true(shop.exit_confirmation.visible)
	assert_eq(shop.exit_confirmation_mode, shop.CONFIRM_NEXT_DAY)
	shop._on_exit_confirmed()
	await get_tree().process_frame
	assert_eq(main.current_view, &"map")
	assert_eq(GameState.day, 2)
	assert_eq(GameState.wallet.money, 200)
	assert_true(GameState.pieces.is_empty())
	assert_true(main.current_screen.transition_panel.visible)
	assert_false(main.protagonist_interface.protagonist_popup.visible)
	assert_true(main.protagonist_interface.task_popups.is_empty())


func test_leaving_shop_confirms_unpaid_items_and_closes_bag_popups() -> void:
	var main = await _spawn_main()
	main._show_shop()
	await get_tree().process_frame
	var shop = main.current_screen
	var pending := shop.transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(pending, DemoCatalog.EMPTY_BAG_TASK_ID, Vector2i.ZERO)
	main.protagonist_interface._on_bag_pressed()
	main.protagonist_interface.open_task(DemoCatalog.EMPTY_BAG_TASK_ID)
	shop._on_leave_pressed()
	assert_eq(main.current_view, &"shop")
	assert_true(shop.exit_confirmation.visible)
	assert_false(main.protagonist_interface.task_popups.is_empty())
	shop._on_exit_cancelled()
	await get_tree().process_frame
	assert_eq(main.current_view, &"map")
	assert_false(GameState.pieces.has(pending))
	assert_false(main.protagonist_interface.protagonist_popup.visible)
	assert_true(main.protagonist_interface.task_popups.is_empty())


func test_owner_talk_unlocks_teddy_and_adds_protagonist_card() -> void:
	var main = await _spawn_main()
	main._show_shop()
	await get_tree().process_frame
	main.current_screen._on_talk_pressed()
	await get_tree().process_frame
	assert_true(GameState.is_task_unlocked(&"teddy"))
	assert_has(main.protagonist_interface.card_buttons, &"teddy")
	assert_eq(GameState.toy_transaction.available_stock(&"special_teddy"), 1)


func test_completed_teddy_event_returns_to_map_and_advances_stage() -> void:
	var original_locale := LocaleManager.current_locale
	LocaleManager.set_locale("zh_CN", false)
	var main = await _spawn_main()
	main._show_shop()
	await get_tree().process_frame
	var shop = main.current_screen
	shop._on_talk_pressed()
	_add_teddy_solution_to_cart(shop.transaction)
	shop._on_checkout_pressed()
	await get_tree().process_frame
	shop._on_talk_pressed()
	await get_tree().process_frame
	assert_eq(GameState.world_stage, 1)
	assert_true(GameState.is_task_completed(&"teddy"))
	assert_eq(main.current_view, &"map")
	assert_eq(main.current_screen.notice_label.text, TranslationServer.translate(&"map.notice.teddy_complete"))
	LocaleManager.set_locale("en", false)
	assert_eq(main.current_screen.notice_label.text, "The first thing is done.")
	LocaleManager.set_locale(original_locale, false)


func test_third_event_opens_demo_summary_and_continue_keeps_map_playable() -> void:
	var main = await _spawn_main()
	for task_id in GameState.TASK_ORDER:
		GameState.completed_tasks[task_id] = true
	GameState.world_stage = 3
	main._on_event_completed(&"tape")
	await get_tree().process_frame
	assert_eq(main.current_view, &"map")
	assert_true(main.current_screen.demo_complete_panel.visible)
	assert_true(main.current_screen.demo_complete_scrim.visible)
	main.current_screen._on_demo_continue_pressed()
	assert_false(main.current_screen.demo_complete_panel.visible)


func _spawn_main():
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate()
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _fill_daily_goal() -> void:
	var uid := 100
	for cell in GameState.daily_task().mask_cells:
		var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(&"book_period"))
		_place_piece(piece, DemoCatalog.DAILY_TASK_ID, cell)
		GameState.pieces.append(piece)
		uid += 1
	GameState.notify_piece_layout_changed()


func _add_teddy_solution_to_cart(transaction: ShopTransaction) -> void:
	var rows := [
		[&"special_teddy", Vector2i(1, 1), 0],
		[&"toy_blocks", Vector2i(0, 0), 1],
		[&"toy_blocks", Vector2i(3, 0), 2],
		[&"toy_blocks", Vector2i(0, 3), 2],
		[&"toy_blocks", Vector2i(3, 3), 1],
	]
	for row in rows:
		var piece := transaction.add_to_cart(row[0]).piece as PuzzlePieceState
		_place_piece(piece, &"teddy", row[1], row[2])


func _place_piece(
	piece: PuzzlePieceState,
	task_id: StringName,
	position: Vector2i,
	rotation: int = 0
) -> void:
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = task_id
	piece.grid_position = position
	piece.rotation_steps = rotation
