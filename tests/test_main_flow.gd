extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_main_opens_new_map_with_global_card_hand() -> void:
	var main := await _spawn_main()
	assert_true(main is QuestMain)
	assert_true(main.current_screen is QuestMapScreen)
	assert_eq((main.current_screen as QuestMapScreen).store_hotspots.size(), 6)
	assert_eq(main.state, GameState.quest_state)
	assert_eq(main.hand_bar.state, GameState.quest_state)
	assert_eq(main.hand_bar.card_views.size(), 0)


func test_shop_shelf_is_selected_before_checkout_and_card_then_enters_hand() -> void:
	var main := await _spawn_main()
	main._show_shop(&"fast_food")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	var transaction := GameState.quest_state.transaction_for_store(&"fast_food")
	var slot_id := transaction.shelf_slots[0].slot_id
	shop._on_shelf_pressed(slot_id)
	assert_eq(transaction.cart_count(), 1)
	assert_true(GameState.quest_state.inventory.is_empty())
	shop._on_checkout_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameState.quest_state.inventory.size(), 1)
	assert_eq(GameState.quest_state.wallet.money, 8)
	assert_eq(main.hand_bar.card_views.size(), 1)
	assert_true(transaction.shelf_slot(slot_id).is_empty())


func test_left_bookmarks_toggle_one_task_window_and_confirm_without_consuming() -> void:
	var main := await _spawn_main()
	assert_eq(main.task_dock.bookmark_column.get_child_count(), 2)
	var care := GameState.quest_state.task_instance_for_definition(&"care_hungry")
	main.task_dock._toggle_task(care.instance_id)
	await get_tree().process_frame
	var first_window := main.task_dock.task_window
	assert_not_null(first_window)
	assert_eq(main.task_dock.open_task_instance_id, care.instance_id)
	var card := GameState.quest_state.grant_item(&"fast_hash_brown")
	await get_tree().process_frame
	var slot := first_window.slots_row.get_child(0) as QuestTaskSlot
	assert_true(slot._can_drop_data(Vector2.ZERO, _drag_data(card)))
	slot._drop_data(Vector2.ZERO, _drag_data(card))
	await get_tree().process_frame
	assert_eq(card.location, CardItemState.Location.ACTIVITY_SLOT)
	assert_false(main.hand_bar.card_views.has(card.instance_id))
	main.task_dock.task_window._on_action_pressed()
	assert_true(care.confirmed)
	assert_has(GameState.quest_state.inventory, card)
	main.task_dock._toggle_task(care.instance_id)
	assert_null(main.task_dock.task_window)
	assert_eq(main.task_dock.open_task_instance_id, 0)


func test_focused_task_slot_highlights_matching_owned_cards_and_shop_goods() -> void:
	var main := await _spawn_main()
	var food := GameState.quest_state.grant_item(&"fast_hash_brown")
	var flower := GameState.quest_state.grant_item(&"flower_sunflower")
	await get_tree().process_frame
	var care := GameState.quest_state.task_instance_for_definition(&"care_hungry")
	var definition := QuestArcCatalog.task_by_id(care.definition_id)
	var rule := definition.slot_rules[0] as CardSlotRule
	main._on_rule_focused(rule)
	assert_true((main.hand_bar.card_views[food.instance_id] as CardHandCard).rule_match_highlighted)
	assert_false((main.hand_bar.card_views[flower.instance_id] as CardHandCard).rule_match_highlighted)
	main._show_shop(&"fast_food")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	assert_eq(shop.highlight_rule, rule)
	assert_eq(shop.shelf_buttons.size(), 6)


func test_locked_map_store_only_accepts_its_exact_key_card() -> void:
	var main := await _spawn_main()
	var map := main.current_screen as QuestMapScreen
	var record_hotspot := map.store_hotspots[&"record"] as QuestStoreHotspot
	var sunflower := GameState.quest_state.grant_item(&"flower_sunflower")
	var moth := GameState.quest_state.grant_item(&"toy_windup_moth")
	assert_false(record_hotspot._can_drop_data(Vector2.ZERO, _drag_data(sunflower)))
	assert_true(record_hotspot._can_drop_data(Vector2.ZERO, _drag_data(moth)))
	map._on_unlock_requested(&"record", moth)
	assert_true(GameState.quest_state.is_store_unlocked(&"record"))
	assert_null(GameState.quest_state.card_by_instance_id(moth.instance_id))
	assert_not_null(GameState.quest_state.card_by_instance_id(sunflower.instance_id))


func test_next_day_is_allowed_without_confirmed_tasks_and_finishes_empty_arc() -> void:
	var main := await _spawn_main()
	main.arc_fade_seconds = 0.0
	main.arc_result_seconds = 0.0
	main.arc_empty_seconds = 0.0
	main.arc_new_day_seconds = 0.0
	main._on_next_day_requested()
	for index in 12:
		await get_tree().process_frame
	assert_eq(GameState.quest_state.day, 2)
	assert_null(GameState.quest_state.pending_arc)
	assert_false(main.transition_in_progress)
	assert_true(main.hand_bar.visible)


func test_recycle_screen_returns_actual_purchase_price() -> void:
	var main := await _spawn_main()
	var state := GameState.quest_state
	var transaction := state.transaction_for_store(&"flower")
	assert_true(transaction.select_shelf_slot(transaction.shelf_slots[0].slot_id).ok)
	var card := state.checkout_store(&"flower").purchased[0] as CardItemState
	assert_eq(state.wallet.money, 8)
	main._show_shop(&"recycling")
	await get_tree().process_frame
	var recycle := main.current_screen as QuestShopScreen
	assert_true(state.stage_recycle_card(card).ok)
	recycle._on_checkout_pressed()
	assert_eq(state.wallet.money, 10)
	assert_true(state.inventory.is_empty())


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _drag_data(card: CardItemState) -> Dictionary:
	return {"kind": &"card_item", "card": card, "source": &"hand"}
