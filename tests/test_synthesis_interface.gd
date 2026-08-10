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
	synthesis._reveal_result()
	assert_true(synthesis.result_revealed)
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

	var persona_button := synthesis.persona_buttons[&"reverie"] as Button
	var base_slot := synthesis.material_slots[0]
	var fuel_slot := synthesis.material_slots[1]
	var preallocated_base_card_view := base_slot.card_view
	synthesis.reset_debug_update_counts()
	persona_button.pressed.emit()
	assert_eq(main.state.synthesis_persona_id, &"reverie")
	assert_true(is_instance_valid(synthesis))
	assert_same(synthesis.persona_buttons[&"reverie"], persona_button)
	assert_same(synthesis.material_slots[0], base_slot)
	assert_same(synthesis.material_slots[1], fuel_slot)
	assert_eq(int(synthesis.debug_update_counts.get(&"full", 0)), 0)
	assert_eq(int(synthesis.debug_update_counts.get(&"materials", 0)), 0)
	assert_eq(int(synthesis.debug_update_counts.get(&"persona_selection", 0)), 1)
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
	assert_same(base_slot.card_view, base_card_view)
	assert_same(synthesis.persona_buttons[&"reverie"], persona_button)

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
