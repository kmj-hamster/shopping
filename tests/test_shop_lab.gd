extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_shop_keeps_goods_left_owner_right_without_inventory_or_task_tabs() -> void:
	var shop := await _spawn_shop()
	assert_eq(shop.transaction.money, 100)
	assert_eq(shop.transaction.cart_count(), 0)
	assert_eq(shop.shelf_list.get_child_count(), 4)
	assert_true(shop.owner_portrait.visible)
	assert_null(shop.find_child("ShelfTabs", true, false))
	assert_null(shop.find_child("TaskTabs", true, false))
	assert_eq(shop.feedback_label.text, TranslationServer.translate(&"shop.feedback.ready"))
	var checkout_dock := shop.find_child("CheckoutDock", true, false) as Control
	var owner_side := shop.find_child("OwnerSide", true, false) as Control
	assert_not_null(checkout_dock)
	assert_true(checkout_dock.is_ancestor_of(shop.checkout_button))
	assert_true(owner_side.is_ancestor_of(shop.talk_button))
	assert_lt(shop.checkout_button.global_position.x, owner_side.global_position.x)


func test_unplaced_purchase_is_rejected_then_placed_purchase_is_atomic() -> void:
	var shop := await _spawn_shop()
	var marble := shop.transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	shop._on_checkout_pressed()
	await get_tree().process_frame
	assert_eq(shop.transaction.money, 100)
	assert_eq(marble.ownership, PuzzlePieceState.Ownership.PENDING_PURCHASE)
	assert_eq(shop.feedback_label.text, TranslationServer.translate(&"shop.feedback.unplaced"))

	_place_piece(marble, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	shop._on_checkout_pressed()
	await get_tree().process_frame
	assert_eq(shop.transaction.cart_count(), 0)
	assert_eq(shop.transaction.money, 90)
	assert_eq(shop.transaction.stock_remaining[&"toy_marble"], 0)
	assert_eq(marble.ownership, PuzzlePieceState.Ownership.OWNED)


func test_pending_purchase_can_be_dragged_from_grid_back_to_goods() -> void:
	var shop := await _spawn_shop()
	var marble := shop.transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(marble, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	var data := {
		"kind": &"puzzle_piece",
		"source": &"board",
		"candidate": marble.copy_for_drag(),
		"original": marble,
	}
	assert_true(shop.shelf_drop_zone.can_return_drag(data))
	assert_true(shop.shelf_drop_zone.request_return(data))
	await get_tree().process_frame
	assert_false(GameState.pieces.has(marble))
	assert_eq(shop.transaction.cart_count(), 0)
	assert_eq(shop.transaction.available_stock(&"toy_marble"), 1)
	assert_eq(
		shop.feedback_label.text,
		TranslationServer.translate(&"shop.feedback.returned")
	)


func test_goods_reject_owned_piece_and_new_product_template() -> void:
	var shop := await _spawn_shop()
	var owned := PuzzlePieceState.new(90, DemoCatalog.item_by_id(&"toy_marble"))
	GameState.pieces.append(owned)
	assert_false(shop.shelf_drop_zone.can_return_drag({
		"kind": &"puzzle_piece",
		"source": &"board",
		"candidate": owned.copy_for_drag(),
		"original": owned,
	}))
	assert_false(shop.shelf_drop_zone.can_return_drag({
		"kind": &"puzzle_piece",
		"source": &"shop_template",
		"candidate": shop.transaction.make_drag_candidate(&"toy_marble"),
		"original": null,
	}))


func test_talking_unlocks_event_and_reveals_special_product() -> void:
	var shop := await _spawn_shop()
	assert_false(GameState.is_task_unlocked(&"teddy"))
	assert_eq(shop.shelf_list.get_child_count(), 4)
	shop._on_talk_pressed()
	await get_tree().process_frame
	assert_true(GameState.is_task_unlocked(&"teddy"))
	assert_eq(shop.shelf_list.get_child_count(), 5)
	assert_eq(
		shop.feedback_label.text,
		TranslationServer.translate(&"shop.feedback.unlocked_teddy")
	)


func test_same_shop_scene_can_checkout_bookstore_piece_on_daily_grid() -> void:
	var shop := await _spawn_shop(DemoCatalog.STORE_BOOK)
	var period := shop.transaction.add_to_cart(&"book_period").piece as PuzzlePieceState
	_place_piece(period, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	shop._on_checkout_pressed()
	await get_tree().process_frame
	assert_eq(shop.store_id, DemoCatalog.STORE_BOOK)
	assert_eq(shop.transaction.store_id, DemoCatalog.STORE_BOOK)
	assert_eq(GameState.wallet.money, 90)
	assert_eq(GameState.pieces, [period])


func test_next_day_is_blocked_until_daily_goal_is_submitted() -> void:
	var shop := await _spawn_shop()
	shop._on_next_day_pressed()
	assert_eq(GameState.day, 1)
	assert_eq(
		shop.feedback_label.text,
		TranslationServer.translate(&"shop.feedback.daily_required")
	)


func test_leave_confirmation_x_keeps_cart_and_direct_leave_returns_it() -> void:
	var shop := await _spawn_shop()
	var marble := shop.transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(marble, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	var leave_count := [0]
	shop.leave_requested.connect(func() -> void: leave_count[0] += 1)
	shop._on_leave_pressed()
	assert_true(shop.exit_confirmation.visible)
	assert_gt(shop.exit_confirmation_layer.layer, 20)
	assert_eq(shop.exit_confirmation_mode, shop.CONFIRM_LEAVE)
	assert_eq(leave_count[0], 0)
	assert_true(GameState.pieces.has(marble))
	assert_eq(
		shop.exit_confirmation_title.text,
		TranslationServer.translate(&"shop.leave_pending.title")
	)
	shop._on_exit_close_pressed()
	assert_false(shop.exit_confirmation.visible)
	assert_true(GameState.pieces.has(marble))
	shop._on_leave_pressed()
	shop._on_exit_cancelled()
	assert_eq(leave_count[0], 1)
	assert_false(GameState.pieces.has(marble))
	assert_eq(shop.transaction.available_stock(&"toy_marble"), 1)


func test_checkout_and_leave_pays_for_cart_and_keeps_piece() -> void:
	var shop := await _spawn_shop()
	var marble := shop.transaction.add_to_cart(&"toy_marble").piece as PuzzlePieceState
	_place_piece(marble, DemoCatalog.DAILY_TASK_ID, Vector2i.ZERO)
	var leave_count := [0]
	shop.leave_requested.connect(func() -> void: leave_count[0] += 1)
	shop._on_leave_pressed()
	assert_eq(
		shop.exit_confirm_button.text,
		TranslationServer.translate(&"shop.leave_pending.checkout")
	)
	assert_eq(
		shop.exit_cancel_button.text,
		TranslationServer.translate(&"shop.leave_pending.direct")
	)
	shop._on_exit_confirmed()
	assert_eq(leave_count[0], 1)
	assert_eq(GameState.wallet.money, 90)
	assert_true(GameState.pieces.has(marble))
	assert_eq(marble.ownership, PuzzlePieceState.Ownership.OWNED)


func test_leaving_without_unpaid_items_needs_no_confirmation() -> void:
	var shop := await _spawn_shop()
	var leave_count := [0]
	shop.leave_requested.connect(func() -> void: leave_count[0] += 1)
	shop._on_leave_pressed()
	assert_eq(leave_count[0], 1)
	assert_false(shop.exit_confirmation.visible)


func _spawn_shop(store_id: StringName = DemoCatalog.STORE_TOY) -> Node:
	var packed := load("res://scenes/shop_lab/shop_lab.tscn") as PackedScene
	var shop := packed.instantiate()
	shop.store_id = store_id
	add_child_autoqfree(shop)
	await get_tree().process_frame
	return shop


func _place_piece(piece: PuzzlePieceState, task_id: StringName, position: Vector2i) -> void:
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = task_id
	piece.grid_position = position
