extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_talking_unlocks_teddy_before_it_can_be_bought() -> void:
	assert_eq(GameState.toy_transaction.available_stock(&"special_teddy"), 0)
	var talk := GameState.talk_to_owner(DemoCatalog.STORE_TOY)
	assert_true(talk.ok)
	assert_eq(talk.task_id, &"teddy")
	assert_true(GameState.is_task_unlocked(&"teddy"))
	assert_eq(GameState.toy_transaction.available_stock(&"special_teddy"), 1)

	var teddy := GameState.toy_transaction.add_to_cart(&"special_teddy").piece as PuzzlePieceState
	_place_piece(teddy, &"teddy", Vector2i(1, 1))
	var checkout := GameState.checkout_store(DemoCatalog.STORE_TOY)
	assert_true(checkout.ok)
	assert_eq(GameState.wallet.money, 78)
	assert_true(GameState.purchased_special_items.has(&"special_teddy"))
	assert_false(GameState.talk_to_owner(DemoCatalog.STORE_TOY).ok)


func test_buying_special_does_not_unlock_a_task_and_wrong_task_is_rejected() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	GameState._sync_special_stock()
	var teddy := GameState.toy_transaction.add_to_cart(&"special_teddy").piece as PuzzlePieceState
	_place_piece(teddy, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	var result := GameState.checkout_store(DemoCatalog.STORE_TOY)
	assert_false(result.ok)
	assert_eq(result.reason, GameState.RESULT_INVALID_SPECIAL_TASK)
	assert_eq(GameState.wallet.money, 100)


func test_five_store_transactions_share_wallet_and_unique_piece_ids() -> void:
	var book := GameState.transaction_for_store(DemoCatalog.STORE_BOOK)
	var toy := GameState.transaction_for_store(DemoCatalog.STORE_TOY)
	var book_piece := book.add_to_cart(&"book_period").piece as PuzzlePieceState
	var toy_piece := toy.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(book_piece, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	_place_piece(toy_piece, DemoCatalog.DAILY_TASK_ID, Vector2i(1, 0))
	assert_true(GameState.checkout_store(DemoCatalog.STORE_BOOK).ok)
	assert_true(GameState.checkout_store(DemoCatalog.STORE_TOY).ok)
	assert_eq(GameState.wallet.money, 80)
	assert_ne(book_piece.piece_uid, toy_piece.piece_uid)
	assert_eq(book_piece.ownership, PuzzlePieceState.Ownership.OWNED)
	assert_eq(toy_piece.ownership, PuzzlePieceState.Ownership.OWNED)


func test_closed_store_cannot_checkout() -> void:
	var record := GameState.transaction_for_store(DemoCatalog.STORE_RECORD)
	var needle := record.add_to_cart(&"record_needle").piece as PuzzlePieceState
	_place_piece(needle, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	var result := GameState.checkout_store(DemoCatalog.STORE_RECORD)
	assert_false(result.ok)
	assert_eq(result.reason, &"store_closed")
	assert_eq(GameState.wallet.money, 100)
	assert_eq(record.cart_count(), 1)


func test_daily_goal_must_be_submitted_before_advance_and_is_consumed_afterward() -> void:
	var blocked := GameState.advance_day()
	assert_false(blocked.ok)
	assert_eq(blocked.reason, GameState.RESULT_DAILY_INCOMPLETE)
	assert_eq(GameState.day, 1)

	_fill_daily_goal(&"book_period")
	var submitted := GameState.submit_daily_goal()
	assert_true(submitted.ok)
	assert_eq(submitted.result_key, &"daily.result.fog")
	var daily_piece_count := GameState.pieces.size()
	var advanced := GameState.advance_day()
	assert_true(advanced.ok)
	assert_eq(advanced.consumed_count, daily_piece_count)
	assert_eq(GameState.day, 2)
	assert_eq(GameState.wallet.money, 200)
	assert_true(GameState.pieces.is_empty())
	assert_false(GameState.daily_goal.submitted)
	assert_eq(GameState.daily_goal.template_id, &"daily_tue")


func test_organizer_and_pending_purchase_each_block_advance_day() -> void:
	_fill_daily_goal(&"book_period")
	assert_true(GameState.submit_daily_goal().ok)
	var organizer_piece := _new_piece(90, &"toy_marble")
	organizer_piece.location = PuzzlePieceState.Location.ORGANIZER
	organizer_piece.task_id = &"teddy"
	GameState.pieces.append(organizer_piece)
	assert_eq(GameState.advance_day().reason, GameState.RESULT_ORGANIZER_NOT_EMPTY)
	GameState.pieces.erase(organizer_piece)

	var pending := GameState.toy_transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(pending, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	assert_eq(GameState.advance_day().reason, GameState.RESULT_PENDING_PURCHASE)
	assert_eq(GameState.day, 1)


func test_advance_preserves_owned_story_layout() -> void:
	var story_piece := _new_piece(50, &"toy_blocks")
	_place_piece(story_piece, &"teddy", Vector2i(3, 3))
	GameState.pieces.append(story_piece)
	_fill_daily_goal(&"book_period")
	assert_true(GameState.submit_daily_goal().ok)
	assert_true(GameState.advance_day().ok)
	assert_eq(GameState.pieces, [story_piece])
	assert_eq(story_piece.task_id, &"teddy")
	assert_eq(story_piece.grid_position, Vector2i(3, 3))


func test_three_events_unlock_by_talk_and_complete_in_order() -> void:
	var fast_food := GameState.transaction_for_store(DemoCatalog.STORE_FAST_FOOD)
	var record := GameState.transaction_for_store(DemoCatalog.STORE_RECORD)
	assert_eq(GameState.toy_transaction.available_stock(&"special_teddy"), 0)
	assert_eq(fast_food.available_stock(&"special_fishbone"), 0)
	assert_eq(record.available_stock(&"special_tape"), 0)

	assert_true(GameState.talk_to_owner(DemoCatalog.STORE_TOY).ok)
	var teddy := GameState.toy_transaction.add_to_cart(&"special_teddy").piece as PuzzlePieceState
	_place_piece(teddy, &"teddy", Vector2i(1, 1))
	assert_true(GameState.checkout_store(DemoCatalog.STORE_TOY).ok)
	_fill_task_with_monominoes(&"teddy", &"toy_marble")
	assert_true(GameState.submit_task(&"teddy").ok)
	assert_eq(GameState.world_stage, 1)
	assert_eq(fast_food.available_stock(&"special_fishbone"), 0)

	assert_true(GameState.talk_to_owner(DemoCatalog.STORE_FAST_FOOD).ok)
	assert_eq(fast_food.available_stock(&"special_fishbone"), 1)
	var fishbone := fast_food.add_to_cart(&"special_fishbone").piece as PuzzlePieceState
	_place_piece(fishbone, &"goldfish", Vector2i(1, 1))
	assert_true(GameState.checkout_store(DemoCatalog.STORE_FAST_FOOD).ok)
	_fill_task_with_monominoes(&"goldfish", &"fast_sugar")
	assert_true(GameState.submit_task(&"goldfish").ok)
	assert_eq(GameState.world_stage, 2)
	assert_eq(record.available_stock(&"special_tape"), 0)

	_fill_daily_goal(&"book_period")
	assert_true(GameState.submit_daily_goal().ok)
	assert_true(GameState.advance_day().ok)
	record = GameState.transaction_for_store(DemoCatalog.STORE_RECORD)
	assert_true(GameState.talk_to_owner(DemoCatalog.STORE_RECORD).ok)
	var tape := record.add_to_cart(&"special_tape").piece as PuzzlePieceState
	_place_piece(tape, &"tape", Vector2i(0, 0))
	assert_true(GameState.checkout_store(DemoCatalog.STORE_RECORD).ok)
	_fill_task_with_monominoes(&"tape", &"book_period")
	assert_true(GameState.submit_task(&"tape").ok)
	assert_eq(GameState.world_stage, 3)
	assert_true(GameState.all_tasks_completed())
	assert_false(GameState.submit_task(&"tape").ok)


func test_incomplete_event_does_not_consume_or_advance_world() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	var special := _new_piece(1, &"special_teddy")
	_place_piece(special, &"teddy", Vector2i(1, 1))
	GameState.pieces.append(special)
	var result := GameState.submit_task(&"teddy")
	assert_false(result.ok)
	assert_eq(result.reason, &"incomplete")
	assert_eq(GameState.pieces, [special])
	assert_eq(GameState.world_stage, 0)


func test_completed_event_consumes_only_its_own_board() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	var daily_piece := _new_piece(80, &"book_period")
	_place_piece(daily_piece, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	GameState.pieces.append(daily_piece)
	_fill_teddy_with_shop_solution()
	var result := GameState.submit_task(&"teddy")
	assert_true(result.ok)
	assert_eq(result.consumed_count, 5)
	assert_eq(GameState.pieces, [daily_piece])
	assert_true(GameState.is_task_completed(&"teddy"))


func _fill_teddy_with_shop_solution() -> void:
	var rows := [
		[1, &"special_teddy", Vector2i(1, 1), 0],
		[2, &"toy_blocks", Vector2i(0, 0), 1],
		[3, &"toy_blocks", Vector2i(3, 0), 2],
		[4, &"toy_blocks", Vector2i(0, 3), 2],
		[5, &"toy_blocks", Vector2i(3, 3), 1],
	]
	for row in rows:
		var piece := _new_piece(row[0], row[1])
		_place_piece(piece, &"teddy", row[2], row[3])
		GameState.pieces.append(piece)


func _fill_daily_goal(item_id: StringName) -> void:
	var task := GameState.daily_task()
	var uid := 100
	for cell in task.mask_cells:
		var piece := _new_piece(uid, item_id)
		_place_piece(piece, task.id, cell)
		GameState.pieces.append(piece)
		uid += 1


func _fill_task_with_monominoes(task_id: StringName, filler_item_id: StringName) -> void:
	var task := DemoCatalog.task_by_id(task_id)
	var occupied: Dictionary = {}
	for piece in GameState.pieces:
		if piece.task_id == task_id:
			for cell in piece.occupied_cells():
				occupied[cell] = true
	var uid := 200
	for cell in task.mask_cells:
		if occupied.has(cell):
			continue
		var filler := _new_piece(uid, filler_item_id)
		_place_piece(filler, task_id, cell)
		GameState.pieces.append(filler)
		uid += 1


func _new_piece(uid: int, item_id: StringName) -> PuzzlePieceState:
	return PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))


func _place_piece(
	piece: PuzzlePieceState,
	task_id: StringName,
	position: Vector2i,
	rotation_steps: int = 0
) -> void:
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = task_id
	piece.grid_position = position
	piece.rotation_steps = rotation_steps
