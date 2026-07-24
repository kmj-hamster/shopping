extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_bag_panel_opens_daily_card_and_multiple_draggable_task_popups() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	var interface := ProtagonistInterface.new()
	add_child_autoqfree(interface)
	await get_tree().process_frame
	assert_eq(interface.root.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	interface._on_bag_pressed()
	assert_true(interface.protagonist_popup.visible)
	assert_has(interface.card_buttons, DemoCatalog.DAILY_TASK_ID)
	assert_has(interface.card_buttons, &"teddy")
	var daily := interface.open_task(DemoCatalog.DAILY_TASK_ID)
	var teddy := interface.open_task(&"teddy")
	await get_tree().process_frame
	assert_eq(interface.task_popups.size(), 2)
	assert_eq(daily.task_id, DemoCatalog.DAILY_TASK_ID)
	assert_eq(teddy.task_id, &"teddy")
	assert_ne(daily.position, teddy.position)
	assert_eq(interface.bag_button.size, Vector2(168, 168))
	assert_eq(interface.bag_button.get_global_rect().end.y, get_viewport().get_visible_rect().end.y)
	assert_lt(interface.bag_button.z_index, interface.protagonist_popup.z_index)
	assert_lt(interface.bag_button.z_index, daily.z_index)


func test_empty_bag_is_a_shared_eight_by_eight_popup() -> void:
	var interface := ProtagonistInterface.new()
	add_child_autoqfree(interface)
	await get_tree().process_frame
	assert_has(interface.card_buttons, DemoCatalog.EMPTY_BAG_TASK_ID)
	var popup := interface.open_task(DemoCatalog.EMPTY_BAG_TASK_ID)
	assert_eq(popup.task.bounds_size(), Vector2i(8, 8))
	assert_false(popup.empty_bag_toggle_button.visible)


func test_task_popup_icon_opens_and_closes_shared_empty_bag() -> void:
	var interface := ProtagonistInterface.new()
	add_child_autoqfree(interface)
	await get_tree().process_frame
	interface.set_view_context(&"shop")
	var daily := interface.open_task(DemoCatalog.DAILY_TASK_ID)
	assert_eq(daily.empty_bag_toggle_button.text, "▦")
	interface._on_empty_bag_toggle_requested(daily)
	await get_tree().process_frame
	assert_has(interface.task_popups, DemoCatalog.EMPTY_BAG_TASK_ID)
	var empty_bag := interface.task_popups[DemoCatalog.EMPTY_BAG_TASK_ID] as TaskPuzzlePopup
	assert_almost_eq(
		empty_bag.position.x + empty_bag.size.x,
		daily.position.x - ProtagonistInterface.EMPTY_BAG_POPUP_GAP,
		0.1
	)
	assert_gt(empty_bag.position.x, 200.0)
	assert_eq(daily.empty_bag_toggle_button.text, "▣")
	interface._on_empty_bag_toggle_requested(daily)
	assert_false(interface.task_popups.has(DemoCatalog.EMPTY_BAG_TASK_ID))
	assert_eq(daily.empty_bag_toggle_button.text, "▦")
	daily.position = Vector2(100, 80)
	interface._on_empty_bag_toggle_requested(daily)
	await get_tree().process_frame
	empty_bag = interface.task_popups[DemoCatalog.EMPTY_BAG_TASK_ID] as TaskPuzzlePopup
	assert_eq(empty_bag.position, ProtagonistInterface.EMPTY_BAG_FALLBACK_POSITION)


func test_completed_daily_and_story_cards_use_completed_color() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	var interface := ProtagonistInterface.new()
	add_child_autoqfree(interface)
	await get_tree().process_frame
	var daily := interface.card_buttons[DemoCatalog.DAILY_TASK_ID] as Button
	var pending_style := daily.get_theme_stylebox("normal") as StyleBoxFlat
	assert_ne(pending_style.bg_color, ProtagonistInterface.COMPLETED_CARD_FILL)
	GameState.daily_goal.submitted = true
	GameState.completed_tasks[&"teddy"] = true
	interface.refresh()
	var completed_daily := interface.card_buttons[DemoCatalog.DAILY_TASK_ID] as Button
	var completed_teddy := interface.card_buttons[&"teddy"] as Button
	assert_eq(
		(completed_daily.get_theme_stylebox("normal") as StyleBoxFlat).bg_color,
		ProtagonistInterface.COMPLETED_CARD_FILL
	)
	assert_eq(
		(completed_teddy.get_theme_stylebox("normal") as StyleBoxFlat).border_color,
		ProtagonistInterface.COMPLETED_CARD_BORDER
	)


func test_owned_piece_moves_directly_between_open_task_boards_without_copying() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	var piece := PuzzlePieceState.new(1, DemoCatalog.item_by_id(&"book_period"))
	_place_piece(piece, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	GameState.pieces.append(piece)
	var target := TaskPuzzlePopup.new()
	add_child_autoqfree(target)
	target.setup(&"teddy", &"map")
	await get_tree().process_frame
	var candidate := piece.copy_for_drag()
	_drop_piece(target.puzzle_board, candidate, piece, Vector2i.ZERO)
	assert_eq(GameState.pieces, [piece])
	assert_eq(piece.task_id, &"teddy")
	assert_eq(piece.grid_position, Vector2i.ZERO)


func test_shop_drag_candidate_creates_pending_piece_only_after_legal_drop() -> void:
	var popup := TaskPuzzlePopup.new()
	add_child_autoqfree(popup)
	popup.setup(DemoCatalog.DAILY_TASK_ID, &"shop")
	await get_tree().process_frame
	var candidate := GameState.toy_transaction.make_drag_candidate(&"toy_marble")
	var data := {
		"kind": &"puzzle_piece",
		"source": &"shop_template",
		"candidate": candidate,
		"original": null,
		"grab_offset": Vector2i.ZERO,
		"preview": null,
	}
	assert_true(GameState.pieces.is_empty())
	popup.puzzle_board._drop_data(_local_drop(Vector2i.ZERO), data)
	assert_eq(GameState.pieces.size(), 1)
	assert_eq(GameState.pieces[0].ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)
	assert_eq(GameState.pieces[0].task_id, DemoCatalog.DAILY_TASK_ID)


func test_popup_can_close_while_empty_bag_contains_items() -> void:
	var piece := PuzzlePieceState.new(1, DemoCatalog.item_by_id(&"toy_marble"))
	_place_piece(piece, DemoCatalog.EMPTY_BAG_TASK_ID, Vector2i.ZERO)
	GameState.pieces.append(piece)
	var popup := TaskPuzzlePopup.new()
	add_child_autoqfree(popup)
	popup.setup(DemoCatalog.DAILY_TASK_ID, &"shop")
	var close_count := [0]
	popup.close_requested.connect(func(_task_id: StringName) -> void: close_count[0] += 1)
	popup._on_close_pressed()
	assert_eq(close_count[0], 1)


func test_daily_submit_shows_checkout_notice_when_complete_grid_contains_unpaid_piece() -> void:
	var task := GameState.daily_task()
	var definition := DemoCatalog.item_by_id(&"toy_marble")
	for index in range(task.mask_cells.size()):
		var piece := PuzzlePieceState.new(index + 1, definition)
		piece.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE
		_place_piece(piece, DemoCatalog.DAILY_TASK_ID, task.mask_cells[index])
		GameState.pieces.append(piece)
	var popup := TaskPuzzlePopup.new()
	add_child_autoqfree(popup)
	popup.setup(DemoCatalog.DAILY_TASK_ID, &"shop")
	await get_tree().process_frame
	assert_true(popup.submit_button.visible)
	popup._on_submit_pressed()
	assert_false(GameState.daily_goal.submitted)
	assert_true(popup.checkout_notice.visible)
	assert_eq(
		popup.checkout_notice_label.text,
		TranslationServer.translate(&"task.checkout_first")
	)


func _drop_piece(
	board: PuzzleBoard,
	candidate: PuzzlePieceState,
	original: PuzzlePieceState,
	target: Vector2i
) -> void:
	board._drop_data(_local_drop(target), {
		"kind": &"puzzle_piece",
		"source": &"board",
		"candidate": candidate,
		"original": original,
		"grab_offset": Vector2i.ZERO,
		"preview": null,
	})


func _local_drop(target: Vector2i) -> Vector2:
	return PuzzleBoard.BOARD_OFFSET + (Vector2(target) + Vector2(0.5, 0.5)) * TaskPuzzlePopup.CELL_SIZE


func _place_piece(piece: PuzzlePieceState, task_id: StringName, position: Vector2i) -> void:
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = task_id
	piece.grid_position = position
