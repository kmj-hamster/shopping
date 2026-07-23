extends GutTest


func test_teddy_can_be_filled_from_unlimited_mirror_monominoes() -> void:
	var setup := _filled_solution(&"teddy", Vector2i(1, 1), 0, &"toy_marble")
	var result := PuzzleRules.evaluate(setup.task, setup.pieces)
	assert_true(result.is_complete, str(result.reasons))
	assert_eq(result.required_special_count, 1)
	assert_eq(result.attribute_totals[ItemDefinition.ATTRIBUTE_MIRROR], 19)


func test_goldfish_can_be_filled_from_unlimited_flower_monominoes() -> void:
	var setup := _filled_solution(&"goldfish", Vector2i(1, 2), 0, &"fast_sugar")
	var result := PuzzleRules.evaluate(setup.task, setup.pieces)
	assert_true(result.is_complete, str(result.reasons))
	assert_eq(result.attribute_totals[ItemDefinition.ATTRIBUTE_MIRROR], 7)
	assert_eq(result.attribute_totals[ItemDefinition.ATTRIBUTE_FLOWER], 16)


func test_tape_can_be_filled_without_an_attribute_restriction() -> void:
	var setup := _filled_solution(&"tape", Vector2i(0, 0), 0, &"book_period")
	var result := PuzzleRules.evaluate(setup.task, setup.pieces)
	assert_true(result.is_complete, str(result.reasons))
	assert_eq(result.covered_count, 29)


func test_missing_special_item_blocks_completion() -> void:
	var task := DemoCatalog.task_by_id(&"teddy")
	var pieces: Array[PuzzlePieceState] = []
	var result := PuzzleRules.evaluate(task, pieces)
	assert_false(result.is_complete)
	assert_false(result.has_required_special)


func test_duplicate_special_item_blocks_completion() -> void:
	var task := DemoCatalog.task_by_id(&"teddy")
	var pieces: Array[PuzzlePieceState] = [
		_placed_piece(1, &"special_teddy", Vector2i(1, 1), 0),
		_placed_piece(2, &"special_teddy", Vector2i(1, 1), 0),
	]
	var result := PuzzleRules.evaluate(task, pieces)
	assert_false(result.is_complete)
	assert_eq(result.required_special_count, 2)


func test_overlap_and_outside_cells_are_reported() -> void:
	var task := DemoCatalog.task_by_id(&"teddy")
	var first := _placed_piece(1, &"book_manga", Vector2i(0, 0), 0)
	var second := _placed_piece(2, &"toy_blocks", Vector2i(0, 0), 0)
	var outside := _placed_piece(3, &"book_period", Vector2i(-1, 0), 0)
	var pieces: Array[PuzzlePieceState] = [first, second, outside]
	var result := PuzzleRules.evaluate(task, pieces)
	assert_gt(result.overlap_cells.size(), 0)
	assert_gt(result.outside_cells.size(), 0)


func test_drag_candidate_can_replace_its_original_piece() -> void:
	var task := DemoCatalog.task_by_id(&"teddy")
	var original := _placed_piece(1, &"toy_blocks", Vector2i(1, 1), 0)
	var candidate := original.copy_for_drag()
	var pieces: Array[PuzzlePieceState] = [original]
	assert_true(PuzzleRules.can_place(task, candidate, pieces, Vector2i(1, 1), 0, original))


func test_board_pieces_from_other_tasks_do_not_overlap_or_count() -> void:
	var teddy := DemoCatalog.task_by_id(&"teddy")
	var teddy_piece := _placed_piece(1, &"toy_marble", Vector2i(0, 0), 0)
	teddy_piece.task_id = &"teddy"
	var goldfish_piece := _placed_piece(2, &"fast_sugar", Vector2i(0, 0), 0)
	goldfish_piece.task_id = &"goldfish"
	var pieces: Array[PuzzlePieceState] = [teddy_piece, goldfish_piece]

	var result := PuzzleRules.evaluate(teddy, pieces)

	assert_eq(result.covered_count, 1)
	assert_true(result.overlap_cells.is_empty())
	assert_true(PuzzleRules.can_place(
		teddy,
		PuzzlePieceState.new(3, DemoCatalog.item_by_id(&"toy_marble")),
		pieces,
		Vector2i(1, 0),
		0
	))


func _filled_solution(
	task_id: StringName,
	special_position: Vector2i,
	special_rotation: int,
	filler_item_id: StringName
) -> Dictionary:
	var task := DemoCatalog.task_by_id(task_id)
	var pieces: Array[PuzzlePieceState] = []
	var special := _placed_piece(1, task.required_special_item_id, special_position, special_rotation)
	pieces.append(special)
	var occupied: Dictionary = {}
	for cell in special.occupied_cells():
		occupied[cell] = true
	var uid := 2
	for cell in task.mask_cells:
		if occupied.has(cell):
			continue
		pieces.append(_placed_piece(uid, filler_item_id, cell, 0))
		uid += 1
	return {
		"task": task,
		"pieces": pieces,
	}


func _placed_piece(uid: int, item_id: StringName, position: Vector2i, rotation: int) -> PuzzlePieceState:
	var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))
	piece.location = PuzzlePieceState.Location.BOARD
	piece.grid_position = position
	piece.rotation_steps = rotation
	return piece
