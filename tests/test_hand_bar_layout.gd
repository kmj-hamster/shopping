extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.LEGACY_MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_all_cards_and_slots_use_the_new_paper_proportion() -> void:
	assert_eq(CardHandCard.CARD_SIZE, Vector2(90, 110))
	assert_eq(QuestTaskSlot.CARD_SIZE, CardHandCard.CARD_SIZE)
	var main := await _spawn_main()
	assert_eq(main.hand_bar.custom_minimum_size.y, QuestHandBar.HAND_HEIGHT)
	for view in main.hand_bar.card_views.values():
		var card_view := view as CardHandCard
		assert_eq(card_view.size, CardHandCard.CARD_SIZE)
		assert_eq(
			card_view.card_background.texture.resource_path,
			"res://resources/ui/shell/hand-card.png",
		)
	var first_card := main.hand_bar.card_views.values()[0] as CardHandCard
	assert_almost_eq(
		first_card.get_global_rect().end.y,
		get_viewport().get_visible_rect().end.y,
		1.0,
	)
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
	assert_eq(location_slot.custom_minimum_size, CardHandCard.CARD_SIZE)
	assert_eq(location_slot.card_view.size, CardHandCard.CARD_SIZE)

	var synthesis_slot := QuestSynthesisMaterialSlot.new()
	add_child_autoqfree(synthesis_slot)
	await get_tree().process_frame
	assert_eq(synthesis_slot.custom_minimum_size, QuestTaskSlot.CARD_SIZE)
	assert_eq(synthesis_slot.size, QuestTaskSlot.CARD_SIZE)


func test_items_and_live_persona_cards_share_one_hand_without_entering_inventory() -> void:
	var main := await _spawn_main()
	var hand := main.hand_bar
	var inventory_count := main.state.inventory.size()
	assert_eq(hand.active_tab, QuestHandBar.TAB_ITEMS)
	assert_null(hand.find_child("ItemTabButton", true, false))
	assert_null(hand.find_child("PersonaTabButton", true, false))
	assert_eq(hand.card_views.size(), inventory_count + 4)

	hand.show_tab(QuestHandBar.TAB_PERSONAS)
	assert_eq(hand.active_tab, QuestHandBar.TAB_PERSONAS)
	assert_eq(hand.card_views.size(), inventory_count + 4)
	for shape_id in PersonaCardCatalog.PERSONA_SHAPES:
		var card := PersonaCardCatalog.card_for_shape(shape_id)
		var view := hand.card_views[card.instance_id] as CardHandCard
		assert_true(view.definition.has_property(CardPropertySet.PROPERTY_PERSONA))
		assert_eq(
			view.definition.property_value(shape_id),
			int(main.state.protagonist_shape_levels[shape_id]),
		)
		assert_true(view.value_label.visible)
		assert_eq(view.value_label.text, str(main.state.protagonist_shape_levels[shape_id]))
	assert_eq(main.state.inventory.size(), inventory_count)
	var first_shape := hand.persona_shape_order[0]
	var first_persona_card := PersonaCardCatalog.card_for_shape(first_shape)
	var first_persona_view := hand.card_views[first_persona_card.instance_id] as CardHandCard
	first_persona_view._begin_drag_visual()
	hand._drop_data(
		Vector2(hand.size.x - 1.0, hand.size.y * 0.5),
		{
			"kind": &"card_item",
			"card": first_persona_card,
			"grab_offset": CardHandCard.CARD_SIZE * 0.5,
		},
	)
	first_persona_view._end_drag_visual(true)
	assert_eq(hand.persona_shape_order.back(), first_shape)
	assert_same(hand.card_views[first_persona_card.instance_id], first_persona_view)
	assert_true(first_persona_view.visible)

	var persona_rule := CardSlotRule.new()
	persona_rule.id = &"persona_test"
	persona_rule.required_all = [CardPropertySet.PROPERTY_PERSONA]
	main._on_rule_focused(persona_rule)
	assert_eq(hand.active_tab, QuestHandBar.TAB_PERSONAS)
	var item_rule := CardSlotRule.new()
	item_rule.id = &"item_test"
	item_rule.required_all = [&"food"]
	main._on_rule_focused(item_rule)
	assert_eq(hand.active_tab, QuestHandBar.TAB_ITEMS)


func test_persona_cards_use_colored_symbols_on_frosted_glass() -> void:
	var main := await _spawn_main()
	var hand := main.hand_bar
	var expected_symbols := {
		CardPropertySet.SHAPE_LIGHT: "res://resources/ui/synthesis/shape/light.png",
		CardPropertySet.SHAPE_TEAR: "res://resources/ui/synthesis/shape/tear.png",
		CardPropertySet.SHAPE_DREAM: "res://resources/ui/synthesis/shape/dream.png",
		CardPropertySet.SHAPE_SLEEP: "res://resources/ui/synthesis/shape/sleep.png",
	}
	for shape_id in PersonaCardCatalog.PERSONA_SHAPES:
		var card := PersonaCardCatalog.card_for_shape(shape_id)
		var view := hand.card_views[card.instance_id] as CardHandCard
		assert_true(view.persona_glass.visible, shape_id)
		assert_true(view.persona_glass.material is ShaderMaterial, shape_id)
		assert_eq(
			(view.persona_glass.material as ShaderMaterial).shader.resource_path,
			"res://resources/shaders/frosted_dialogue.gdshader",
			shape_id,
		)
		assert_almost_eq(
			view.persona_glass.self_modulate.a,
			CardHandCard.PERSONA_GLASS_ALPHA,
			0.001,
			shape_id,
		)
		assert_almost_eq(
			view.card_background.self_modulate.a,
			CardHandCard.PERSONA_PAPER_ALPHA,
			0.001,
			shape_id,
		)
		assert_true(view.shape_icon_background.visible, shape_id)
		assert_eq(view.item_image.texture.resource_path, expected_symbols[shape_id], shape_id)
		assert_eq(view.item_image.self_modulate, Color.BLACK, shape_id)
		assert_eq(view.item_image.offset_left, CardHandCard.SHAPE_ICON_INSET, shape_id)
		assert_eq(view.item_image.offset_top, CardHandCard.SHAPE_ICON_INSET, shape_id)
		assert_eq(view.item_image.offset_right, -CardHandCard.SHAPE_ICON_INSET, shape_id)
		assert_eq(view.item_image.offset_bottom, -CardHandCard.SHAPE_ICON_INSET, shape_id)
		var icon_style := view.shape_icon_background.get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(icon_style, shape_id)
		assert_eq(icon_style.bg_color, ShapeVisuals.COLORS[shape_id], shape_id)

	var dream_card := PersonaCardCatalog.card_for_shape(
		CardPropertySet.SHAPE_DREAM
	)
	var dream_view := hand.card_views[dream_card.instance_id] as CardHandCard
	main._show_item(dream_view.definition)
	assert_eq(
		main.detail_popup.item_image.texture.resource_path,
		expected_symbols[CardPropertySet.SHAPE_DREAM],
	)
	assert_eq(main.detail_popup.item_image.self_modulate, Color.BLACK)
	assert_eq(
		main.detail_popup.item_image.custom_minimum_size,
		Vector2.ONE * ItemDetailPopup.LARGE_ICON_SIDE,
	)
	var popup_icon_style := main.detail_popup.item_frame.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(
		popup_icon_style.bg_color,
		ShapeVisuals.color(CardPropertySet.SHAPE_DREAM),
	)

	var item_card := main.state.inventory[0] as CardItemState
	var item_view := hand.card_views[item_card.instance_id] as CardHandCard
	assert_false(item_view.persona_glass.visible)
	assert_false(item_view.shape_icon_background.visible)
	assert_eq(item_view.card_background.self_modulate, Color.WHITE)
	assert_eq(item_view.item_image.self_modulate, Color.WHITE)


func test_disease_cards_use_smaller_rounded_black_icon_tiles() -> void:
	var definition := CardItemDefinition.new()
	definition.id = &"visual_disease"
	definition.display_name_key = &"expedition.disease.white_flower.name"
	definition.image = load("res://resources/items/white_flower.png") as Texture2D
	definition.property_set = CardPropertySet.new()
	definition.property_set.tags = [CardPropertySet.PROPERTY_DISEASE]
	var view := CardHandCard.new()
	view.setup(CardItemState.new(1, definition.id), definition)
	add_child_autoqfree(view)
	await get_tree().process_frame

	assert_false(view.persona_glass.visible)
	assert_true(view.shape_icon_background.visible)
	assert_eq(view.shape_icon_background.offset_left, CardHandCard.DISEASE_BACKGROUND_INSET)
	assert_eq(view.shape_icon_background.offset_top, CardHandCard.DISEASE_BACKGROUND_INSET)
	assert_eq(view.item_image.offset_left, CardHandCard.DISEASE_ICON_INSET)
	assert_eq(view.item_image.offset_top, CardHandCard.DISEASE_ICON_INSET)
	var icon_style := view.shape_icon_background.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(icon_style)
	assert_eq(icon_style.bg_color, Color.BLACK)
	assert_eq(icon_style.corner_radius_top_left, 5)
	assert_eq(icon_style.corner_radius_top_right, 5)
	assert_eq(icon_style.corner_radius_bottom_left, 5)
	assert_eq(icon_style.corner_radius_bottom_right, 5)


func test_card_titles_shrink_then_wrap_without_splitting_english_words() -> void:
	var original_locale := LocaleManager.current_locale
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	var view := CardHandCard.new()
	add_child_autoqfree(view)
	await get_tree().process_frame

	view.setup(null, _title_probe_definition("Tea"), false)
	assert_eq(
		view.title_label.get_theme_font_size("font_size"),
		CardHandCard.ITEM_TITLE_FONT_SIZE,
	)
	assert_eq(view.title_label.max_lines_visible, 1)
	assert_eq(view.title_label.autowrap_mode, TextServer.AUTOWRAP_OFF)

	view.setup(null, _title_probe_definition("Kaleidoscope Tape"), false)
	var reduced_size := view.title_label.get_theme_font_size("font_size")
	assert_lt(reduced_size, CardHandCard.ITEM_TITLE_FONT_SIZE)
	assert_gte(
		reduced_size,
		CardHandCard.ITEM_TITLE_FONT_SIZE - CardHandCard.TITLE_MAX_FONT_REDUCTION,
	)
	assert_eq(view.title_label.max_lines_visible, 1)

	view.setup(
		null,
		_title_probe_definition(
			"A Very Long Card Name With Several Complete English Words"
		),
		false,
	)
	assert_eq(
		view.title_label.get_theme_font_size("font_size"),
		CardHandCard.ITEM_TITLE_FONT_SIZE - CardHandCard.TITLE_MAX_FONT_REDUCTION,
	)
	assert_eq(view.title_label.max_lines_visible, 2)
	assert_eq(view.title_label.autowrap_mode, TextServer.AUTOWRAP_WORD)
	assert_eq(
		view.title_label.text_overrun_behavior,
		TextServer.OVERRUN_TRIM_ELLIPSIS,
	)
	assert_eq(view.title_host.custom_minimum_size.y, CardHandCard.TITLE_HOST_HEIGHT)
	LocaleManager.set_locale(original_locale, false)


func test_overflowing_hand_overlaps_and_hovered_card_receives_full_space() -> void:
	var main := await _spawn_main()
	for index in 10:
		main.state.grant_item(&"jasmine")
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


func test_reordering_uses_the_dragged_card_overlap_instead_of_the_cursor_edge() -> void:
	var main := await _spawn_main()
	var hand := main.hand_bar
	await get_tree().process_frame
	var hand_cards := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.location == CardItemState.Location.HAND
	)
	var dragged := hand_cards[0] as CardItemState
	var second := hand_cards[1] as CardItemState
	var third := hand_cards[2] as CardItemState
	var second_view := hand.card_views[second.instance_id] as CardHandCard
	var third_view := hand.card_views[third.instance_id] as CardHandCard
	assert_eq(hand.card_row.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(hand.card_scroll.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_ne(hand.card_row.get_parent().mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_ne(hand.card_scroll.get_parent().mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_ne(hand.card_scroll.get_parent().get_parent().mouse_filter, Control.MOUSE_FILTER_STOP)
	var desired_center := third_view.get_global_rect().get_center().x - 20.0
	var dragged_left := desired_center - CardHandCard.CARD_SIZE.x * 0.5
	assert_lt(dragged_left, second_view.get_global_rect().end.x)
	assert_gt(dragged_left + CardHandCard.CARD_SIZE.x, third_view.get_global_rect().position.x)
	var grab_offset := Vector2(80.0, CardHandCard.CARD_SIZE.y * 0.5)
	var pointer_global_x := dragged_left + grab_offset.x
	var drop_position := Vector2(
		pointer_global_x - hand.get_global_rect().position.x,
		hand.size.y * 0.5,
	)

	hand._drop_data(drop_position, {
		"kind": &"card_item",
		"card": dragged,
		"grab_offset": grab_offset,
	})
	var reordered := main.state.inventory.filter(
		func(card: CardItemState) -> bool: return card.location == CardItemState.Location.HAND
	)
	assert_same(reordered[0], second)
	assert_same(reordered[1], dragged)
	assert_same(reordered[2], third)
	assert_true(hand._has_point(Vector2(-QuestHandBar.REORDER_DROP_MARGIN.x + 1.0, 70.0)))
	assert_false(hand._has_point(Vector2(-QuestHandBar.REORDER_DROP_MARGIN.x - 1.0, 70.0)))


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


func _title_probe_definition(title: String) -> CardItemDefinition:
	var definition := CardItemDefinition.new()
	definition.id = StringName(title.to_snake_case())
	definition.display_name_key = StringName(title)
	definition.property_set = CardPropertySet.new()
	return definition
