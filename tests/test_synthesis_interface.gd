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
	assert_same(
		synthesis.find_child("SynthesisBackgroundInput", true, false),
		synthesis.background_input,
	)
	assert_eq(synthesis.background_input.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_lt(synthesis.background_input.get_index(), synthesis.draft_layer.get_index())
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


func test_synthesis_uses_the_dedicated_four_persona_art() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var expected_paths := {
		&"nightwalker": "res://resources/ui/synthesis/persona/nightwalker.png",
		&"mourner": "res://resources/ui/synthesis/persona/mourner.png",
		&"dreamwalker": "res://resources/ui/synthesis/persona/dreamwalker.png",
		&"homecomer": "res://resources/ui/synthesis/persona/homecomer.png",
	}
	assert_eq(
		synthesis.background_image.texture.resource_path,
		"res://resources/ui/synthesis/bg-inbag.png",
	)
	assert_eq(
		Vector4(
			synthesis.background_image.offset_left,
			synthesis.background_image.offset_top,
			synthesis.background_image.offset_right,
			synthesis.background_image.offset_bottom,
		),
		Vector4(0.0, -24.0, 48.0, 24.0),
	)
	for persona_id in expected_paths:
		var button := synthesis.persona_buttons[persona_id] as Button
		var icon := button.get_node("PersonaIcon") as TextureRect
		assert_not_null(icon, persona_id)
		assert_eq(icon.texture.resource_path, expected_paths[persona_id], persona_id)
		var display_scale := float(
			QuestSynthesisInterface.PERSONA_ICON_DISPLAY_SCALES[persona_id]
		)
		var expected_size := QuestSynthesisInterface.PERSONA_ICON_SIZE * display_scale
		var expected_position := (button.size - icon.size) * 0.5
		assert_almost_eq(icon.size.x, expected_size.x, 0.001, persona_id)
		assert_almost_eq(icon.size.y, expected_size.y, 0.001, persona_id)
		assert_almost_eq(icon.position.x, expected_position.x, 0.001, persona_id)
		assert_almost_eq(icon.position.y, expected_position.y, 0.001, persona_id)


func test_synthesis_shell_does_not_block_hand_cards_or_bag_button() -> void:
	var main := await _spawn_synthesis_main()
	var first_wrapper := main.hand_bar.card_row.get_child(0) as Control
	var first_card := first_wrapper.get_child(0) as CardHandCard
	var exposed_card_point := first_card.get_global_rect().position + Vector2(8, 52)
	assert_false(
		(main.current_screen as QuestSynthesisInterface).background_input._has_point(
			(main.current_screen as QuestSynthesisInterface)
				.background_input
				.get_global_transform_with_canvas()
				.affine_inverse()
				* exposed_card_point
		)
	)
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


func test_blank_synthesis_background_closes_top_right_details() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	main._show_item(QuestArcCatalog.item_by_id(&"jasmine"))
	assert_true(main.detail_popup.visible)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	synthesis.background_input.gui_input.emit(click)
	assert_false(main.detail_popup.visible)


func test_clicking_material_and_borrow_slots_lifts_only_cards_they_accept() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var jasmine := _card_by_definition(main.state, &"jasmine")
	var helper := _card_by_definition(main.state, &"soft_gauze")
	var dreamwalker := PersonaMaskCatalog.card_for_persona(&"dreamwalker")
	var jasmine_view := main.hand_bar.card_views[jasmine.instance_id] as CardHandCard
	var helper_view := main.hand_bar.card_views[helper.instance_id] as CardHandCard
	var dreamwalker_view := (
		main.hand_bar.card_views[dreamwalker.instance_id] as CardHandCard
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	synthesis.base_slot._on_gui_input(click)
	assert_true(main.hand_bar.card_highlight_predicate.is_valid())
	assert_true(jasmine_view.rule_match_highlighted)
	assert_false(dreamwalker_view.rule_match_highlighted)
	assert_almost_eq(jasmine_view.offset_top, -QuestHandBar.RULE_MATCH_LIFT, 0.01)
	assert_almost_eq(dreamwalker_view.offset_top, 0.0, 0.01)

	assert_true(synthesis.stage_card(&"base", jasmine))
	assert_false(main.hand_bar.card_highlight_predicate.is_valid())
	synthesis.persona_slot._on_gui_input(click)
	assert_true(dreamwalker_view.rule_match_highlighted)
	assert_false(helper_view.rule_match_highlighted)
	assert_almost_eq(dreamwalker_view.offset_top, -QuestHandBar.RULE_MATCH_LIFT, 0.01)

	(synthesis.reinforcement_labels[&"helper"] as Label).gui_input.emit(click)
	assert_false(dreamwalker_view.rule_match_highlighted)
	assert_true(helper_view.rule_match_highlighted)
	assert_almost_eq(helper_view.offset_top, -QuestHandBar.RULE_MATCH_LIFT, 0.01)

	synthesis.background_input.gui_input.emit(click)
	assert_false(main.hand_bar.card_highlight_predicate.is_valid())
	assert_false(helper_view.rule_match_highlighted)
	assert_almost_eq(helper_view.offset_top, 0.0, 0.01)


func test_empty_material_slots_open_localized_help_in_the_item_popup() -> void:
	var original_locale := LocaleManager.current_locale
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	synthesis.base_slot._on_gui_input(click)
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.current_definition.id, &"synthesis_base_help")
	assert_eq(main.detail_popup.title_label.text, "原料")
	assert_true(main.detail_popup.description_label.text.contains("[放入一件物品作为原料"))

	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	synthesis.persona_slot._on_gui_input(click)
	assert_eq(main.detail_popup.current_definition.id, &"synthesis_persona_help")
	assert_eq(main.detail_popup.title_label.text, "借助自己")
	assert_true(main.detail_popup.description_label.text.contains("[拖入一张面相卡"))

	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	synthesis.helper_slot._on_gui_input(click)
	assert_eq(main.detail_popup.current_definition.id, &"synthesis_helper_help")
	assert_eq(main.detail_popup.title_label.text, "borrow an item")
	assert_true(main.detail_popup.description_label.text.contains("[Drag in one item"))
	LocaleManager.set_locale(original_locale, false)


func test_material_type_icons_appear_above_the_base_and_open_property_details() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_false(synthesis.base_type_host.visible)
	assert_true(synthesis.displayed_base_type_ids.is_empty())

	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	assert_true(synthesis.base_type_host.visible)
	assert_eq(synthesis.displayed_base_type_ids, [&"flower"])
	assert_eq(synthesis.base_type_row.get_child_count(), 1)
	assert_lt(
		synthesis.base_type_host.position.y + synthesis.base_type_host.size.y,
		synthesis.base_slot_host.position.y,
	)
	var flower_icon := synthesis.base_type_row.get_child(0) as Button
	assert_eq(flower_icon.name, "FlowerBaseType")
	flower_icon.pressed.emit()
	assert_true(main.detail_popup.visible)
	assert_eq(main.detail_popup.primary_property_id, &"flower")

	var multi_type_item := CardItemDefinition.new()
	multi_type_item.property_set = CardPropertySet.new()
	multi_type_item.property_set.tags = [&"flower", &"toy", &"metal"]
	synthesis._update_base_type_icons({"base_item": multi_type_item}, true)
	assert_eq(synthesis.displayed_base_type_ids, [&"flower", &"toy"])
	assert_eq(synthesis.base_type_row.get_child_count(), 2)

	assert_true(main.state.return_card_to_hand(main.state.synthesis_base_card()))
	assert_false(synthesis.base_type_host.visible)
	assert_true(synthesis.displayed_base_type_ids.is_empty())


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
	assert_gt(dreamwalker.position.y, PersonaStarChart.POPUP_SAFE_RECT.end.y)
	assert_false(PersonaStarChart.POPUP_SAFE_RECT.intersects(
		Rect2(dreamwalker.position, dreamwalker.size)
	))
	assert_gt(mourner.get_rect().get_center().y + mourner.position.y, 340.0)
	assert_gt(homecomer.get_rect().get_center().y + homecomer.position.y, 340.0)
	assert_gt(QuestSynthesisInterface.FIELD_CENTER.x, 640.0)
	assert_gt(QuestSynthesisInterface.FIELD_CENTER.y, 280.0)


func test_recipe_nodes_keep_fixed_star_chart_coordinates_when_totals_change() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var single_recipe := QuestArcCatalog.recipe_by_id(&"recipe_midnight_rose")
	var pair_recipe := SynthesisRecipeDefinition.new()
	pair_recipe.id = &"star_chart_pair_probe"
	pair_recipe.required_personas = {&"nightwalker": 5, &"dreamwalker": 5}
	var lower_pair_recipe := SynthesisRecipeDefinition.new()
	lower_pair_recipe.id = &"star_chart_lower_pair_probe"
	lower_pair_recipe.required_personas = {&"mourner": 5, &"dreamwalker": 5}
	assert_not_null(single_recipe)
	var single_position := synthesis._candidate_position(single_recipe)
	var pair_position := synthesis._candidate_position(pair_recipe)
	var lower_pair_position := synthesis._candidate_position(lower_pair_recipe)
	assert_eq(
		single_position,
		synthesis.star_chart.axis_point(&"dreamwalker", 5.0),
	)
	assert_true(PersonaStarChart.CANDIDATE_BOUNDS.has_point(pair_position))
	assert_ne(pair_position, QuestSynthesisInterface.FIELD_CENTER)
	var pair_track := synthesis.star_chart.pair_track_points(pair_recipe)
	assert_eq(
		pair_track[0],
		synthesis.star_chart.axis_point(&"nightwalker", 5.0),
	)
	assert_eq(
		pair_track[-1],
		synthesis.star_chart.axis_point(&"dreamwalker", 5.0),
	)
	assert_true(pair_position in pair_track)
	var visible_pair_recipes: Array[SynthesisRecipeDefinition] = [
		pair_recipe,
		lower_pair_recipe,
	]
	synthesis.star_chart.set_candidate_recipes(visible_pair_recipes)
	assert_eq(synthesis.star_chart.active_pair_recipes, visible_pair_recipes)
	var lower_pair_rect := Rect2(
		lower_pair_position - QuestSynthesisInterface.CANDIDATE_NODE_SIZE * 0.5,
		QuestSynthesisInterface.CANDIDATE_NODE_SIZE,
	)
	for role_id in [&"persona", &"helper"]:
		var reinforcement_column := (
			synthesis.reinforcement_columns[role_id] as VBoxContainer
		)
		var reinforcement_slot_rect := Rect2(
			reinforcement_column.position,
			QuestTaskSlot.CARD_SIZE,
		)
		assert_false(lower_pair_rect.intersects(reinforcement_slot_rect))
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
	assert_eq(candidate_button.text, "◆")
	assert_true(candidate_button.flat)
	var candidate_style := candidate_button.get_theme_stylebox("normal") as StyleBoxEmpty
	assert_not_null(candidate_style)
	assert_eq(candidate_button.get_theme_constant("outline_size"), 3)
	var candidate_view := synthesis.candidate_views[&"recipe_midnight_rose"] as Dictionary
	assert_true((candidate_view.halo as Label).visible)
	assert_true(synthesis.candidate_breath_tweens.has(&"recipe_midnight_rose"))

	assert_true(synthesis.stage_card(&"helper", toy_block))
	candidates = main.state.synthesis_candidates()
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].recipe_id, &"recipe_midnight_rose")


func test_reinforcement_slots_appear_only_after_material_is_placed() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var helper := _card_by_definition(main.state, &"soft_gauze")
	var dreamwalker := PersonaMaskCatalog.card_for_persona(&"dreamwalker")
	assert_false(synthesis.reinforcement_group.visible)
	assert_false(synthesis.stage_card(&"helper", helper))
	assert_false(synthesis.stage_card(&"persona", dreamwalker))

	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	assert_true(synthesis.reinforcement_group.visible)
	var persona_column := synthesis.reinforcement_columns[&"persona"] as VBoxContainer
	var helper_column := synthesis.reinforcement_columns[&"helper"] as VBoxContainer
	var base_center_x := synthesis.base_slot_host.position.x + synthesis.base_slot_host.size.x * 0.5
	var reinforcement_center_x := (
		persona_column.position.x
		+ helper_column.position.x
		+ QuestTaskSlot.CARD_SIZE.x
	) * 0.5
	assert_almost_eq(base_center_x, reinforcement_center_x, 0.01)
	assert_gt(persona_column.position.y, synthesis.base_slot_host.position.y + synthesis.base_slot_host.size.y)
	assert_eq(persona_column.position.y, helper_column.position.y)
	assert_almost_eq(
		helper_column.position.x - persona_column.position.x - QuestTaskSlot.CARD_SIZE.x,
		QuestSynthesisInterface.REINFORCEMENT_SLOT_GAP,
		0.01,
	)
	assert_lt(
		persona_column.position.y + persona_column.custom_minimum_size.y,
		560.0,
	)
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
	assert_false(synthesis.reinforcement_group.visible)
	assert_null(synthesis.persona_slot.card)
	assert_null(synthesis.helper_slot.card)


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


func test_candidate_selection_clears_on_repeat_or_blank_background_click() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	assert_true(synthesis.stage_card(&"base", _card_by_definition(main.state, &"jasmine")))
	var button := synthesis.candidate_buttons[&"recipe_midnight_rose"] as Button

	button.pressed.emit()
	assert_eq(main.state.synthesis_candidate_recipe_id, &"recipe_midnight_rose")
	assert_true(button.button_pressed)
	assert_true(main.detail_popup.visible)

	button.pressed.emit()
	assert_true(main.state.synthesis_candidate_recipe_id.is_empty())
	assert_false(button.button_pressed)
	assert_false(synthesis.action_button.visible)
	assert_false(main.detail_popup.visible)

	button.pressed.emit()
	assert_eq(main.state.synthesis_candidate_recipe_id, &"recipe_midnight_rose")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	synthesis.background_input.gui_input.emit(click)
	assert_true(main.state.synthesis_candidate_recipe_id.is_empty())
	assert_false(button.button_pressed)
	assert_false(synthesis.action_button.visible)
	assert_false(main.detail_popup.visible)


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


func test_drop_highlights_follow_visible_inline_reinforcement_slots() -> void:
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	var jasmine := _card_by_definition(main.state, &"jasmine")
	synthesis.show_drop_targets_for_card(jasmine)
	_assert_drop_highlights(synthesis, {&"base": true})
	synthesis.clear_drop_target_highlights()

	assert_true(synthesis.stage_card(&"base", jasmine))
	synthesis.show_drop_targets_for_card(_card_by_definition(main.state, &"soft_gauze"))
	_assert_drop_highlights(synthesis, {&"helper": true})
	synthesis.show_drop_targets_for_card(PersonaMaskCatalog.card_for_persona(&"dreamwalker"))
	_assert_drop_highlights(synthesis, {&"persona": true})


func test_inline_reinforcement_copy_switches_live_between_chinese_and_english() -> void:
	var original_locale := LocaleManager.current_locale
	var main := await _spawn_synthesis_main()
	var synthesis := main.current_screen as QuestSynthesisInterface
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	assert_eq((synthesis.reinforcement_labels[&"persona"] as Label).text, "borrow myself")
	assert_eq((synthesis.reinforcement_labels[&"helper"] as Label).text, "borrow an item")
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
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
