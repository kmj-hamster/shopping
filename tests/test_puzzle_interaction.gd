extends GutTest


func test_standard_template_drop_creates_a_fresh_piece_each_time() -> void:
	var board := PuzzleBoard.new()
	autofree(board)
	var pieces: Array[PuzzlePieceState] = []
	board.set_context(DemoCatalog.task_by_id(&"teddy"), pieces)

	_drop_template(board, DemoCatalog.item_by_id(&"book_period"), Vector2i(0, 0))
	_drop_template(board, DemoCatalog.item_by_id(&"book_period"), Vector2i(1, 0))

	assert_eq(pieces.size(), 2)
	assert_ne(pieces[0].piece_uid, pieces[1].piece_uid)
	assert_eq(pieces[0].definition.id, pieces[1].definition.id)
	assert_eq(pieces[0].task_id, &"teddy")
	assert_eq(pieces[1].task_id, &"teddy")


func test_drag_preview_keeps_grab_offset_below_native_cursor_anchor() -> void:
	var candidate := PuzzlePieceState.new(-1, DemoCatalog.item_by_id(&"book_bookmark"))
	var preview := PieceDragPreview.new()
	var grab_offset := Vector2i.ZERO
	preview.configure_for_drag(candidate, grab_offset, PuzzleBoard.DEFAULT_CELL_SIZE)
	assert_eq(preview.size, Vector2.ZERO)
	assert_eq(preview.drag_layer.layer, PieceDragPreview.DRAG_CANVAS_LAYER)
	assert_gt(preview.drag_layer.layer, 20)
	assert_true(preview.is_set_as_top_level())
	assert_eq(preview.z_index, 4096)
	assert_eq(preview.shape_preview.size, Vector2(112, 56))
	assert_eq(preview.shape_preview.position, Vector2(-28, -28))

	# Godot owns and repositions the drag-preview root at the mouse cursor.
	# The grabbed-cell correction must therefore live on a child Control.
	preview.position = Vector2(240, 180)
	assert_eq(preview.shape_preview.position, Vector2(-28, -28))

	grab_offset = PolyominoGeometry.rotate_anchor_clockwise(candidate.local_cells(), grab_offset)
	candidate.rotation_steps = 1
	preview.refresh_drag_geometry(grab_offset)
	assert_eq(preview.size, Vector2.ZERO)
	assert_eq(preview.shape_preview.size, Vector2(56, 112))
	assert_eq(preview.shape_preview.position, Vector2(-28, -28))
	preview.free()


func test_lab_rotates_candidate_while_drag_data_remains_uncommitted() -> void:
	var packed := load("res://scenes/puzzle_lab/puzzle_lab.tscn") as PackedScene
	var lab := packed.instantiate()
	add_child_autoqfree(lab)
	var candidate := PuzzlePieceState.new(-1, DemoCatalog.item_by_id(&"toy_blocks"))
	var data := {
		"kind": &"puzzle_piece",
		"candidate": candidate,
		"grab_offset": Vector2i(0, 0),
		"preview": null,
	}

	assert_true(lab._rotate_drag_data(data))
	assert_eq(candidate.rotation_steps, 1)
	assert_has(candidate.local_cells(), data.grab_offset)
	assert_eq(lab.pieces.size(), 0)


func test_developer_board_can_remove_piece_dropped_outside() -> void:
	var board := PuzzleBoard.new()
	autofree(board)
	var piece := PuzzlePieceState.new(1, DemoCatalog.item_by_id(&"special_teddy"))
	piece.location = PuzzlePieceState.Location.BOARD
	var pieces: Array[PuzzlePieceState] = [piece]
	board.set_context(DemoCatalog.task_by_id(&"teddy"), pieces)
	board.size = board.custom_minimum_size
	board.dragged_piece = piece

	board._finish_piece_drag(false, Vector2(-1, board.size.y * 0.5))

	assert_true(pieces.is_empty())
	assert_null(board.dragged_piece)


func test_invalid_drop_inside_board_keeps_original_piece() -> void:
	var board := PuzzleBoard.new()
	autofree(board)
	var piece := PuzzlePieceState.new(1, DemoCatalog.item_by_id(&"book_period"))
	piece.location = PuzzlePieceState.Location.BOARD
	var pieces: Array[PuzzlePieceState] = [piece]
	board.set_context(DemoCatalog.task_by_id(&"teddy"), pieces)
	board.size = board.custom_minimum_size
	board.dragged_piece = piece

	board._finish_piece_drag(false, board.size * 0.5)

	assert_eq(pieces, [piece])
	assert_null(board.dragged_piece)


func test_formal_task_board_keeps_piece_after_failed_external_drop() -> void:
	var board := PuzzleBoard.new()
	autofree(board)
	var piece := PuzzlePieceState.new(1, DemoCatalog.item_by_id(&"book_period"))
	piece.location = PuzzlePieceState.Location.BOARD
	piece.grid_position = Vector2i(1, 1)
	var pieces: Array[PuzzlePieceState] = [piece]
	board.set_context(DemoCatalog.task_by_id(&"teddy"), pieces)
	board.size = board.custom_minimum_size
	board.remove_on_failed_external_drop = false
	board.dragged_piece = piece

	board._finish_piece_drag(false, Vector2(-1, board.size.y * 0.5))

	assert_eq(pieces, [piece])
	assert_eq(piece.location, PuzzlePieceState.Location.BOARD)
	assert_eq(piece.grid_position, Vector2i(1, 1))


func test_shop_template_drop_preserves_pending_purchase_ownership() -> void:
	var board := PuzzleBoard.new()
	autofree(board)
	var pieces: Array[PuzzlePieceState] = []
	board.set_context(DemoCatalog.task_by_id(&"teddy"), pieces)
	var candidate := PuzzlePieceState.new(-1, DemoCatalog.item_by_id(&"toy_marble"))
	candidate.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE

	_drop_candidate(board, candidate, Vector2i(0, 0), &"shop_template")

	assert_eq(pieces.size(), 1)
	assert_eq(pieces[0].ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)
	assert_eq(pieces[0].task_id, &"teddy")


func _drop_template(board: PuzzleBoard, definition: ItemDefinition, target: Vector2i) -> void:
	var candidate := PuzzlePieceState.new(-1, definition)
	_drop_candidate(board, candidate, target, &"template")


func _drop_candidate(
	board: PuzzleBoard,
	candidate: PuzzlePieceState,
	target: Vector2i,
	source: StringName
) -> void:
	var local_drop := PuzzleBoard.BOARD_OFFSET + (Vector2(target) + Vector2(0.5, 0.5)) * board.cell_size
	board._drop_data(local_drop, {
		"kind": &"puzzle_piece",
		"source": source,
		"candidate": candidate,
		"original": null,
		"grab_offset": Vector2i.ZERO,
		"preview": null,
	})
