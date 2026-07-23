extends GutTest


func test_successful_checkout_deducts_money_stock_and_owns_every_cart_piece() -> void:
	var transaction := _toy_transaction(100)
	var marble := transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	var blocks := transaction.add_to_cart(&"toy_blocks").piece as PuzzlePieceState

	var result := transaction.checkout()

	assert_true(result.ok)
	assert_eq(transaction.money, 76)
	assert_eq(transaction.stock_remaining[&"toy_marble"], 0)
	assert_eq(transaction.stock_remaining[&"toy_blocks"], 3)
	assert_eq(marble.ownership, PuzzlePieceState.Ownership.OWNED)
	assert_eq(blocks.ownership, PuzzlePieceState.Ownership.OWNED)


func test_insufficient_funds_checkout_is_atomic() -> void:
	var transaction := _toy_transaction(10)
	var teddy := transaction.add_to_cart(&"special_teddy").piece as PuzzlePieceState
	var stock_before: Dictionary = transaction.stock_remaining.duplicate(true)

	var result := transaction.checkout()

	assert_false(result.ok)
	assert_eq(result.reason, ShopTransaction.RESULT_INSUFFICIENT_FUNDS)
	assert_eq(transaction.money, 10)
	assert_eq(transaction.stock_remaining, stock_before)
	assert_eq(teddy.ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)


func test_stock_failure_checkout_is_atomic() -> void:
	var transaction := _toy_transaction(100)
	var teddy := transaction.add_to_cart(&"special_teddy").piece as PuzzlePieceState
	transaction.stock_remaining[&"special_teddy"] = 0

	var result := transaction.checkout()

	assert_false(result.ok)
	assert_eq(result.reason, ShopTransaction.RESULT_OUT_OF_STOCK)
	assert_eq(transaction.money, 100)
	assert_eq(transaction.stock_remaining[&"special_teddy"], 0)
	assert_eq(teddy.ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)


func test_cart_reservations_limit_stock_before_checkout() -> void:
	var transaction := _toy_transaction(100)
	assert_true(transaction.add_to_cart(&"special_teddy").ok)

	var second := transaction.add_to_cart(&"special_teddy")

	assert_false(second.ok)
	assert_eq(second.reason, ShopTransaction.RESULT_OUT_OF_STOCK)
	assert_eq(transaction.available_stock(&"special_teddy"), 0)


func test_cancel_cart_preserves_owned_piece_and_its_board_position() -> void:
	var owned := PuzzlePieceState.new(8, DemoCatalog.item_by_id(&"book_bookmark"))
	owned.location = PuzzlePieceState.Location.BOARD
	owned.grid_position = Vector2i(3, 2)
	var pieces: Array[PuzzlePieceState] = [owned]
	var transaction := ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		100,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY),
		pieces
	)
	transaction.add_to_cart(&"toy_marble")

	assert_eq(transaction.cancel_cart(), 1)
	assert_eq(pieces, [owned])
	assert_eq(owned.location, PuzzlePieceState.Location.BOARD)
	assert_eq(owned.grid_position, Vector2i(3, 2))


func _toy_transaction(starting_money: int) -> ShopTransaction:
	return ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		starting_money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY)
	)
