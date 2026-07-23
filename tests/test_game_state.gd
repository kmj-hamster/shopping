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


func test_five_store_transactions_share_wallet_and_unique_piece_ids() -> void:
	var book := GameState.transaction_for_store(DemoCatalog.STORE_BOOK)
	var toy := GameState.transaction_for_store(DemoCatalog.STORE_TOY)
	var book_piece := book.add_to_cart(&"book_period").piece as PuzzlePieceState
	var toy_piece := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState

	assert_true(GameState.checkout_store(DemoCatalog.STORE_BOOK).ok)
	assert_true(GameState.checkout_store(DemoCatalog.STORE_TOY).ok)
	assert_eq(GameState.wallet.money, 80)
	assert_ne(book_piece.piece_uid, toy_piece.piece_uid)
	assert_eq(book_piece.ownership, PuzzlePieceState.Ownership.OWNED)
	assert_eq(toy_piece.ownership, PuzzlePieceState.Ownership.OWNED)


func test_closed_store_cannot_checkout() -> void:
	var record := GameState.transaction_for_store(DemoCatalog.STORE_RECORD)
	assert_true(record.add_to_cart(&"record_needle").ok)

	var result := GameState.checkout_store(DemoCatalog.STORE_RECORD)

	assert_false(result.ok)
	assert_eq(result.reason, &"store_closed")
	assert_eq(GameState.wallet.money, 100)
	assert_eq(record.cart_count(), 1)


func test_advance_day_adds_income_refreshes_stock_and_preserves_owned_layout() -> void:
	var toy := GameState.toy_transaction
	var owned := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	assert_true(GameState.checkout_toy_store().ok)
	owned.location = PuzzlePieceState.Location.BOARD
	owned.grid_position = Vector2i(4, 3)
	var original_uid := owned.piece_uid
	assert_eq(toy.stock_remaining[&"toy_marble"], 0)

	var result := GameState.advance_day()

	assert_eq(result.day, 2)
	assert_eq(result.weekday_key, &"weekday.tue")
	assert_eq(GameState.wallet.money, 190)
	assert_eq(GameState.toy_transaction.stock_remaining[&"toy_marble"], 1)
	assert_eq(GameState.pieces.size(), 1)
	assert_eq(GameState.pieces[0].piece_uid, original_uid)
	assert_eq(GameState.pieces[0].location, PuzzlePieceState.Location.BOARD)
	assert_eq(GameState.pieces[0].grid_position, Vector2i(4, 3))


func test_advance_day_cancels_pending_items_without_losing_owned_items() -> void:
	var toy := GameState.toy_transaction
	var owned := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	assert_true(GameState.checkout_toy_store().ok)
	assert_true(toy.add_to_cart(&"toy_blocks").ok)

	var result := GameState.advance_day()

	assert_eq(result.cancelled_count, 1)
	assert_eq(GameState.pieces, [owned])
	assert_eq(GameState.wallet.money, 190)


func test_twenty_one_day_advances_keep_calendar_money_and_inventory_stable() -> void:
	var toy := GameState.toy_transaction
	var owned := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	assert_true(GameState.checkout_toy_store().ok)

	for _index in range(21):
		GameState.advance_day()

	assert_eq(GameState.day, 22)
	assert_eq(ShopSchedule.weekday_key(GameState.day), &"weekday.mon")
	assert_eq(GameState.wallet.money, 2190)
	assert_eq(GameState.pieces, [owned])


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
