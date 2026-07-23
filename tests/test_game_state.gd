extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_buying_teddy_unlocks_event_once_and_keeps_shared_money() -> void:
	assert_true(GameState.toy_transaction.add_to_cart(&"special_teddy").ok)

	var result := GameState.checkout_toy_store()

	assert_true(result.ok)
	assert_eq(GameState.wallet.money, 78)
	assert_true(GameState.is_task_unlocked(&"teddy"))
	assert_true(GameState.purchased_special_items.has(&"special_teddy"))
	assert_false(GameState.toy_transaction.add_to_cart(&"special_teddy").ok)


func test_incomplete_event_does_not_consume_or_advance_world() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	var special := _placed_piece(1, &"special_teddy", Vector2i(1, 1))
	GameState.pieces.append(special)

	var result := GameState.submit_teddy_event()

	assert_false(result.ok)
	assert_eq(result.reason, &"incomplete")
	assert_eq(GameState.pieces, [special])
	assert_eq(GameState.world_stage, 0)


func test_completed_event_consumes_board_and_advances_world_once() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	_fill_teddy_with_shop_solution()

	var result := GameState.submit_teddy_event()

	assert_true(result.ok)
	assert_eq(result.consumed_count, 5)
	assert_true(GameState.pieces.is_empty())
	assert_true(GameState.is_task_completed(&"teddy"))
	assert_eq(GameState.world_stage, 1)
	assert_false(GameState.submit_teddy_event().ok)


func _fill_teddy_with_shop_solution() -> void:
	GameState.pieces.append(_placed_piece(1, &"special_teddy", Vector2i(1, 1)))
	GameState.pieces.append(_placed_piece(2, &"toy_blocks", Vector2i(0, 0), 1))
	GameState.pieces.append(_placed_piece(3, &"toy_blocks", Vector2i(3, 0), 2))
	GameState.pieces.append(_placed_piece(4, &"toy_blocks", Vector2i(0, 3), 2))
	GameState.pieces.append(_placed_piece(5, &"toy_blocks", Vector2i(3, 3), 1))


func _placed_piece(
	uid: int,
	item_id: StringName,
	position: Vector2i,
	rotation_steps := 0
) -> PuzzlePieceState:
	var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))
	piece.location = PuzzlePieceState.Location.BOARD
	piece.grid_position = position
	piece.rotation_steps = rotation_steps
	return piece
