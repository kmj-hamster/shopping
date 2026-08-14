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
	assert_eq(synthesis.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_null(synthesis.find_child("SynthesisBackgroundInput", true, false))
	assert_null(synthesis.find_child("InBagBackground", true, false))
	assert_null(synthesis.find_child("SynthesisBackgroundDimmer", true, false))
	var star_chart := synthesis.find_child("PersonaStarChart", true, false) as PersonaStarChart
	assert_not_null(star_chart)
	assert_eq(PersonaStarChart.BACKGROUND_COLOR, Color("050a18"))
	assert_lt(star_chart.get_index(), synthesis.draft_layer.get_index())
	assert_eq(PersonaStarChart.MAX_LEVEL, 10)

	main._show_map_immediate()
	assert_true(main.global_frame.visible)
	assert_true(main.task_dock.visible)


func test_synthesis_shell_does_not_block_hand_cards_or_bag_button() -> void:
	var main := await _spawn_synthesis_main()
	var first_wrapper := main.hand_bar.card_row.get_child(0) as Control
	var first_card := first_wrapper.get_child(0) as CardHandCard
	var exposed_card_point := first_card.get_global_rect().position + Vector2(8, 52)
	await _click_viewport_at(exposed_card_point)
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.current_definition.id, first_card.definition.id)
	main._close_detail_popups()
	await get_tree().process_frame

	# GUT's own TestOutput control covers the runtime button's lower-right position.
	# Move the button into an uncovered area while preserving the same canvas layer.
	main.protagonist_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	main.protagonist_button.position = Vector2(28, 510)
	main.protagonist_button.size = Vector2(128, 150)
	await get_tree().process_frame
	var bag_point := main.protagonist_button.get_global_rect().get_center()
	await _move_viewport_to(bag_point)
	assert_same(get_viewport().gui_get_hovered_control(), main.protagonist_button)
	await _click_viewport_at(bag_point)
	await get_tree().create_timer(0.4).timeout
	assert_true(main.current_screen is QuestMapScreen)


func test_persona_rays_clear_the_card_and_reach_distant_icons_at_level_ten() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var card_rect := Rect2(
		synthesis.base_slot_host.position,
		synthesis.base_slot_host.size,
	)
	for persona_id in CardPropertySet.PERSONAS:
		var button := synthesis.persona_buttons[persona_id] as Button
		var button_rect := Rect2(button.position, button.size)
		var level_zero := synthesis._persona_ray_points(persona_id, 0)
		var level_one := synthesis._persona_ray_points(persona_id, 1)
		var level_two := synthesis._persona_ray_points(persona_id, 2)
		var level_nine := synthesis._persona_ray_points(persona_id, 9)
		var level_ten := synthesis._persona_ray_points(persona_id, 10)
		assert_eq(level_zero[0], level_zero[1])
		assert_false(card_rect.has_point(level_one[0]))
		assert_almost_eq(
			level_one[0].distance_to(level_one[1]),
			QuestSynthesisInterface.PERSONA_RAY_LEVEL_ONE_LENGTH,
			0.01,
		)
		assert_almost_eq(
			level_two[0].distance_to(level_two[1])
				- level_one[0].distance_to(level_one[1]),
			level_ten[0].distance_to(level_ten[1])
				- level_nine[0].distance_to(level_nine[1]),
			0.01,
		)
		assert_true(button_rect.has_point(level_ten[1]))

	var nightwalker := synthesis.persona_buttons[&"nightwalker"] as Button
	var mourner := synthesis.persona_buttons[&"mourner"] as Button
	var dreamwalker := synthesis.persona_buttons[&"dreamwalker"] as Button
	var homecomer := synthesis.persona_buttons[&"homecomer"] as Button
	assert_lt(nightwalker.get_rect().get_center().x + nightwalker.position.x, 240.0)
	assert_lt(mourner.get_rect().get_center().x + mourner.position.x, 240.0)
	assert_gt(dreamwalker.get_rect().get_center().x + dreamwalker.position.x, 1040.0)
	assert_gt(homecomer.get_rect().get_center().x + homecomer.position.x, 1040.0)
	assert_lt(nightwalker.get_rect().get_center().y + nightwalker.position.y, 180.0)
	assert_lt(dreamwalker.get_rect().get_center().y + dreamwalker.position.y, 180.0)
	assert_gt(mourner.get_rect().get_center().y + mourner.position.y, 340.0)
	assert_gt(homecomer.get_rect().get_center().y + homecomer.position.y, 340.0)


func test_recipe_nodes_keep_fixed_star_chart_coordinates_when_totals_change() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var single_recipe := QuestArcCatalog.recipe_by_id(&"recipe_midnight_rose")
	var pair_recipe := SynthesisRecipeDefinition.new()
	pair_recipe.id = &"star_chart_pair_probe"
	pair_recipe.required_personas = {&"nightwalker": 5, &"dreamwalker": 5}
	assert_not_null(single_recipe)
	var single_position := synthesis._candidate_position(single_recipe)
	var pair_position := synthesis._candidate_position(pair_recipe)
	assert_eq(
		single_position,
		synthesis.star_chart.axis_point(&"dreamwalker", 5.0),
	)
	assert_true(PersonaStarChart.CANDIDATE_BOUNDS.has_point(pair_position))
	assert_ne(pair_position, QuestSynthesisInterface.FIELD_CENTER)
	synthesis.star_chart.set_totals({
		&"nightwalker": 10,
		&"mourner": 7,
		&"dreamwalker": 9,
		&"homecomer": 6,
	})
	assert_eq(synthesis._candidate_position(single_recipe), single_position)
	assert_eq(synthesis._candidate_position(pair_recipe), pair_position)


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
	var candidate_button := synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button
	assert_eq(candidate_button.text, "◇")
	assert_true(candidate_button.flat)
	var candidate_style := candidate_button.get_theme_stylebox("normal") as StyleBoxEmpty
	assert_not_null(candidate_style)
	assert_eq(candidate_button.get_theme_constant("outline_size"), 2)

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


func _click_viewport_at(position: Vector2) -> void:
	await _move_viewport_to(position)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.position = position
	click.global_position = position
	click.pressed = true
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	click = click.duplicate() as InputEventMouseButton
	click.button_mask = 0
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame


func _move_viewport_to(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame


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
