extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_shop_lab_starts_with_sparse_counter_state() -> void:
	var lab := await _spawn_lab()

	assert_eq(lab.transaction.money, 100)
	assert_eq(lab.transaction.cart_count(), 0)
	assert_eq(lab.pieces.size(), 0)
	assert_true(lab.puzzle_board.return_removed_to_inventory)
	assert_false(lab.board_center.visible)
	assert_eq(lab.feedback_label.text, TranslationServer.translate(&"shop.feedback.ready"))


func test_add_and_checkout_update_counter_without_partial_state() -> void:
	var lab := await _spawn_lab()

	lab._on_product_add_requested(&"toy_marble")
	await get_tree().process_frame
	assert_eq(lab.transaction.cart_count(), 1)
	assert_eq(lab.transaction.money, 100)
	assert_string_contains(lab.cart_label.text, "10")

	lab._on_checkout_pressed()
	await get_tree().process_frame
	assert_eq(lab.transaction.cart_count(), 0)
	assert_eq(lab.transaction.money, 90)
	assert_eq(lab.transaction.stock_remaining[&"toy_marble"], 0)


func test_special_checkout_reveals_event_board_and_submit_action() -> void:
	var lab := await _spawn_lab()
	lab._on_product_add_requested(&"special_teddy")
	lab._on_checkout_pressed()
	await get_tree().process_frame

	assert_true(GameState.is_task_unlocked(&"teddy"))
	assert_true(lab.board_center.visible)
	assert_eq(lab.talk_button.text, TranslationServer.translate(&"shop.submit"))


func _spawn_lab() -> Node:
	var packed := load("res://scenes/shop_lab/shop_lab.tscn") as PackedScene
	var lab := packed.instantiate()
	add_child_autoqfree(lab)
	await get_tree().process_frame
	return lab
