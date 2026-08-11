extends GutTest


func before_each() -> void:
	GameState.reset_game()


func test_narrative_click_finishes_then_advances_and_result_returns_to_hand() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	var sunflower := _card_by_definition(main.state, &"sunflower")
	var soft_gauze := _card_by_definition(main.state, &"soft_gauze")
	assert_true(synthesis.stage_card(&"base", sunflower))
	assert_true(synthesis.stage_card(&"fuel", soft_gauze))
	assert_true(main.state.select_synthesis_persona(&"reverie"))
	assert_true(main.state.select_synthesis_candidate(&"recipe_midnight_rose"))
	synthesis._on_action_pressed()
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.NARRATIVE)
	assert_true(main.state.synthesis_persona_id.is_empty())
	assert_eq(
		PersonaMaskCatalog.card_for_persona(&"reverie").location,
		CardItemState.Location.HAND,
	)
	assert_null(synthesis.material_slots[2].card)
	assert_eq(synthesis.narrative_index, 0)
	assert_eq(synthesis.narrative_state, QuestSynthesisInterface.NarrativeState.FADING)
	var output := synthesis.pending_output
	assert_not_null(output)
	assert_true(main.hand_bar.temporarily_hidden_card_ids.has(output.instance_id))

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	synthesis._on_narrative_input(click)
	assert_eq(synthesis.narrative_state, QuestSynthesisInterface.NarrativeState.HOLDING)
	assert_almost_eq(synthesis.current_narrative_label.modulate.a, 1.0, 0.001)
	synthesis._on_narrative_input(click)
	assert_eq(synthesis.narrative_index, 1)
	assert_eq(synthesis.narrative_state, QuestSynthesisInterface.NarrativeState.FADING)

	synthesis._show_result()
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.RESULT)
	assert_eq(synthesis.result_layer.get_child_count(), 1)
	synthesis._reveal_result()
	assert_true(synthesis.result_revealed)
	assert_eq(
		synthesis.result_hint.text,
		TranslationServer.translate(&"demo.ui.synthesis.drag_result"),
	)
	synthesis._on_result_drag_finished(output, true)
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.DRAFT)
	assert_null(synthesis.pending_output)
	assert_false(main.hand_bar.temporarily_hidden_card_ids.has(output.instance_id))
	assert_true(main.hand_bar.card_views.has(output.instance_id))


func test_synthesis_controls_update_without_recreating_fixed_views() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface

	var base_slot := synthesis.material_slots[0]
	var fuel_slot := synthesis.material_slots[1]
	var mask_slot := synthesis.material_slots[2]
	var preallocated_base_card_view := base_slot.card_view
	var preallocated_mask_card_view := mask_slot.card_view
	var mask_card := PersonaMaskCatalog.card_for_persona(&"reverie")
	synthesis.reset_debug_update_counts()
	assert_true(synthesis.stage_card(&"mask", mask_card))
	assert_eq(main.state.synthesis_persona_id, &"reverie")
	assert_true(is_instance_valid(synthesis))
	assert_same(synthesis.material_slots[0], base_slot)
	assert_same(synthesis.material_slots[1], fuel_slot)
	assert_same(synthesis.material_slots[2], mask_slot)
	assert_same(mask_slot.card, mask_card)
	assert_same(mask_slot.card_view, preallocated_mask_card_view)
	assert_eq(int(synthesis.debug_update_counts.get(&"full", 0)), 0)
	assert_eq(int(synthesis.debug_update_counts.get(&"materials", 0)), 1)
	assert_eq(int(synthesis.debug_update_counts.get(&"totals", 0)), 1)
	assert_eq(int(synthesis.debug_update_counts.get(&"candidates", 0)), 1)
	assert_lt(synthesis.last_delta_update_usec, 16_000)

	var sunflower := _card_by_definition(main.state, &"sunflower")
	var soft_gauze := _card_by_definition(main.state, &"soft_gauze")
	synthesis.reset_debug_update_counts()
	assert_true(synthesis.stage_card(&"base", sunflower))
	var base_card_view := base_slot.card_view
	assert_same(base_card_view, preallocated_base_card_view)
	assert_eq(int(synthesis.debug_update_counts.get(&"materials", 0)), 1)
	assert_eq(int(synthesis.debug_update_counts.get(&"persona_text", 0)), 0)
	assert_lt(synthesis.last_delta_update_usec, 16_000)
	assert_true(synthesis.stage_card(&"fuel", soft_gauze))
	assert_same(synthesis.material_slots[0], base_slot)
	assert_same(synthesis.material_slots[1], fuel_slot)
	assert_same(synthesis.material_slots[2], mask_slot)
	assert_same(base_slot.card_view, base_card_view)
	assert_same(mask_slot.card_view, preallocated_mask_card_view)

	var candidate_button := synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button
	assert_false(candidate_button.disabled)
	var total_roots: Dictionary = {}
	for tag in synthesis.total_chip_views:
		total_roots[tag] = (synthesis.total_chip_views[tag] as Dictionary).root
	synthesis.reset_debug_update_counts()
	candidate_button.pressed.emit()
	assert_eq(main.state.synthesis_candidate_recipe_id, &"recipe_midnight_rose")
	assert_true(is_instance_valid(synthesis))
	assert_same(synthesis.candidate_buttons[&"recipe_midnight_rose"], candidate_button)
	assert_same(synthesis.material_slots[0], base_slot)
	assert_same(synthesis.material_slots[1], fuel_slot)
	assert_same(base_slot.card_view, base_card_view)
	assert_eq(int(synthesis.debug_update_counts.get(&"candidate_selection", 0)), 1)
	assert_eq(int(synthesis.debug_update_counts.get(&"action", 0)), 1)
	assert_eq(int(synthesis.debug_update_counts.get(&"materials", 0)), 0)
	assert_eq(int(synthesis.debug_update_counts.get(&"totals", 0)), 0)
	assert_eq(int(synthesis.debug_update_counts.get(&"candidates", 0)), 0)
	assert_lt(synthesis.last_delta_update_usec, 16_000)
	for tag in total_roots:
		assert_same((synthesis.total_chip_views[tag] as Dictionary).root, total_roots[tag])


func test_synthesis_panels_shift_left_and_totals_preview_is_narrower() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	var totals_panel := synthesis.totals_row.get_parent().get_parent().get_parent() as PanelContainer
	var base_panel := synthesis.base_slot_host.get_parent().get_parent() as PanelContainer
	var mask_panel := synthesis.mask_slot_host.get_parent().get_parent() as PanelContainer
	var fuel_panel := synthesis.fuel_slot_host.get_parent().get_parent() as PanelContainer
	var candidate_panel := (
		synthesis.candidate_list.get_parent().get_parent().get_parent().get_parent()
		as PanelContainer
	)
	assert_almost_eq(totals_panel.anchor_left, candidate_panel.anchor_left, 0.001)
	assert_almost_eq(totals_panel.anchor_right, candidate_panel.anchor_right, 0.001)
	assert_almost_eq(base_panel.anchor_left, 0.0625, 0.001)
	assert_almost_eq(
		(base_panel.anchor_left + base_panel.anchor_right) * 0.5,
		candidate_panel.anchor_left * 0.5,
		0.001,
	)
	assert_almost_eq(candidate_panel.anchor_left, 0.315, 0.001)
	assert_almost_eq(candidate_panel.anchor_right, 0.685, 0.001)
	assert_almost_eq(
		(candidate_panel.anchor_left + candidate_panel.anchor_right) * 0.5,
		0.5,
		0.001,
	)
	assert_almost_eq(mask_panel.anchor_left, 0.700, 0.001)
	assert_almost_eq(fuel_panel.anchor_left, 0.835, 0.001)
	assert_lt(fuel_panel.anchor_left - mask_panel.anchor_right, 0.02)
	assert_gt(candidate_panel.anchor_top, 0.19)
	assert_true(base_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert_true(mask_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert_true(fuel_panel.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert_null(synthesis.find_child("PersonaHeading", true, false))
	assert_null(synthesis.find_child("LeaveSynthesisButton", true, false))
	assert_eq(synthesis.result_layer.get_child_count(), 1)


func test_empty_material_slots_show_text_only_role_help() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	var base_slot := synthesis.material_slots[0]
	base_slot._on_gui_input(click)
	assert_eq(main.hand_bar.active_tab, QuestHandBar.TAB_ITEMS)
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.current_definition.id, &"synthesis_base_help")
	assert_eq(
		main.detail_popup.title_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.base"),
	)
	assert_eq(
		main.detail_popup.description_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.base.description"),
	)
	assert_false(main.detail_popup.item_frame.visible)
	assert_false(main.detail_popup.property_band.visible)
	base_slot._on_gui_input(click)
	assert_false(main.detail_popup.visible)

	var fuel_slot := synthesis.material_slots[1]
	fuel_slot._on_gui_input(click)
	assert_eq(main.hand_bar.active_tab, QuestHandBar.TAB_ITEMS)
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.current_definition.id, &"synthesis_fuel_help")
	assert_eq(
		main.detail_popup.title_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.fuel"),
	)
	assert_eq(
		main.detail_popup.description_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.fuel.description"),
	)
	assert_false(main.detail_popup.item_frame.visible)
	assert_false(main.detail_popup.property_band.visible)

	var mask_slot := synthesis.material_slots[2]
	mask_slot._on_gui_input(click)
	assert_eq(main.hand_bar.active_tab, QuestHandBar.TAB_MASKS)
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.current_definition.id, &"synthesis_mask_help")
	assert_eq(
		main.detail_popup.title_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.mask"),
	)
	assert_eq(
		main.detail_popup.description_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.mask.description"),
	)
	assert_false(main.detail_popup.item_frame.visible)
	assert_false(main.detail_popup.property_band.visible)


func test_synthesis_slot_matches_task_slot_and_uses_drag_replace_contract() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	var slot := synthesis.material_slots[0]
	var reusable_card_view := slot.card_view
	assert_eq(slot.custom_minimum_size, QuestTaskSlot.CARD_SIZE)
	assert_eq(slot.size, QuestTaskSlot.CARD_SIZE)
	var slot_style := slot.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(slot_style.corner_radius_top_left, 8)
	assert_eq(slot.find_children("*", "Button", true, false).size(), 0)
	assert_true(slot._has_point(Vector2(-QuestTaskSlot.DROP_MARGIN.x + 1.0, 70.0)))

	var first := _card_by_definition(main.state, &"sunflower")
	var replacement := _card_by_definition(main.state, &"toy_block")
	assert_true(synthesis.stage_card(&"base", first))
	var replacement_data := {"kind": &"card_item", "card": replacement}
	assert_true(slot._can_drop_data(Vector2.ZERO, replacement_data))
	slot._drop_data(Vector2.ZERO, replacement_data)
	assert_same(slot.card_view, reusable_card_view)
	assert_same(slot.card, replacement)
	assert_eq(first.location, CardItemState.Location.HAND)
	assert_true(main.hand_bar.card_views.has(first.instance_id))

	slot.card_view._begin_drag_visual()
	main.hand_bar._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": replacement},
	)
	slot.card_view._end_drag_visual(true)
	await get_tree().process_frame
	assert_null(slot.card)
	assert_false(slot.card_view.visible)
	assert_eq(main.state.synthesis_base_instance_id, 0)
	assert_eq(replacement.location, CardItemState.Location.HAND)
	assert_true(main.hand_bar.card_views.has(replacement.instance_id))


func test_mask_slot_replaces_and_returns_persistent_persona_cards_to_mask_tab() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	var mask_slot := synthesis.material_slots[2]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	mask_slot._on_gui_input(click)
	assert_eq(main.hand_bar.active_tab, QuestHandBar.TAB_MASKS)

	var dreamwalker := PersonaMaskCatalog.card_for_persona(&"reverie")
	var nightwalker := PersonaMaskCatalog.card_for_persona(&"clarity")
	assert_true(synthesis.stage_card(&"mask", dreamwalker))
	assert_same(mask_slot.card, dreamwalker)
	assert_eq(dreamwalker.location, CardItemState.Location.ACTIVITY_SLOT)
	assert_eq(main.hand_bar.card_views.size(), 3)

	assert_true(synthesis.stage_card(&"mask", nightwalker))
	assert_same(mask_slot.card, nightwalker)
	assert_eq(dreamwalker.location, CardItemState.Location.HAND)
	assert_true(main.hand_bar.card_views.has(dreamwalker.instance_id))
	assert_false(main.hand_bar.card_views.has(nightwalker.instance_id))

	mask_slot.card_view._begin_drag_visual()
	main.hand_bar._drop_data(
		Vector2.ZERO,
		{"kind": &"card_item", "card": nightwalker},
	)
	mask_slot.card_view._end_drag_visual(true)
	await get_tree().process_frame
	assert_true(main.state.synthesis_persona_id.is_empty())
	assert_null(mask_slot.card)
	assert_eq(nightwalker.location, CardItemState.Location.HAND)
	assert_eq(main.hand_bar.card_views.size(), 4)


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null
