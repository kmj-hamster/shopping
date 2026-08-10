extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_item_cards_and_slots_keep_height_while_becoming_narrower() -> void:
	assert_eq(CardHandCard.CARD_SIZE, Vector2(88, 146))
	assert_eq(QuestTaskSlot.CARD_SIZE, CardHandCard.CARD_SIZE)

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


func test_reordering_a_hovered_hand_card_rebuilds_after_drag_finishes() -> void:
	var main := await _spawn_main()
	var hand := main.hand_bar
	var first_wrapper := hand.card_row.get_child(0) as Control
	var dragged_view := first_wrapper.get_child(0) as CardHandCard
	var dragged_card := dragged_view.card
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
	assert_false(is_instance_valid(dragged_view))
	assert_true(hand.card_views.has(dragged_card.instance_id))
	assert_true(is_instance_valid(hand.card_views[dragged_card.instance_id]))


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
