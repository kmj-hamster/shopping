extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_map_exposes_distinct_expedition_entrance_and_main_enters_full_screen_mode() -> void:
	var main := await _spawn_main()
	assert_not_null(main.map_screen.expedition_button)
	assert_eq(
		main.map_screen.expedition_button.text,
		TranslationServer.translate(&"expedition.ui.enter"),
	)
	main._start_expedition()
	await get_tree().process_frame
	assert_true(main.state.expedition.active)
	assert_not_null(main.expedition_screen)
	assert_false(main.art_canvas.visible)
	assert_true(main.expedition_screen.hand_bar.visible)
	assert_eq(
		main.expedition_screen.door_host.get_child_count(),
		main.state.expedition.current_door_ids.size(),
	)
	assert_true(main.debug_button_row.visible)
	assert_eq(main.debug_button_row.get_parent(), main.debug_button_layer)
	assert_gt(main.debug_button_layer.layer, QuestMain.SCREEN_TRANSITION_CANVAS_LAYER)


func test_shop_talk_button_notice_disappears_when_owner_request_is_accepted() -> void:
	var main := await _spawn_main()
	main.state.unlocked_store_ids[&"toy"] = true
	main.state.store_unlock_days[&"toy"] = 1
	main.state.available_owner_request_ids[&"toy_owner"] = true
	main._show_shop_immediate(&"toy")
	await get_tree().process_frame
	var shop := main.current_screen as QuestShopScreen
	assert_true(shop.talk_request_dot.visible)
	for press_index in 4:
		shop._on_owner_pressed()
		if main.state.task_instance_for_definition(&"owner_toy_birthday_cake") != null:
			break
	assert_false(shop.talk_request_dot.visible)
	assert_not_null(main.state.task_instance_for_definition(&"owner_toy_birthday_cake"))


func test_expedition_plays_confirmed_owner_request_before_showing_doors() -> void:
	var main := await _spawn_main()
	main.arc_fade_seconds = 0.0
	main.arc_typewriter_char_seconds = 0.0
	var task := main.state.activate_task(&"owner_toy_birthday_cake")
	var cake := main.state.grant_item(&"birthday_cake", &"test")
	assert_true(main.state.assign_card(task.instance_id, &"birthday_cake", cake).ok)
	assert_true(main.state.confirm_task(task.instance_id).ok)

	main._start_expedition()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(main.state.expedition.active)
	assert_true(main.arc_overlay.visible)
	assert_null(main.expedition_screen)
	assert_eq(main.arc_store_background.texture.resource_path, "res://resources/background/toystore.png")
	assert_eq(main.arc_owner_portrait.texture.resource_path, "res://resources/character/balloon-head.png")
	assert_eq(main.state.wallet.money, 0)

	main._on_arc_advance_requested()
	await get_tree().process_frame
	assert_eq(main.state.wallet.money, 20)
	assert_true(task.settled)
	assert_null(main.state.card_by_instance_id(cake.instance_id))
	assert_false(main.arc_reward_label.text.is_empty())
	main._on_arc_advance_requested()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(main.arc_overlay.visible)
	assert_not_null(main.expedition_screen)
	assert_eq(main.state.day, 1)


func test_flower_owner_reward_uses_a_gardenia_flip_before_the_doors() -> void:
	var main := await _spawn_main()
	main.arc_fade_seconds = 0.0
	main.arc_typewriter_char_seconds = 0.0
	var task := main.state.activate_task(&"owner_flower_teddy")
	var bear := main.state.grant_item(&"cold_teddy_bear", &"test")
	assert_true(main.state.assign_card(task.instance_id, &"teddy", bear).ok)
	assert_true(main.state.confirm_task(task.instance_id).ok)

	main._start_expedition()
	await get_tree().process_frame
	await get_tree().process_frame
	main._on_arc_advance_requested()
	await get_tree().process_frame
	assert_true(main.arc_reward_reveal_overlay.visible)
	assert_true(main.arc_reward_reveal_back.visible)
	assert_eq(main.arc_reward_reveal_card.definition.id, &"gardenia")
	main._flip_arc_reward_reveal()
	assert_true(main.arc_reward_reveal_card.visible)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._on_arc_reward_reveal_input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(main.arc_reward_reveal_overlay.visible)
	assert_false(main.arc_overlay.visible)
	assert_not_null(main.expedition_screen)


func test_language_debug_button_refreshes_the_active_expedition_in_place() -> void:
	var original_locale := LocaleManager.current_locale
	var target_locale := (
		LocaleManager.LOCALE_EN
		if original_locale == LocaleManager.LOCALE_ZH
		else LocaleManager.LOCALE_ZH
	)
	var main := await _spawn_main()
	main.state.expedition.begin_night(1, 4)
	main.state.expedition.current_door_ids = [&"gray_hall"]
	main._show_expedition_immediate()
	await get_tree().process_frame
	main.expedition_screen._enter_room(&"gray_hall")
	main.language_button.pressed.emit()
	assert_eq(LocaleManager.current_locale, target_locale)
	assert_eq(
		main.expedition_screen.room_title.text,
		TranslationServer.translate(&"expedition.room.gray_hall.name"),
	)
	assert_eq(
		main.expedition_screen.narrative_display_text,
		TranslationServer.translate(&"expedition.room.gray_hall.intro.1"),
	)
	LocaleManager.set_locale(original_locale, false)


func test_unknown_door_uses_white_asset_and_name_only_appears_on_hover() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 5)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	var door := screen.door_host.get_child(0) as QuestExpeditionDoor
	assert_eq(
		door.door_button.texture_normal.resource_path,
		"res://resources/ui/expedition/doorclosed.png",
	)
	assert_false(door.name_label.visible)
	door._on_hover_changed(true)
	assert_true(door.name_label.visible)
	assert_eq(door.name_label.text, TranslationServer.translate(&"expedition.ui.unknown"))


func test_discovered_door_uses_category_color_and_reveals_room_name() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 6)
	state.expedition.discovered_room_ids[&"gray_hall"] = true
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	var door := screen.door_host.get_child(0) as QuestExpeditionDoor
	assert_eq(
		door.door_button.texture_normal.resource_path,
		"res://resources/ui/expedition/redclose.png",
	)
	door._on_hover_changed(true)
	assert_eq(
		door.name_label.text,
		TranslationServer.translate(&"expedition.room.gray_hall.name"),
	)


func test_first_boss_door_is_red_but_still_named_unknown() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 7)
	state.expedition.current_door_ids = [&"scanner"]
	var screen := await _spawn_screen(state)
	var door := screen.door_host.get_child(0) as QuestExpeditionDoor
	assert_eq(
		door.door_button.texture_normal.resource_path,
		"res://resources/ui/expedition/redclose.png",
	)
	door._on_hover_changed(true)
	assert_eq(door.name_label.text, TranslationServer.translate(&"expedition.ui.unknown"))


func test_challenge_flow_exposes_two_irreversible_approaches_slots_and_feedback() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 9)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.INTRO)
	assert_true(screen.narrative_typing)
	var first_visible_character_count := screen.narrative_label.visible_characters
	await get_tree().create_timer(0.06).timeout
	assert_gt(
		screen.narrative_label.visible_characters,
		first_visible_character_count,
	)
	screen._on_action_pressed()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.INTRO)
	assert_false(screen.narrative_typing)
	assert_true(screen.narrative_holding)
	assert_eq(screen.narrative_segment_index, 0)
	assert_true(screen.narrative_label.text.ends_with(QuestExpeditionScreen.NARRATIVE_CURSOR))
	screen._toggle_narrative_cursor()
	assert_false(screen.narrative_label.text.ends_with(QuestExpeditionScreen.NARRATIVE_CURSOR))
	screen._on_action_pressed()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.INTRO)
	assert_true(screen.narrative_typing)
	assert_eq(screen.narrative_segment_index, 1)
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.CHALLENGE_INTRO)
	assert_false(screen.approach_row.visible)
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.APPROACH)
	assert_true(screen.approach_row.visible)
	assert_eq(screen.approach_buttons.size(), 2)
	screen._choose_approach(0)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.SLOTS)
	assert_true(screen.slot_row.visible)
	assert_eq(screen.feedback_label.text, TranslationServer.translate(&"expedition.feedback.hopeless"))
	assert_false(screen.action_button.disabled)


func test_blank_background_click_obeys_sentence_boundaries() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 10)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._on_background_input(click)
	assert_false(screen.narrative_typing)
	assert_true(screen.narrative_holding)
	assert_eq(screen.narrative_segment_index, 0)
	screen._on_background_input(click)
	assert_true(screen.narrative_typing)
	assert_eq(screen.narrative_segment_index, 1)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.INTRO)


func test_failed_challenge_is_only_committed_after_reward_is_collected_and_room_left() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 13)
	state.expedition.current_door_ids = [&"birthday_party"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"birthday_party")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(1)
	screen._submit_slots()
	assert_false(state.expedition.is_discovered(&"birthday_party"))
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.ROUND_RESULT)
	assert_false(screen.reward_host.visible)
	_advance_text_phase(screen)
	assert_eq(screen.reward_card.definition.id, &"expedition_wound")
	screen._flip_reward()
	screen._on_reward_collected()
	screen._leave_room()
	assert_true(state.expedition.is_discovered(&"birthday_party"))
	assert_eq(state.inventory[-1].definition_id, &"expedition_wound")


func test_room_draft_does_not_mutate_card_location_or_persistent_inventory() -> void:
	var state := QuestGameState.new()
	var card := state.inventory[0]
	state.expedition.begin_night(1, 21)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(0)
	screen.stage_card(0, card)
	assert_eq(card.location, CardItemState.Location.HAND)
	assert_true(state.inventory.has(card))
	assert_false(state.expedition.is_discovered(&"gray_hall"))


func test_slot_drop_stages_and_dragging_the_staged_card_returns_it_to_hand() -> void:
	var state := QuestGameState.new()
	var card := state.inventory[0]
	state.expedition.begin_night(1, 29)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(0)
	var slot := screen.slots[0]
	var drag_data := {"kind": &"card_item", "card": card}
	assert_true(slot._can_drop_data(Vector2.ZERO, drag_data))
	slot._drop_data(Vector2.ZERO, drag_data)
	assert_eq(screen.staged_entries[0].card, card)
	assert_eq(card.location, CardItemState.Location.HAND)
	slot._on_card_drag_started(card)
	assert_true(screen.staged_entries[0].is_empty())
	assert_eq(card.location, CardItemState.Location.HAND)


func test_room_phase_copy_refreshes_when_locale_changes_live() -> void:
	var original_locale := LocaleManager.current_locale
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 31)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	_advance_text_phase(screen)
	var chinese_narrative := screen.narrative_label.text
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	assert_eq(
		screen.room_title.text,
		TranslationServer.translate(screen.room.display_name_key),
	)
	assert_eq(
		screen.narrative_display_text,
		TranslationServer.translate(screen.room.challenge_text_keys[0]),
	)
	assert_eq(screen.narrative_segment_index, 0)
	assert_true(screen.narrative_holding)
	assert_ne(screen.narrative_display_text, chinese_narrative)
	assert_eq(
		screen.action_button.text,
		TranslationServer.translate(&"expedition.ui.continue"),
	)
	LocaleManager.set_locale(original_locale, false)


func test_first_shape_growth_leaves_the_rest_room_without_a_reveal() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 0
	var cactus := state.grant_item(&"cactus", &"test")
	state.expedition.begin_night(1, 44)
	state.expedition.current_door_ids = [&"home"]
	var screen := await _spawn_screen(state)
	watch_signals(screen)
	screen._enter_room(&"home")
	_advance_text_phase(screen)
	screen.stage_card(0, cactus)
	screen._preview_rest_result()
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DOORS)
	assert_false(screen.room_panel.visible)
	assert_true(state.expedition.is_discovered(&"home"))
	assert_signal_not_emitted(screen, "persona_reveal_requested")
	assert_true(state.pending_persona_reveal_shape_ids.is_empty())


func test_work_room_flips_twenty_wage_then_commits_money_on_leave() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 52)
	state.expedition.current_door_ids = [&"shelf_shift"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"shelf_shift")
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.REWARD)
	assert_true(screen.reward_back.visible)
	screen._flip_reward()
	assert_true(screen.reward_collected)
	assert_eq(state.wallet.money, 0)
	screen._leave_room()
	assert_eq(state.wallet.money, 20)
	assert_true(state.expedition.is_discovered(&"shelf_shift"))


func test_empty_rainforest_submission_previews_and_commits_twenty_without_disease() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 53)
	state.expedition.current_door_ids = [&"rainforest"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"rainforest")
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.SLOTS)
	assert_false(screen.action_button.disabled)
	screen._preview_rest_result()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.REST_RESULT)
	assert_eq(
		screen.narrative_display_text,
		TranslationServer.translate(&"expedition.room.rest.empty_result"),
	)
	screen._leave_room()
	assert_eq(state.wallet.money, 20)
	assert_eq(state.disease_count(&"white_flower"), 0)


func test_boss_ui_runs_two_rounds_before_demo_completion() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 5
	state.expedition.begin_night(1, 61)
	state.expedition.current_door_ids = [&"scanner"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"scanner")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	var persona_card := PersonaCardCatalog.card_for_shape(&"light")
	for round_index in 2:
		screen._choose_approach(round_index % 2)
		screen.stage_card(0, persona_card)
		screen._submit_slots()
		assert_eq(screen.phase, QuestExpeditionScreen.Phase.ROUND_RESULT)
		if round_index < 1:
			assert_true(screen._has_next_boss_round())
			_advance_text_phase(screen)
			assert_eq(screen.phase, QuestExpeditionScreen.Phase.APPROACH)
		else:
			assert_false(screen._has_next_boss_round())
			_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.REWARD)
	assert_eq(screen.reward_card.definition.id, &"expedition_salvage")
	screen._flip_reward()
	assert_true(
		screen.reward_target._can_drop_data(
			Vector2.ZERO,
			{"kind": &"expedition_reward", "reward_id": &"expedition_salvage"},
		)
	)
	screen._on_reward_collected()
	screen._leave_room()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DEMO_COMPLETE)
	assert_true(state.expedition.boss_cleared)


func test_main_does_not_show_persona_reveal_after_rest_growth() -> void:
	var main := await _spawn_main()
	main.state.protagonist_shape_levels[&"light"] = 0
	var cactus := main.state.grant_item(&"cactus", &"test")
	main.state.expedition.begin_night(1, 71)
	main.state.expedition.current_door_ids = [&"home"]
	main._show_expedition_immediate()
	await get_tree().process_frame
	var screen := main.expedition_screen
	screen._enter_room(&"home")
	_advance_text_phase(screen)
	screen.stage_card(0, cactus)
	screen._preview_rest_result()
	_advance_text_phase(screen)
	assert_false(main.persona_reveal_overlay.visible)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DOORS)


func test_lethal_disease_enters_a_persistent_arc_ending_instead_of_doors() -> void:
	var state := QuestGameState.new()
	state.gain_disease(&"expedition_wound", 3)
	assert_true(state.begin_mall_expedition(818).game_over)
	var screen := await _spawn_screen(state)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DISEASE_END)
	assert_true(screen.demo_panel.visible)
	assert_false(screen.hand_bar.visible)
	assert_eq(
		(screen.demo_panel.get_node("DemoCompleteLabel") as Label).text,
		TranslationServer.translate(&"expedition.ui.disease_end.expedition_wound"),
	)


func test_map_confirmation_warns_about_the_specific_lethal_disease() -> void:
	var state := QuestGameState.new()
	state.gain_disease(&"white_flower", 3)
	var map := QuestMapScreen.new()
	map.setup(state)
	add_child_autofree(map)
	await get_tree().process_frame
	map._refresh_expedition_text()
	assert_eq(
		map.expedition_confirm_dialog.dialog_text,
		TranslationServer.translate(&"expedition.ui.confirm_enter.lethal_white_flower"),
	)


func test_outputless_disease_synthesis_returns_directly_to_the_draft() -> void:
	var main := await _spawn_main()
	main._show_synthesis_immediate()
	await get_tree().process_frame
	var synthesis := main.current_screen as QuestSynthesisInterface
	var gained := main.state.gain_disease(&"white_flower")
	var flower := main.state.card_by_instance_id(int(gained.granted_instance_ids[0]))
	var cactus := main.state.grant_item(&"cactus", &"test")
	assert_true(main.state.assign_synthesis_base(flower).ok)
	assert_true(main.state.assign_synthesis_helper(cactus).ok)
	assert_true(main.state.select_synthesis_persona(&"light"))
	assert_true(
		main.state.select_synthesis_candidate(&"recipe_clear_white_flower_light")
	)
	synthesis._on_action_pressed()
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.NARRATIVE)
	assert_null(synthesis.pending_output)
	synthesis._advance_narrative()
	synthesis._advance_narrative()
	assert_eq(synthesis.phase, QuestSynthesisInterface.Phase.DRAFT)
	assert_true(synthesis.draft_layer.visible)
	assert_false(synthesis.result_layer.visible)


func _spawn_main() -> QuestMain:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	return main


func _spawn_screen(state: QuestGameState) -> QuestExpeditionScreen:
	var screen := QuestExpeditionScreen.new()
	screen.setup(state)
	add_child_autoqfree(screen)
	await get_tree().process_frame
	return screen


func _advance_text_phase(screen: QuestExpeditionScreen) -> void:
	while screen.narrative_typing or screen._has_next_narrative_segment():
		if screen.narrative_typing:
			screen._finish_narrative_typewriter()
		if screen._has_next_narrative_segment():
			screen._on_action_pressed()
	screen._on_action_pressed()
