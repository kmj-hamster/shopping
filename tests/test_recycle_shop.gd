extends GutTest

var original_locale: String


func before_each() -> void:
	original_locale = LocaleManager.current_locale
	GameState.reset_demo()


func after_each() -> void:
	LocaleManager.set_locale(original_locale, false)


func test_drop_zone_shows_staged_piece_as_a_draggable_card() -> void:
	var shop := await _spawn_shop()
	var piece := _owned_piece(1, &"toy_marble")
	GameState.pieces.append(piece)
	var data := _drag_data(piece)
	assert_true(shop.drop_zone.request_recycle(data))
	await get_tree().process_frame
	assert_eq(piece.location, PuzzlePieceState.Location.RECYCLE_CART)
	assert_eq(shop.transaction.cart_count(), 1)
	assert_string_contains(shop.cart_label.text, "+¥8")
	assert_eq(shop.recycle_list.get_child_count(), 1)
	var card := shop.recycle_list.get_child(0) as RecyclePieceCard
	assert_eq(card.piece, piece)
	assert_string_contains(card.meta_label.text, "+¥8")
	assert_true(card.has_method(&"_get_drag_data"))


func test_checkout_pays_and_removes_recycled_piece() -> void:
	var shop := await _spawn_shop()
	var piece := _owned_piece(2, &"toy_blocks")
	GameState.pieces.append(piece)
	shop._on_recycle_requested(piece)
	shop._on_checkout_pressed()
	await get_tree().process_frame
	assert_eq(GameState.wallet.money, 111)
	assert_false(GameState.pieces.has(piece))
	assert_eq(shop.recycle_list.get_child_count(), 0)
	assert_string_contains(shop.feedback_label.text, "+¥11")


func test_special_piece_returns_to_board_with_short_feedback() -> void:
	var shop := await _spawn_shop()
	var piece := _owned_piece(3, &"special_teddy")
	GameState.pieces.append(piece)
	shop._on_recycle_requested(piece)
	await get_tree().process_frame
	assert_eq(piece.location, PuzzlePieceState.Location.BOARD)
	assert_eq(shop.transaction.cart_count(), 0)
	assert_eq(
		shop.feedback_label.text,
		TranslationServer.translate(&"recycle.feedback.special")
	)


func test_leaving_cancels_recycling_and_restores_piece() -> void:
	var shop := await _spawn_shop()
	var piece := _owned_piece(4, &"toy_puzzle")
	piece.grid_position = Vector2i(4, 3)
	GameState.pieces.append(piece)
	shop._on_recycle_requested(piece)
	var leave_count := [0]
	shop.leave_requested.connect(func() -> void: leave_count[0] += 1)
	shop._on_leave_pressed()
	assert_eq(leave_count[0], 1)
	assert_eq(piece.location, PuzzlePieceState.Location.BOARD)
	assert_eq(piece.grid_position, Vector2i(4, 3))


func test_feedback_retranslates_when_locale_changes() -> void:
	LocaleManager.set_locale("zh_CN", false)
	var shop := await _spawn_shop()
	var piece := _owned_piece(5, &"special_teddy")
	GameState.pieces.append(piece)
	shop._on_recycle_requested(piece)
	assert_eq(shop.feedback_label.text, "它还牵着一条故事线。")
	LocaleManager.set_locale("en", false)
	await get_tree().process_frame
	assert_eq(shop.feedback_label.text, "A story is still tied to it.")


func _spawn_shop() -> RecycleShopScreen:
	var packed := load("res://scenes/recycle_shop/recycle_shop.tscn") as PackedScene
	var shop := packed.instantiate() as RecycleShopScreen
	add_child_autoqfree(shop)
	await get_tree().process_frame
	return shop


func _owned_piece(uid: int, item_id: StringName) -> PuzzlePieceState:
	var piece := PuzzlePieceState.new(uid, DemoCatalog.item_by_id(item_id))
	piece.ownership = PuzzlePieceState.Ownership.OWNED
	piece.location = PuzzlePieceState.Location.BOARD
	piece.task_id = DemoCatalog.EMPTY_BAG_TASK_ID
	piece.grid_position = Vector2i.ZERO
	return piece


func _drag_data(piece: PuzzlePieceState) -> Dictionary:
	return {
		"kind": &"puzzle_piece",
		"source": &"board",
		"candidate": piece.copy_for_drag(),
		"original": piece,
		"grab_offset": Vector2i.ZERO,
		"preview": null,
	}
