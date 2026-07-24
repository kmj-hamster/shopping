extends GutTest


func test_owned_normal_piece_can_be_staged_for_eighty_percent() -> void:
	var setup := _transaction_with_piece(&"toy_marble")
	var piece := setup.piece as PuzzlePieceState
	var transaction := setup.transaction as RecycleTransaction
	var result := transaction.stage(piece)
	assert_true(result.ok)
	assert_eq(result.total, 8)
	assert_eq(piece.location, PuzzlePieceState.Location.RECYCLE_CART)
	assert_eq(transaction.cart_count(), 1)
	assert_eq(transaction.cart_total(), 8)


func test_pending_and_special_items_are_rejected_without_mutation() -> void:
	var normal_setup := _transaction_with_piece(&"toy_marble")
	var pending := normal_setup.piece as PuzzlePieceState
	pending.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE
	var normal_transaction := normal_setup.transaction as RecycleTransaction
	assert_eq(normal_transaction.stage(pending).reason, RecycleTransaction.RESULT_NOT_OWNED)
	assert_eq(pending.location, PuzzlePieceState.Location.BOARD)

	var special_setup := _transaction_with_piece(&"special_teddy")
	var special := special_setup.piece as PuzzlePieceState
	var special_transaction := special_setup.transaction as RecycleTransaction
	assert_eq(special_transaction.stage(special).reason, RecycleTransaction.RESULT_SPECIAL_ITEM)
	assert_eq(special.location, PuzzlePieceState.Location.BOARD)


func test_cancel_restores_exact_source_layout() -> void:
	var setup := _transaction_with_piece(&"toy_blocks")
	var piece := setup.piece as PuzzlePieceState
	var transaction := setup.transaction as RecycleTransaction
	piece.task_id = &"teddy"
	piece.grid_position = Vector2i(3, 2)
	piece.rotation_steps = 3
	assert_true(transaction.stage(piece).ok)
	assert_eq(transaction.cancel(), 1)
	assert_eq(piece.location, PuzzlePieceState.Location.BOARD)
	assert_eq(piece.task_id, &"teddy")
	assert_eq(piece.grid_position, Vector2i(3, 2))
	assert_eq(piece.rotation_steps, 3)
	assert_eq(transaction.wallet.money, 100)


func test_piece_dragged_out_of_recycle_cart_is_not_restored_by_cancel() -> void:
	var setup := _transaction_with_piece(&"toy_blocks")
	var piece := setup.piece as PuzzlePieceState
	var transaction := setup.transaction as RecycleTransaction
	assert_true(transaction.stage(piece).ok)
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = &"teddy"
	piece.grid_position = Vector2i(1, 2)
	assert_eq(transaction.cart_count(), 0)
	assert_eq(transaction.cancel(), 0)
	assert_eq(piece.task_id, &"teddy")
	assert_eq(piece.grid_position, Vector2i(1, 2))


func test_checkout_pays_combined_floor_values_and_consumes_pieces() -> void:
	var wallet := PlayerWallet.new(100)
	var marble := _owned_piece(1, &"toy_marble", Vector2i.ZERO)
	var blocks := _owned_piece(2, &"toy_blocks", Vector2i(1, 0))
	var pieces: Array[PuzzlePieceState] = [marble, blocks]
	var transaction := RecycleTransaction.new(pieces, wallet)
	assert_true(transaction.stage(marble).ok)
	assert_true(transaction.stage(blocks).ok)
	var result := transaction.checkout()
	assert_true(result.ok)
	assert_eq(result.count, 2)
	assert_eq(result.total, 19)
	assert_eq(wallet.money, 119)
	assert_true(pieces.is_empty())
	assert_eq(transaction.checkout().reason, RecycleTransaction.RESULT_EMPTY)


func test_game_state_blocks_advance_until_recycle_cart_is_resolved() -> void:
	GameState.reset_demo()
	var piece := _owned_piece(10, &"toy_marble", Vector2i.ZERO)
	GameState.pieces.append(piece)
	assert_true(GameState.stage_recycle_piece(piece).ok)
	GameState.daily_goal.submitted = true
	assert_eq(GameState.advance_day().reason, GameState.RESULT_RECYCLE_PENDING)
	assert_eq(GameState.cancel_recycling(), 1)
	assert_true(GameState.advance_day().ok)


func _transaction_with_piece(item_id: StringName) -> Dictionary:
	var piece := _owned_piece(1, item_id, Vector2i.ZERO)
	var pieces: Array[PuzzlePieceState] = [piece]
	return {
		"piece": piece,
		"transaction": RecycleTransaction.new(pieces, PlayerWallet.new(100)),
	}


func _owned_piece(
	uid: int,
	item_id: StringName,
	position: Vector2i
) -> PuzzlePieceState:
	var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))
	piece.ownership = PuzzlePieceState.Ownership.OWNED
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = DemoCatalog.EMPTY_BAG_TASK_ID
	piece.grid_position = position
	return piece
