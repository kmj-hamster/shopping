extends GutTest


func test_teddy_baseline_solution_costs_82_and_requires_mirror_lead() -> void:
	var setup := _solution(&"teddy", [
		[&"special_teddy", Vector2i(3, 0), 0],
		[&"book_manga", Vector2i(0, 0), 0],
		[&"toy_blocks", Vector2i(3, 3), 1],
		[&"flower_sunflower", Vector2i(0, 2), 1],
		[&"fast_straw", Vector2i(2, 1), 1],
	])
	var result := PuzzleRules.evaluate(setup.task, setup.pieces)
	assert_true(result.is_complete, str(result.reasons))
	assert_eq(result.attribute_totals[ItemDefinition.ATTRIBUTE_MIRROR], 8)
	assert_eq(_total_price(setup.pieces), 82)


func test_goldfish_baseline_solution_costs_96_and_has_lamp_lead() -> void:
	var setup := _solution(&"goldfish", [
		[&"special_fishbone", Vector2i(0, 1), 0],
		[&"fast_fries", Vector2i(2, 1), 3],
		[&"flower_roots", Vector2i(5, 2), 1],
		[&"record_headphones", Vector2i(3, 0), 2],
		[&"toy_blocks", Vector2i(3, 3), 3],
		[&"book_period", Vector2i(7, 1), 0],
	])
	var result := PuzzleRules.evaluate(setup.task, setup.pieces)
	assert_true(result.is_complete, str(result.reasons))
	assert_eq(result.attribute_totals[ItemDefinition.ATTRIBUTE_LAMP], 9)
	assert_eq(result.attribute_totals[ItemDefinition.ATTRIBUTE_MIRROR], 8)
	assert_eq(_total_price(setup.pieces), 96)


func test_tape_baseline_solution_costs_120() -> void:
	var setup := _solution(&"tape", [
		[&"special_tape", Vector2i(5, 0), 0],
		[&"flower_roots", Vector2i(0, 0), 0],
		[&"fast_fries", Vector2i(1, 2), 0],
		[&"book_clipping", Vector2i(5, 2), 0],
		[&"record_extension", Vector2i(1, 3), 3],
		[&"book_bookmark", Vector2i(1, 0), 0],
		[&"toy_blocks", Vector2i(3, 0), 1],
	])
	var result := PuzzleRules.evaluate(setup.task, setup.pieces)
	assert_true(result.is_complete, str(result.reasons))
	assert_eq(_total_price(setup.pieces), 120)


func test_missing_special_item_blocks_completion() -> void:
	var task := DemoCatalog.task_by_id(&"teddy")
	var pieces: Array[PuzzlePieceState] = []
	var result := PuzzleRules.evaluate(task, pieces)
	assert_false(result.is_complete)
	assert_false(result.has_required_special)


func test_overlap_and_outside_cells_are_reported() -> void:
	var task := DemoCatalog.task_by_id(&"teddy")
	var first := _placed_piece(1, &"book_manga", Vector2i(0, 0), 0)
	var second := _placed_piece(2, &"toy_blocks", Vector2i(0, 0), 0)
	var outside := _placed_piece(3, &"book_period", Vector2i(-1, 0), 0)
	var pieces: Array[PuzzlePieceState] = [first, second, outside]
	var result := PuzzleRules.evaluate(task, pieces)
	assert_gt(result.overlap_cells.size(), 0)
	assert_gt(result.outside_cells.size(), 0)


func _solution(task_id: StringName, placements: Array) -> Dictionary:
	var pieces: Array[PuzzlePieceState] = []
	var uid := 1
	for placement in placements:
		pieces.append(_placed_piece(uid, placement[0], placement[1], placement[2]))
		uid += 1
	return {
		"task": DemoCatalog.task_by_id(task_id),
		"pieces": pieces,
	}


func _placed_piece(uid: int, item_id: StringName, position: Vector2i, rotation: int) -> PuzzlePieceState:
	var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))
	piece.location = PuzzlePieceState.Location.BOARD
	piece.grid_position = position
	piece.rotation_steps = rotation
	return piece


func _total_price(pieces: Array[PuzzlePieceState]) -> int:
	var total := 0
	for piece in pieces:
		total += piece.definition.price
	return total

