extends GutTest


func before_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)


func after_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)


func test_rules_are_grouped_into_seven_pages_with_the_confirmed_audio() -> void:
	assert_eq(QuestOpeningRulesScreen.PAGES.size(), 7)
	assert_eq((QuestOpeningRulesScreen.PAGES[0] as Array).size(), 2)
	assert_eq((QuestOpeningRulesScreen.PAGES[1] as Array).size(), 1)
	assert_eq((QuestOpeningRulesScreen.PAGES[2] as Array).size(), 2)
	assert_eq((QuestOpeningRulesScreen.PAGES[3] as Array).size(), 2)
	assert_eq((QuestOpeningRulesScreen.PAGES[4] as Array).size(), 1)
	assert_eq((QuestOpeningRulesScreen.PAGES[5] as Array).size(), 2)
	assert_eq((QuestOpeningRulesScreen.PAGES[6] as Array).size(), 3)
	assert_eq(
		((QuestOpeningRulesScreen.PAGES[0] as Array)[0] as Dictionary).audio_path,
		"res://resources/audio/opening/0-1.mp3",
	)
	assert_eq(
		((QuestOpeningRulesScreen.PAGES[0] as Array)[1] as Dictionary).audio_path,
		"res://resources/audio/opening/0-2.mp3",
	)
	assert_true(
		bool(((QuestOpeningRulesScreen.PAGES[4] as Array)[0] as Dictionary).red)
	)
	var final_line := (QuestOpeningRulesScreen.PAGES[6] as Array)[2] as Dictionary
	assert_true(bool(final_line.red))
	assert_true(bool(final_line.auto_hide))
	for raw_page in QuestOpeningRulesScreen.PAGES:
		for raw_line in raw_page as Array:
			var audio_path := str((raw_line as Dictionary).audio_path)
			assert_true(ResourceLoader.exists(audio_path), audio_path)


func test_only_confirmed_rule_pages_use_faint_runtime_background_art() -> void:
	var screen := await _spawn_screen()
	assert_false(screen.background_art.visible)
	assert_null(screen.background_art.texture)

	var expected_paths := {
		1: "res://resources/background/opening/rule-night3.png",
		2: "res://resources/character/bag.png",
		3: "res://resources/background/opening/rule-night1.png",
		5: "res://resources/background/opening/rule-night2.png",
		6: "res://resources/background/map.png",
	}
	for expected_page in expected_paths:
		screen._start_page(expected_page)
		assert_true(screen.background_art.visible, str(expected_page))
		assert_eq(
			screen.background_art.texture.resource_path,
			expected_paths[expected_page],
			str(expected_page),
		)
		assert_almost_eq(
			screen.background_art.self_modulate.a,
			QuestOpeningRulesScreen.BACKGROUND_ART_ALPHA,
			0.001,
		)

	screen._start_page(2)
	assert_eq(
		screen.background_art.stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
	)
	screen._start_page(3)
	assert_eq(
		screen.background_art.stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED,
	)
	for black_page in [0, 4]:
		screen._start_page(black_page)
		assert_false(screen.background_art.visible, str(black_page))
		assert_null(screen.background_art.texture, str(black_page))


func test_click_reveals_without_stopping_audio_then_advances_within_the_page() -> void:
	var screen := await _spawn_screen()
	assert_true(screen.typing)
	assert_eq(screen.page_index, 0)
	assert_eq(screen.line_index, 0)
	assert_eq(screen.line_labels.size(), 1)
	assert_true(screen.audio_player.playing)
	var first_audio_player := screen.audio_player

	screen.advance()
	assert_false(screen.typing)
	assert_eq(screen.current_label.visible_characters, -1)
	assert_true(screen.audio_player.playing)
	assert_same(screen.audio_player, first_audio_player)

	screen.advance()
	assert_true(screen.typing)
	assert_eq(screen.page_index, 0)
	assert_eq(screen.line_index, 1)
	assert_eq(screen.line_labels.size(), 2)
	assert_eq(screen.current_audio_path, "res://resources/audio/opening/0-2.mp3")

	screen.advance()
	screen.advance()
	assert_eq(screen.page_index, 1)
	assert_eq(screen.line_index, 0)
	assert_eq(screen.line_labels.size(), 1)
	assert_eq(
		screen.current_localized_text(),
		"一、如果您听到商品的窃窃私语，请保持冷静，它们很快就会恢复沉默。",
	)


func test_chinese_reveals_by_character_but_english_reveals_by_whole_word() -> void:
	var screen := await _spawn_screen()
	assert_eq(screen.reveal_boundaries[0], 1)
	assert_eq(screen.character_index, 1)

	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	screen._start_page(0)
	assert_eq(screen.reveal_boundaries.size(), 6)
	assert_eq(screen.reveal_boundaries[0], 8)
	assert_eq(screen.character_index, 8)
	assert_eq(screen.current_localized_text().left(screen.character_index), "Welcome ")


func test_audio_end_auto_advances_only_when_the_line_received_no_click() -> void:
	var screen := await _spawn_screen()
	assert_false(screen.line_had_pointer_input)
	screen._on_audio_finished()
	assert_eq(screen.page_index, 0)
	assert_eq(screen.line_index, 1)
	assert_true(screen.typing)

	screen.advance()
	assert_true(screen.line_had_pointer_input)
	screen.audio_player.stop()
	screen._on_audio_finished()
	assert_eq(screen.page_index, 0)
	assert_eq(screen.line_index, 1)
	assert_false(screen.typing)


func test_audio_end_waits_two_seconds_only_before_changing_pages() -> void:
	var screen := await _spawn_screen()
	screen.audio_player.stop()
	screen._on_audio_finished()
	assert_eq(screen.page_index, 0)
	assert_eq(screen.line_index, 1)
	assert_true(screen.page_advance_timer.is_stopped())

	screen.audio_player.stop()
	screen._on_audio_finished()
	assert_eq(screen.page_index, 0)
	assert_eq(screen.line_index, 1)
	assert_false(screen.page_advance_timer.is_stopped())
	assert_almost_eq(
		screen.page_advance_timer.wait_time,
		QuestOpeningRulesScreen.PAGE_AUTO_ADVANCE_SECONDS,
		0.001,
	)

	screen._on_page_advance_timeout()
	assert_eq(screen.page_index, 1)
	assert_eq(screen.line_index, 0)


func test_clock_rule_finishes_its_text_well_before_its_audio() -> void:
	var screen := await _spawn_screen()
	screen._start_page(5)
	assert_eq(float(screen.current_line_definition().reveal_duration_ratio), 0.58)
	var scheduled_text_seconds := (
		screen.typewriter_timer.wait_time * screen.reveal_boundaries.size()
	)
	assert_lt(
		scheduled_text_seconds,
		screen.audio_player.stream.get_length() * 0.65,
	)


func test_red_lines_and_final_auto_hide_are_scoped_to_their_sentences() -> void:
	var screen := await _spawn_screen()
	screen._start_page(4)
	assert_true(bool(screen.current_line_definition().red))
	assert_true(screen.current_label.text.contains(
		QuestOpeningRulesScreen.WARNING.to_html(false)
	))

	screen._start_page(6)
	screen.advance()
	screen.advance()
	screen.advance()
	screen.advance()
	assert_eq(screen.page_index, 6)
	assert_eq(screen.line_index, 2)
	assert_true(bool(screen.current_line_definition().auto_hide))
	assert_true(screen.current_label.text.contains(
		QuestOpeningRulesScreen.WARNING.to_html(false)
	))


func test_locale_switch_reflows_current_page_without_restarting_its_audio() -> void:
	var screen := await _spawn_screen()
	screen.advance()
	screen.advance()
	var audio_path := screen.current_audio_path
	var audio_player := screen.audio_player
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	assert_eq(
		screen.current_localized_text(),
		"To ensure a pleasant shopping experience, please observe the following rules:",
	)
	assert_eq(screen.current_audio_path, audio_path)
	assert_same(screen.audio_player, audio_player)
	assert_eq(screen.screen_root.theme, QuestOpeningRulesScreen.EN_UI_THEME)
	assert_eq(
		screen.current_label.get_theme_font_size("normal_font_size"),
		QuestOpeningRulesScreen.EN_FONT_SIZE,
	)
	assert_eq(screen.english_font.spacing_glyph, 1)


func test_final_confirmation_closes_the_presentation() -> void:
	var screen := await _spawn_screen()
	watch_signals(screen)
	screen._start_page(6)
	for click_index in 6:
		screen.advance()
	assert_signal_emitted(screen, "finished")


func _spawn_screen() -> QuestOpeningRulesScreen:
	var screen := QuestOpeningRulesScreen.new()
	add_child_autoqfree(screen)
	await get_tree().process_frame
	return screen
