extends GutTest


func before_each() -> void:
	GameState.reset_demo()


func test_main_opens_map_with_global_hand_and_single_task_window() -> void:
	var main = await _spawn_main()

	assert_eq(main.current_view, &"map")
	assert_true(main.current_screen is MallMapScreen)
	assert_eq(main.current_screen.store_hotspots.size(), 6)
	assert_true(main.protagonist_interface is SlotPlayerInterface)
	assert_eq(main.protagonist_interface.commerce, GameState.slot_commerce)
	assert_not_null(main.protagonist_interface.bag_button.texture_normal)
	assert_not_null(main.protagonist_interface.bag_button.texture_hover)
	assert_false(main.protagonist_interface.task_window.visible)
	assert_eq(_task_window_count(main.protagonist_interface), 1)


func test_bag_opens_same_task_window_across_map_and_shop() -> void:
	var main = await _spawn_main()
	var task_window: SlotTaskWindow = main.protagonist_interface.task_window
	main.protagonist_interface.toggle_task_window()
	assert_true(task_window.visible)

	main._on_shop_requested(DemoCatalog.STORE_TOY)
	await get_tree().process_frame

	assert_eq(main.current_view, &"shop")
	assert_eq(main.protagonist_interface.task_window, task_window)
	assert_true(task_window.visible)
	assert_eq(main.protagonist_interface.view_context, &"shop")
	assert_eq(_task_window_count(main.protagonist_interface), 1)


func test_formal_shop_uses_independent_shelves_and_global_hand_only() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_TOY)
	await get_tree().process_frame
	var shop := main.current_screen as SlotShopScreen
	var transaction := GameState.slot_commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	var first_slot_id := transaction.shelf_slots[0].slot_id

	assert_not_null(shop)
	assert_eq(shop.store_id, SlotDemoCatalog.STORE_TOY)
	assert_null(shop.hand_bar)
	assert_eq(shop.shelf_buttons.size(), 6)
	shop._on_shelf_pressed(first_slot_id)
	assert_true(GameState.slot_commerce.inventory.is_empty())
	shop._on_checkout_pressed()
	await get_tree().process_frame

	assert_eq(GameState.slot_commerce.inventory.size(), 1)
	assert_eq(main.protagonist_interface.hand_bar.card_views.size(), 1)
	assert_true(transaction.shelf_slot(first_slot_id).is_empty())


func test_slot_focus_highlights_current_shop_and_global_hand() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_FAST_FOOD)
	await get_tree().process_frame
	var shop := main.current_screen as SlotShopScreen
	var rule := SlotDemoCatalog.wish_by_id(&"wish_hungry").slot_rule

	main.protagonist_interface._on_slot_rule_focused(rule)

	assert_eq(shop.highlight_rule, rule)
	assert_eq(main.protagonist_interface.hand_bar.highlight_rule, rule)


func test_recycling_hotspot_opens_new_card_recycle_screen() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_RECYCLING)
	await get_tree().process_frame
	var recycle := main.current_screen as SlotRecycleScreen

	assert_not_null(recycle)
	assert_eq(recycle.commerce, GameState.slot_commerce)
	assert_eq(recycle.commerce.recycle_transaction, GameState.slot_commerce.recycle_transaction)
	assert_null(recycle.hand_bar)
	assert_eq(main.protagonist_interface.view_context, &"shop")


func test_closed_store_stays_on_map_and_shows_next_open_day() -> void:
	var main = await _spawn_main()
	main._on_shop_requested(DemoCatalog.STORE_RECORD)
	await get_tree().process_frame

	assert_eq(main.current_view, &"map")
	assert_true(main.current_screen.notice_label.visible)
	assert_string_contains(
		main.current_screen.notice_label.text,
		str(TranslationServer.translate(&"store.record")),
	)
	assert_string_contains(
		main.current_screen.notice_label.text,
		str(TranslationServer.translate(&"weekday.tue")),
	)


func test_next_night_without_two_confirmations_uses_map_notice() -> void:
	var main = await _spawn_main()

	main.current_screen._on_next_day_pressed()

	assert_eq(GameState.slot_commerce.day, 1)
	assert_true(main.current_screen.notice_panel.visible)
	assert_eq(
		main.current_screen.notice_label.text,
		TranslationServer.translate(&"slot.map.next_day.incomplete"),
	)


func test_confirmed_wishes_run_black_transition_and_start_day_two() -> void:
	var main = await _spawn_main()
	var commerce := GameState.slot_commerce
	_complete_first_night(commerce)
	var map := main.current_screen as MallMapScreen
	map.transition_fade_seconds = 0.0
	map.transition_result_seconds = 0.0
	map.transition_dawn_seconds = 0.0
	map.transition_return_seconds = 0.0

	map._on_next_day_pressed()
	for index in range(20):
		await get_tree().process_frame

	assert_eq(commerce.day, 2)
	assert_eq(commerce.wallet.money, 188)
	assert_true(commerce.inventory.is_empty())
	assert_eq(
		commerce.activity_state.active_daily_wish_ids,
		[&"wish_stay_awake", &"wish_remember"],
	)
	assert_false(map.night_overlay.visible)
	assert_true(main.protagonist_interface.visible)
	assert_false(main.transition_in_progress)


func test_active_synthesis_stays_on_map_and_uses_specific_notice() -> void:
	var main = await _spawn_main()
	var commerce := GameState.slot_commerce
	_complete_first_night(commerce)
	var recipe_cards: Array[CardItemState] = [
		CardItemState.new(500, &"record_fluorescent_single"),
		CardItemState.new(501, &"toy_glass_marble"),
		CardItemState.new(502, &"fast_hash_brown"),
	]
	commerce.inventory.append_array(recipe_cards)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"sound", recipe_cards[0]
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"shell", recipe_cards[1]
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"recipe_night_radio", &"tuning", recipe_cards[2]
	).ok)
	assert_true(commerce.begin_synthesis(&"recipe_night_radio", 100.0).ok)

	main.current_screen._on_next_day_pressed()

	assert_eq(commerce.day, 1)
	assert_false(main.transition_in_progress)
	assert_eq(
		main.current_screen.notice_label.text,
		TranslationServer.translate(&"slot.map.next_day.synthesis_active"),
	)


func test_six_map_hotspots_do_not_overlap() -> void:
	var main = await _spawn_main()
	var hotspots: Array = main.current_screen.store_hotspots.values()
	for first_index in range(hotspots.size()):
		var first := hotspots[first_index] as Button
		var first_rect := Rect2(first.position, first.size)
		for second_index in range(first_index + 1, hotspots.size()):
			var second := hotspots[second_index] as Button
			var second_rect := Rect2(second.position, second.size)
			assert_false(
				first_rect.intersects(second_rect),
				"%s overlaps %s" % [first.name, second.name],
			)


func test_demo_complete_page_uses_balloon_request_branch_echo() -> void:
	var main = await _spawn_main()
	var map := main.current_screen as MallMapScreen
	GameState.slot_commerce.story_flags[&"balloon_hug"] = &"comfort"

	map.show_demo_complete()

	assert_true(map.demo_complete_panel.visible)
	assert_eq(
		map.demo_complete_body.text,
		TranslationServer.translate(&"demo.complete.body.balloon_comfort"),
	)


func _spawn_main():
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate()
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _task_window_count(interface: SlotPlayerInterface) -> int:
	return interface.root.get_children().filter(
		func(child: Node) -> bool: return child is SlotTaskWindow
	).size()


func _complete_first_night(commerce: SlotCommerceState) -> void:
	var fast_food := commerce.transaction_for_store(SlotDemoCatalog.STORE_FAST_FOOD)
	assert_true(fast_food.select_shelf_slot(fast_food.shelf_slots[0].slot_id).ok)
	var hash_brown := commerce.checkout_store(SlotDemoCatalog.STORE_FAST_FOOD).purchased[0] \
		as CardItemState
	var flower := commerce.transaction_for_store(SlotDemoCatalog.STORE_FLOWER)
	assert_true(flower.select_shelf_slot(flower.shelf_slots[0].slot_id).ok)
	var sunflower := commerce.checkout_store(SlotDemoCatalog.STORE_FLOWER).purchased[0] \
		as CardItemState
	assert_true(commerce.activity_state.assign_card(
		&"wish_hungry", &"hungry", hash_brown
	).ok)
	assert_true(commerce.activity_state.assign_card(
		&"wish_bedside", &"bedside", sunflower
	).ok)
	assert_true(commerce.activity_state.confirm_daily_wish(&"wish_hungry").ok)
	assert_true(commerce.activity_state.confirm_daily_wish(&"wish_bedside").ok)
