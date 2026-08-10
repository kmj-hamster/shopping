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


func test_pressed_persona_and_candidate_buttons_refresh_after_signal_finishes() -> void:
	var main := await _spawn_main()
	main._show_synthesis()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface

	var persona_button := synthesis.persona_buttons[&"reverie"] as Button
	persona_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(main.state.synthesis_persona_id, &"reverie")
	assert_true(is_instance_valid(synthesis))

	var sunflower := _card_by_definition(main.state, &"sunflower")
	var soft_gauze := _card_by_definition(main.state, &"soft_gauze")
	assert_true(synthesis.stage_card(&"base", sunflower))
	assert_true(synthesis.stage_card(&"fuel", soft_gauze))
	await get_tree().process_frame

	var candidate_button := synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button
	assert_false(candidate_button.disabled)
	candidate_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(main.state.synthesis_candidate_recipe_id, &"recipe_midnight_rose")
	assert_true(is_instance_valid(synthesis))


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
