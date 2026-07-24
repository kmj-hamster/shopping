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


func test_each_task_has_collapsible_four_by_task_height_organizer() -> void:
	var popup := TaskPuzzlePopup.new()
	add_child_autoqfree(popup)
	popup.setup(DemoCatalog.DAILY_TASK_ID, &"map")
	await get_tree().process_frame
	assert_false(popup.organizer_wrap.visible)
	assert_eq(popup.organizer_board.task.bounds_size().x, 4)
	assert_eq(popup.organizer_board.task.bounds_size().y, popup.task.bounds_size().y)
	popup._on_organizer_toggled()
	assert_true(popup.organizer_wrap.visible)


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


func test_nonempty_organizer_blocks_popup_close_and_checkout() -> void:
	var piece := PuzzlePieceState.new(1, DemoCatalog.item_by_id(&"toy_marble"))
	piece.location = PuzzlePieceState.Location.ORGANIZER
	piece.task_id = DemoCatalog.DAILY_TASK_ID
	piece.grid_position = Vector2i.ZERO
	GameState.pieces.append(piece)
	var popup := TaskPuzzlePopup.new()
	add_child_autoqfree(popup)
	popup.setup(DemoCatalog.DAILY_TASK_ID, &"shop")
	var close_count := [0]
	popup.close_requested.connect(func(_task_id: StringName) -> void: close_count[0] += 1)
	popup._on_close_pressed()
	assert_eq(close_count[0], 0)
	assert_true(popup.has_organizer_pieces())
	var transaction := GameState.toy_transaction
	assert_eq(transaction.checkout().reason, ShopTransaction.RESULT_ORGANIZER_NOT_EMPTY)


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
