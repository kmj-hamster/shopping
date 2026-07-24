extends GutTest


func test_successful_checkout_deducts_money_stock_and_owns_every_cart_piece() -> void:
	var transaction := _toy_transaction(100)
	var marble := transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	var blocks := transaction.add_to_cart(&"toy_blocks").piece as PuzzlePieceState
	_place_for_checkout(marble, Vector2i.ZERO)
	_place_for_checkout(blocks, Vector2i(1, 0))

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
	_place_for_checkout(teddy, Vector2i.ZERO, &"teddy")
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
	_place_for_checkout(teddy, Vector2i.ZERO, &"teddy")
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


func test_remove_from_cart_only_accepts_this_store_pending_piece() -> void:
	var pieces: Array[PuzzlePieceState] = []
	var wallet := PlayerWallet.new(100)
	var toy := ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		wallet.money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY),
		pieces,
		wallet
	)
	var book := ShopTransaction.new(
		DemoCatalog.STORE_BOOK,
		wallet.money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_BOOK),
		pieces,
		wallet
	)
	var toy_piece := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	var book_piece := book.add_to_cart(&"book_period").piece as PuzzlePieceState
	assert_false(toy.can_remove_from_cart(book_piece))
	assert_false(toy.remove_from_cart(book_piece))
	toy_piece.ownership = PuzzlePieceState.Ownership.OWNED
	assert_false(toy.can_remove_from_cart(toy_piece))
	toy_piece.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE
	assert_true(toy.remove_from_cart(toy_piece))
	assert_eq(pieces, [book_piece])


func test_shared_piece_array_keeps_each_store_cart_isolated() -> void:
	var pieces: Array[PuzzlePieceState] = []
	var wallet := PlayerWallet.new(100)
	var toy := ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		wallet.money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY),
		pieces,
		wallet
	)
	var book := ShopTransaction.new(
		DemoCatalog.STORE_BOOK,
		wallet.money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_BOOK),
		pieces,
		wallet
	)
	var toy_piece := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	var book_piece := book.add_to_cart(&"book_period").piece as PuzzlePieceState
	_place_for_checkout(toy_piece, Vector2i.ZERO)
	_place_for_checkout(book_piece, Vector2i(1, 0))

	assert_eq(toy.cart_count(), 1)
	assert_eq(book.cart_count(), 1)
	assert_eq(toy.cart_total(), 10)
	assert_true(toy.checkout().ok)
	assert_eq(toy_piece.ownership, PuzzlePieceState.Ownership.OWNED)
	assert_eq(book_piece.ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)
	assert_eq(book.cancel_cart(), 1)
	assert_eq(pieces, [toy_piece])


func test_checkout_rejects_unplaced_piece_without_mutation() -> void:
	var transaction := _toy_transaction(100)
	var piece := transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	var result := transaction.checkout()
	assert_false(result.ok)
	assert_eq(result.reason, ShopTransaction.RESULT_UNPLACED)
	assert_eq(transaction.money, 100)
	assert_eq(piece.ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)


func test_any_occupied_organizer_blocks_checkout() -> void:
	var transaction := _toy_transaction(100)
	var piece := transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	piece.location = PuzzlePieceState.Location.ORGANIZER
	piece.task_id = DemoCatalog.DAILY_TASK_ID
	var result := transaction.checkout()
	assert_false(result.ok)
	assert_eq(result.reason, ShopTransaction.RESULT_ORGANIZER_NOT_EMPTY)
	assert_eq(transaction.money, 100)


func _toy_transaction(starting_money: int) -> ShopTransaction:
	return ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		starting_money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY)
	)


func _place_for_checkout(
	piece: PuzzlePieceState,
	position: Vector2i,
	task_id: StringName = DemoCatalog.DAILY_TASK_ID
) -> void:
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = task_id
	piece.grid_position = position
