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


func test_same_shop_scene_can_checkout_bookstore_inventory() -> void:
	var lab := await _spawn_lab(DemoCatalog.STORE_BOOK)
	lab._on_product_add_requested(&"book_period")
	lab._on_checkout_pressed()
	await get_tree().process_frame

	assert_eq(lab.store_id, DemoCatalog.STORE_BOOK)
	assert_eq(lab.transaction.store_id, DemoCatalog.STORE_BOOK)
	assert_eq(GameState.wallet.money, 90)
	assert_eq(GameState.pieces.size(), 1)
	assert_eq(GameState.pieces[0].definition.id, &"book_period")


func test_task_tabs_isolate_multiple_unfinished_tasks() -> void:
	GameState.unlocked_tasks[&"teddy"] = true
	GameState.unlocked_tasks[&"goldfish"] = true
	var lab := await _spawn_lab(DemoCatalog.STORE_BOOK)

	assert_true(lab.task_tabs.visible)
	assert_eq(lab.task_tabs.tab_count, 2)
	assert_eq(lab.task.id, &"teddy")

	lab._on_task_tab_changed(1)

	assert_eq(lab.task.id, &"goldfish")
	assert_eq(lab.puzzle_board.task.id, &"goldfish")


func _spawn_lab(store_id: StringName = DemoCatalog.STORE_TOY) -> Node:
	var packed := load("res://scenes/shop_lab/shop_lab.tscn") as PackedScene
	var lab := packed.instantiate()
	lab.store_id = store_id
	add_child_autoqfree(lab)
	await get_tree().process_frame
	return lab
