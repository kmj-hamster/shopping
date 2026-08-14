extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.LEGACY_MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_synthesis_uses_full_screen_in_bag_shell() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_same(synthesis.get_parent(), main.art_canvas)
	assert_eq(synthesis.anchor_left, 0.0)
	assert_eq(synthesis.anchor_right, 1.0)
	assert_false(main.global_frame.visible)
	assert_false(main.task_dock.visible)
	assert_true(main.hand_bar.visible)
	assert_true(main.protagonist_button.visible)
	var background := synthesis.find_child("InBagBackground", true, false) as TextureRect
	assert_not_null(background)
	assert_eq(background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq(background.texture.resource_path, "res://resources/ui/synthesis/bg-inbag.png")

	main._show_map_immediate()
	assert_true(main.global_frame.visible)
	assert_true(main.task_dock.visible)


func test_base_type_alone_reveals_gray_candidate_and_helper_type_does_not_add_recipes() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var jasmine := _card_by_definition(main.state, &"jasmine")
	var toy_block := _card_by_definition(main.state, &"toy_block")
	assert_true(synthesis.stage_card(&"base", jasmine))
	var candidates := main.state.synthesis_candidates()
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].recipe_id, &"recipe_midnight_rose")
	assert_false(candidates[0].is_complete)
	assert_true((synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button).visible)
	assert_eq((synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button).text, "◇")

	assert_true(synthesis.stage_card(&"helper", toy_block))
	candidates = main.state.synthesis_candidates()
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].recipe_id, &"recipe_midnight_rose")


func test_strengthen_popup_accepts_one_persona_and_one_helper_after_base() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var helper := _card_by_definition(main.state, &"soft_gauze")
	var dreamwalker := PersonaMaskCatalog.card_for_persona(&"dreamwalker")
	assert_false(synthesis.stage_card(&"helper", helper))
	assert_false(synthesis.stage_card(&"persona", dreamwalker))

	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	assert_true(synthesis.strengthen_button.visible)
	synthesis.strengthen_button.pressed.emit()
	assert_true(synthesis.reinforcement_popup.visible)
	assert_true(synthesis.stage_card(&"helper", helper))
	assert_true(synthesis.stage_card(&"persona", dreamwalker))
	assert_same(synthesis.helper_slot.card, helper)
	assert_same(synthesis.persona_slot.card, dreamwalker)
	var totals := main.state.synthesis_persona_totals()
	assert_eq(int(totals[&"dreamwalker"]), 5)
	assert_eq(int(totals[&"homecomer"]), 4)
	assert_eq(int(totals[&"mourner"]), 0)
	assert_eq(int(totals[&"nightwalker"]), 0)


func test_replacing_or_removing_base_clears_reinforcement_and_returns_helper() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var jasmine := _card_by_definition(main.state, &"jasmine")
	var helper := _card_by_definition(main.state, &"soft_gauze")
	var replacement := _card_by_definition(main.state, &"toy_block")
	assert_true(synthesis.stage_card(&"base", jasmine))
	assert_true(synthesis.stage_card(&"helper", helper))
	assert_true(
		synthesis.stage_card(
			&"persona", PersonaMaskCatalog.card_for_persona(&"dreamwalker")
		)
	)
	assert_true(synthesis.stage_card(&"base", replacement))
	assert_eq(main.state.synthesis_helper_instance_id, 0)
	assert_true(main.state.synthesis_persona_id.is_empty())
	assert_eq(helper.location, CardItemState.Location.HAND)
	assert_eq(jasmine.location, CardItemState.Location.HAND)

	assert_true(synthesis.stage_card(&"helper", helper))
	assert_true(main.state.return_card_to_hand(replacement))
	assert_eq(main.state.synthesis_base_instance_id, 0)
	assert_eq(main.state.synthesis_helper_instance_id, 0)
	assert_eq(helper.location, CardItemState.Location.HAND)
	assert_false(synthesis.reinforcement_popup.visible)


func test_unknown_gray_candidate_opens_possibility_with_types_and_requirements() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	var button := synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button
	button.pressed.emit()
	assert_eq(main.state.synthesis_candidate_recipe_id, &"recipe_midnight_rose")
	assert_false(main.state.discovered_recipe_ids.has(&"recipe_midnight_rose"))
	assert_false(synthesis.action_button.visible)
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.current_definition.id, &"possibility_recipe_midnight_rose")
	assert_eq(
		main.detail_popup.title_label.text,
		TranslationServer.translate(&"quest.ui.synthesis.possibility.title"),
	)
	assert_true(main.detail_popup.current_definition.has_property(&"flower"))
	assert_eq(main.detail_popup.current_definition.property_value(&"dreamwalker"), 5)


func test_complete_click_discovers_recipe_and_discovered_gray_click_reveals_output() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var helper := _card_by_definition(main.state, &"soft_gauze")
	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	assert_true(synthesis.stage_card(&"helper", helper))
	assert_true(
		synthesis.stage_card(
			&"persona", PersonaMaskCatalog.card_for_persona(&"dreamwalker")
		)
	)
	(synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button).pressed.emit()
	assert_true(main.state.discovered_recipe_ids.has(&"recipe_midnight_rose"))
	assert_eq(main.detail_popup.current_definition.id, &"midnight_rose")
	assert_true(synthesis.action_button.visible)

	assert_true(main.state.return_card_to_hand(helper))
	var candidate := _candidate_by_id(main.state, &"recipe_midnight_rose")
	assert_false(candidate.is_complete)
	assert_true(candidate.shows_output)
	(synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button).pressed.emit()
	assert_eq(main.detail_popup.current_definition.id, &"midnight_rose")
	assert_false(synthesis.action_button.visible)


func test_persona_icon_click_opens_details_and_hover_pulses_matching_outputs() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	(synthesis.persona_buttons[&"dreamwalker"] as Button).pressed.emit()
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.primary_property_id, &"dreamwalker")
	assert_eq(
		main.detail_popup.title_label.text,
		TranslationServer.translate(&"demo.mask.dreamwalker.name"),
	)

	synthesis._on_persona_hovered(&"dreamwalker")
	assert_true(synthesis.candidate_hover_tweens.has(&"recipe_midnight_rose"))
	synthesis._on_persona_hovered(&"nightwalker")
	assert_false(synthesis.candidate_hover_tweens.has(&"recipe_midnight_rose"))


func test_success_consumes_base_and_helper_but_returns_persona_then_preserves_result_flow() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var jasmine := _card_by_definition(main.state, &"jasmine")
	var helper := _card_by_definition(main.state, &"soft_gauze")
	var persona := PersonaMaskCatalog.card_for_persona(&"dreamwalker")
	assert_true(synthesis.stage_card(&"base", jasmine))
	assert_true(synthesis.stage_card(&"helper", helper))
	assert_true(synthesis.stage_card(&"persona", persona))
	(synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button).pressed.emit()
	synthesis.action_button.pressed.emit()
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.NARRATIVE)
	assert_null(main.state.card_by_instance_id(jasmine.instance_id))
	assert_null(main.state.card_by_instance_id(helper.instance_id))
	assert_eq(persona.location, CardItemState.Location.HAND)
	assert_true(main.state.synthesis_persona_id.is_empty())
	var output := synthesis.pending_output
	assert_not_null(output)
	assert_true(main.hand_bar.temporarily_hidden_card_ids.has(output.instance_id))

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	synthesis._on_narrative_input(click)
	assert_eq(synthesis.narrative_state, QuestSynthesisInterface.NarrativeState.HOLDING)
	synthesis._show_result()
	synthesis._reveal_result()
	synthesis._on_result_drag_finished(output, true)
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.DRAFT)
	assert_null(synthesis.pending_output)
	assert_true(main.hand_bar.card_views.has(output.instance_id))


func test_drop_highlights_follow_closed_and_open_reinforcement_popup() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var jasmine := _card_by_definition(main.state, &"jasmine")
	synthesis.show_drop_targets_for_card(jasmine)
	_assert_drop_highlights(synthesis, {&"base": true})
	synthesis.clear_drop_target_highlights()

	assert_true(synthesis.stage_card(&"base", jasmine))
	synthesis.show_drop_targets_for_card(_card_by_definition(main.state, &"soft_gauze"))
	_assert_drop_highlights(synthesis, {})
	synthesis._open_reinforcement_popup()
	synthesis.show_drop_targets_for_card(_card_by_definition(main.state, &"soft_gauze"))
	_assert_drop_highlights(synthesis, {&"helper": true})
	synthesis.show_drop_targets_for_card(PersonaMaskCatalog.card_for_persona(&"dreamwalker"))
	_assert_drop_highlights(synthesis, {&"persona": true})


func test_reinforcement_copy_switches_live_between_chinese_and_english() -> void:
	var original_locale := LocaleManager.current_locale
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	assert_eq(synthesis.strengthen_button.text, "Strengthen")
	assert_eq((synthesis.reinforcement_labels[&"persona"] as Label).text, "Borrow Myself")
	assert_eq((synthesis.reinforcement_labels[&"helper"] as Label).text, "Borrow an Item")
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	assert_eq(synthesis.strengthen_button.text, "强化")
	assert_eq((synthesis.reinforcement_labels[&"persona"] as Label).text, "借助自己")
	assert_eq((synthesis.reinforcement_labels[&"helper"] as Label).text, "借助物品")
	LocaleManager.set_locale(original_locale, false)


func _assert_drop_highlights(
	synthesis: QuestSynthesisInterface,
	expected_roles: Dictionary,
) -> void:
	for slot in synthesis.material_slots:
		assert_eq(
			slot.drop_highlighted,
			bool(expected_roles.get(slot.role_id, false)),
			"Unexpected highlight state for %s" % slot.role_id,
		)


func _spawn_synthesis_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	main._show_synthesis_immediate()
	await get_tree().process_frame
	return main


func _card_by_definition(state: QuestGameState, definition_id: StringName) -> CardItemState:
	for card in state.inventory:
		if card.definition_id == definition_id:
			return card
	return null


func _candidate_by_id(state: QuestGameState, recipe_id: StringName) -> Dictionary:
	for candidate in state.synthesis_candidates():
		if StringName(candidate.recipe_id) == recipe_id:
			return candidate
	return {}
