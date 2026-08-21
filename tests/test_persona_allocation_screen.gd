extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	GameState.reset_game()


func after_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)


func test_selection_spends_only_the_delta_and_clicking_active_node_refunds() -> void:
	var screen := await _spawn_screen()
	assert_eq(screen.remaining_points(), 5)
	assert_eq(screen.selected_value(CardPropertySet.SHAPE_LIGHT), 0)
	assert_false(screen.enter_button.visible)

	screen._on_node_pressed(CardPropertySet.SHAPE_LIGHT, 2)
	assert_eq(screen.selected_value(CardPropertySet.SHAPE_LIGHT), 2)
	assert_eq(screen.remaining_points(), 3)
	screen._on_node_pressed(CardPropertySet.SHAPE_LIGHT, 3)
	assert_eq(screen.selected_value(CardPropertySet.SHAPE_LIGHT), 3)
	assert_eq(screen.remaining_points(), 2)
	screen._on_node_pressed(CardPropertySet.SHAPE_LIGHT, 3)
	assert_eq(screen.selected_value(CardPropertySet.SHAPE_LIGHT), 0)
	assert_eq(screen.remaining_points(), 5)


func test_overspending_is_rejected_and_exact_allocation_reveals_enter_button() -> void:
	var screen := await _spawn_screen()
	screen._on_node_pressed(CardPropertySet.SHAPE_LIGHT, 3)
	screen._on_node_pressed(CardPropertySet.SHAPE_TEAR, 2)
	assert_eq(screen.remaining_points(), 0)
	assert_true(screen.enter_button.visible)
	screen._on_node_pressed(CardPropertySet.SHAPE_DREAM, 1)
	assert_eq(screen.selected_value(CardPropertySet.SHAPE_DREAM), 0)
	assert_eq(screen.remaining_points(), 0)
	assert_not_null(screen.points_glow_tween)
	assert_eq(screen.pinned_shape_id, CardPropertySet.SHAPE_DREAM)
	var dream_copy := screen.persona_copy_labels[CardPropertySet.SHAPE_DREAM] as RichTextLabel
	assert_true(dream_copy.visible)
	assert_true(dream_copy.text.contains("梦游者"))


func test_clicking_each_axis_node_pins_its_persona_copy() -> void:
	var screen := await _spawn_screen()
	for shape_id in CardPropertySet.SHAPES:
		screen._on_node_pressed(shape_id, 1)
		assert_eq(screen.pinned_shape_id, shape_id)
		for other_shape_id in CardPropertySet.SHAPES:
			var copy := screen.persona_copy_labels[other_shape_id] as RichTextLabel
			assert_eq(copy.visible, other_shape_id == shape_id)


func test_axes_use_three_even_pulsing_dot_hit_targets() -> void:
	var screen := await _spawn_screen()
	var portrait := screen.get_node("BagPortrait") as Sprite2D
	var rendered_size := portrait.texture.get_size() * portrait.scale
	assert_almost_eq(rendered_size.y, screen.PORTRAIT_SIZE.y, 0.01)
	assert_almost_eq(
		portrait.position.y + rendered_size.y * 0.5,
		screen.PORTRAIT_BOTTOM,
		0.01,
	)
	for shape_id in CardPropertySet.SHAPES:
		var direction := screen._axis_direction(shape_id)
		for value in range(1, 4):
			var button := (screen.node_buttons[shape_id] as Dictionary)[value] as Button
			assert_true(button.flat)
			assert_true(button.get_theme_stylebox("normal") is StyleBoxEmpty)
			assert_almost_eq(
				screen.FIELD_CENTER.distance_to(screen._node_position(shape_id, value)),
				float(screen.NODE_DISTANCES[value - 1]),
				0.01,
			)
			assert_almost_eq(
				(screen._node_position(shape_id, value) - screen.FIELD_CENTER).normalized().dot(direction),
				1.0,
				0.001,
			)
		assert_almost_eq(
			screen.AXIS_END_DISTANCE,
			float(screen.NODE_DISTANCES[-1]),
			0.01,
		)
	assert_lte(screen.NODE_DOT_RADIUS, 2.0)
	assert_gt(screen.NODE_PULSE_MAX_RADIUS, screen.NODE_PULSE_MIN_RADIUS)
	assert_true(screen.is_processing())
	screen._on_node_pressed(CardPropertySet.SHAPE_LIGHT, 2)
	assert_true(screen.is_node_lit(CardPropertySet.SHAPE_LIGHT, 1))
	assert_true(screen.is_node_lit(CardPropertySet.SHAPE_LIGHT, 2))
	assert_false(screen.is_node_lit(CardPropertySet.SHAPE_LIGHT, 3))


func test_icon_hover_previews_copy_and_click_pins_only_one_persona() -> void:
	var screen := await _spawn_screen()
	var light_copy := screen.persona_copy_labels[CardPropertySet.SHAPE_LIGHT] as RichTextLabel
	var tear_copy := screen.persona_copy_labels[CardPropertySet.SHAPE_TEAR] as RichTextLabel
	assert_false(light_copy.visible)
	assert_false(tear_copy.visible)

	screen._on_icon_hovered(CardPropertySet.SHAPE_LIGHT)
	assert_true(light_copy.visible)
	assert_true(light_copy.text.contains("提灯者"))
	assert_true(light_copy.text.contains("理性、调查"))
	assert_false(light_copy.text.contains("侦探，调查员"))
	assert_true(light_copy.text.contains("\n夜晚使我的头脑更加清醒。"))
	screen._on_icon_unhovered(CardPropertySet.SHAPE_LIGHT)
	assert_false(light_copy.visible)

	screen._on_icon_pressed(CardPropertySet.SHAPE_LIGHT)
	assert_eq(screen.pinned_shape_id, CardPropertySet.SHAPE_LIGHT)
	assert_true(light_copy.visible)

	screen._on_icon_hovered(CardPropertySet.SHAPE_TEAR)
	assert_false(light_copy.visible)
	assert_true(tear_copy.visible)
	screen._on_icon_unhovered(CardPropertySet.SHAPE_TEAR)
	assert_true(light_copy.visible)
	assert_false(tear_copy.visible)

	screen._on_icon_pressed(CardPropertySet.SHAPE_TEAR)
	assert_eq(screen.pinned_shape_id, CardPropertySet.SHAPE_TEAR)
	assert_false(light_copy.visible)
	assert_true(tear_copy.visible)
	assert_true(tear_copy.text.contains("共情、怜悯"))

	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	await get_tree().process_frame
	assert_true(tear_copy.text.contains("The Nightwatcher"))
	assert_true(tear_copy.text.contains("empathy and compassion"))
	assert_false(tear_copy.text.contains("Nostalgic ghosts"))
	assert_true(tear_copy.text.contains("\nNight reminds me of sorrowful things."))

	screen._on_icon_pressed(CardPropertySet.SHAPE_DREAM)
	var dream_copy := screen.persona_copy_labels[CardPropertySet.SHAPE_DREAM] as RichTextLabel
	assert_true(dream_copy.text.contains("The Dreamwalker"))
	screen._on_icon_pressed(CardPropertySet.SHAPE_SLEEP)
	var sleep_copy := screen.persona_copy_labels[CardPropertySet.SHAPE_SLEEP] as RichTextLabel
	assert_true(sleep_copy.text.contains("The Homecomer"))
	assert_true(sleep_copy.text.contains("May I sleep well tonight, tonight."))
	assert_false(sleep_copy.text.contains("Those off work"))


func test_persona_copy_stays_inside_aligned_quadrants_in_both_locales() -> void:
	var screen := await _spawn_screen()
	for locale in [LocaleManager.LOCALE_ZH, LocaleManager.LOCALE_EN]:
		LocaleManager.set_locale(locale, false)
		await get_tree().process_frame
		for shape_id in CardPropertySet.SHAPES:
			screen._on_icon_pressed(shape_id)
			await get_tree().process_frame
			var copy := screen.persona_copy_labels[shape_id] as RichTextLabel
			var expected_rect := screen.PERSONA_COPY_RECTS[shape_id] as Rect2
			assert_eq(copy.position, expected_rect.position)
			assert_eq(copy.size, expected_rect.size)
			assert_almost_eq(
				copy.get_global_rect().get_center().x,
				float((screen.ICON_CENTERS[shape_id] as Vector2).x),
				0.01,
				"%s/%s title center" % [locale, shape_id],
			)
			assert_eq(copy.get_theme_font_size("normal_font_size"), 18)
			assert_true(copy.text.contains("[font_size=27]"))
			assert_true(copy.text.contains("[center][font_size=18]"))
			assert_false(copy.text.contains("[right]"))
			assert_false(copy.text.contains("[left]"))
			assert_lte(
				float(copy.get_content_height()),
				copy.size.y,
				"%s/%s" % [locale, shape_id],
			)


func test_main_commits_exact_values_saves_and_returns_to_map_with_all_personas() -> void:
	var main := await _spawn_main()
	main._show_persona_allocation_test()
	await get_tree().process_frame
	var screen := main.persona_allocation_screen
	assert_not_null(screen)
	assert_false(main.art_canvas.visible)
	assert_same(main.current_screen, screen)

	screen._on_node_pressed(CardPropertySet.SHAPE_LIGHT, 3)
	screen._on_node_pressed(CardPropertySet.SHAPE_TEAR, 2)
	screen._on_enter_pressed()
	await get_tree().process_frame
	assert_eq(int(main.state.protagonist_shape_levels[CardPropertySet.SHAPE_LIGHT]), 3)
	assert_eq(int(main.state.protagonist_shape_levels[CardPropertySet.SHAPE_TEAR]), 2)
	assert_eq(int(main.state.protagonist_shape_levels[CardPropertySet.SHAPE_DREAM]), 0)
	assert_eq(int(main.state.protagonist_shape_levels[CardPropertySet.SHAPE_SLEEP]), 0)
	assert_eq(main.state.story_flags[&"initial_persona_allocation_complete"], &"true")
	assert_true(main.art_canvas.visible)
	assert_same(main.current_screen, main.map_screen)
	for shape_id in PersonaCardCatalog.PERSONA_SHAPES:
		var persona_card := PersonaCardCatalog.card_for_shape(shape_id)
		assert_true(main.hand_bar.card_views.has(persona_card.instance_id), shape_id)


func _spawn_screen() -> QuestPersonaAllocationScreen:
	var screen := QuestPersonaAllocationScreen.new()
	add_child_autoqfree(screen)
	await get_tree().process_frame
	return screen


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main
