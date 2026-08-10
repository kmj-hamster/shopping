extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_item_cards_and_slots_keep_height_while_becoming_narrower() -> void:
	assert_eq(CardHandCard.CARD_SIZE, Vector2(88, 146))
	assert_eq(QuestTaskSlot.CARD_SIZE, CardHandCard.CARD_SIZE)
	var main := await _spawn_main()
	for view in main.hand_bar.card_views.values():
		assert_eq((view as CardHandCard).size, CardHandCard.CARD_SIZE)
	var task := main.state.task_instance_for_definition(&"girl_order")
	var rule := QuestArcCatalog.task_by_id(task.definition_id).slot_rules[0] as CardSlotRule
	var fries := main.state.inventory[0] as CardItemState
	assert_true(main.state.assign_card(task.instance_id, rule.id, fries).ok)
	var task_slot := QuestTaskSlot.new()
	task_slot.setup(main.state, task, rule)
	add_child_autoqfree(task_slot)
	await get_tree().process_frame
	assert_eq(task_slot.size, CardHandCard.CARD_SIZE)
	assert_eq(task_slot.card_view.size, CardHandCard.CARD_SIZE)

	var location_slot := QuestLocationUnlockSlot.new()
	add_child_autoqfree(location_slot)
	await get_tree().process_frame
	assert_eq(location_slot.custom_minimum_size, Vector2(100, 166))

	var synthesis_slot := QuestSynthesisMaterialSlot.new()
	add_child_autoqfree(synthesis_slot)
	await get_tree().process_frame
	assert_eq(synthesis_slot.custom_minimum_size, Vector2(117, 176))


func test_overflowing_hand_overlaps_and_hovered_card_receives_full_space() -> void:
	var main := await _spawn_main()
	for index in 10:
		main.state.grant_item(&"sunflower")
	await get_tree().process_frame
	await get_tree().process_frame

	var hand := main.hand_bar
	assert_true(hand.overlap_active)
	var wrappers := hand.card_row.get_children()
	assert_gt(wrappers.size(), 2)
	var compressed := false
	for wrapper in wrappers:
		if wrapper is Control and wrapper.custom_minimum_size.x < CardHandCard.CARD_SIZE.x:
			compressed = true
			break
	assert_true(compressed)

	var hovered_index := int(wrappers.size() / 2)
	var hovered_wrapper := wrappers[hovered_index] as Control
	var hovered_view := hovered_wrapper.get_child(0) as CardHandCard
	hand._on_card_hovered(hovered_view.card.instance_id)
	assert_eq(hand.hovered_card_id, hovered_view.card.instance_id)
	assert_eq(hovered_view.z_index, QuestHandBar.HOVER_Z_INDEX)
	assert_gte(
		hovered_wrapper.custom_minimum_size.x,
		CardHandCard.CARD_SIZE.x + QuestHandBar.HOVER_CARD_GAP,
	)

	hand._on_card_unhovered(hovered_view.card.instance_id)
	assert_eq(hand.hovered_card_id, -1)


func test_reordering_a_hovered_hand_card_preserves_every_view() -> void:
	var main := await _spawn_main()
	var hand := main.hand_bar
	var first_wrapper := hand.card_row.get_child(0) as Control
	var dragged_view := first_wrapper.get_child(0) as CardHandCard
	var dragged_card := dragged_view.card
	var original_views := hand.card_views.duplicate()
	var original_view_count := hand.card_views.size()
	hand._on_card_hovered(dragged_card.instance_id)
	dragged_view._begin_drag_visual()

	hand._drop_data(
		Vector2(hand.size.x - 1.0, hand.size.y * 0.5),
		{"kind": &"card_item", "card": dragged_card},
	)
	dragged_view._end_drag_visual(true)
	await get_tree().process_frame
	await get_tree().process_frame

	var hand_cards := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.location == CardItemState.Location.HAND
	)
	assert_same(hand_cards.back(), dragged_card)
	assert_true(is_instance_valid(dragged_view))
	assert_true(hand.card_views.has(dragged_card.instance_id))
	assert_same(hand.card_views[dragged_card.instance_id], dragged_view)
	assert_true(dragged_view.visible)
	assert_almost_eq(dragged_view.self_modulate.a, 1.0, 0.001)
	assert_eq(dragged_view.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(hand.card_views.size(), original_view_count)
	for instance_id in original_views:
		assert_same(hand.card_views[instance_id], original_views[instance_id])


func test_reordering_hand_cards_is_correct_in_both_directions() -> void:
	var main := await _spawn_main()
	var hand_cards: Array = main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.location == CardItemState.Location.HAND
	)
	assert_gte(hand_cards.size(), 3)
	var first := hand_cards[0] as CardItemState
	var middle := hand_cards[1] as CardItemState
	var last := hand_cards[-1] as CardItemState

	assert_true(main.state.reorder_hand_card(first, hand_cards.size() - 1))
	var reordered: Array = main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.location == CardItemState.Location.HAND
	)
	assert_same(reordered[-1], first)
	assert_same(reordered[0], middle)

	assert_true(main.state.reorder_hand_card(last, 0))
	reordered = main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.location == CardItemState.Location.HAND
	)
	assert_same(reordered[0], last)
	assert_same(reordered[-1], first)


func test_assigning_one_card_only_removes_that_card_view() -> void:
	var main := await _spawn_main()
	var hand := main.hand_bar
	var task := main.state.task_instance_for_definition(&"girl_order")
	var card := main.state.inventory[0] as CardItemState
	var original_views := hand.card_views.duplicate()

	assert_true(main.state.assign_card(task.instance_id, &"food", card).ok)
	assert_false(hand.card_views.has(card.instance_id))
	for instance_id in original_views:
		if instance_id != card.instance_id:
			assert_same(hand.card_views[instance_id], original_views[instance_id])


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
