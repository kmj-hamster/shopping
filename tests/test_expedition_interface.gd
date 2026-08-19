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
	screen._on_action_pressed()
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


func test_failed_challenge_is_only_committed_after_reward_is_collected_and_room_left() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 13)
	state.expedition.current_door_ids = [&"aquarium"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"aquarium")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(1)
	screen._submit_slots()
	assert_false(state.expedition.is_discovered(&"aquarium"))
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.ROUND_RESULT)
	assert_false(screen.reward_host.visible)
	_advance_text_phase(screen)
	assert_eq(screen.reward_card.definition.id, &"expedition_wound")
	screen._flip_reward()
	screen._on_reward_collected()
	screen._leave_room()
	assert_true(state.expedition.is_discovered(&"aquarium"))
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
	var english_lines: PackedStringArray = []
	for key in screen.room.challenge_text_keys:
		english_lines.append(TranslationServer.translate(key))
	assert_eq(
		screen.room_title.text,
		TranslationServer.translate(screen.room.display_name_key),
	)
	assert_eq(
		screen.narrative_label.text,
		"\n".join(english_lines),
	)
	assert_ne(screen.narrative_label.text, chinese_narrative)
	assert_eq(
		screen.action_button.text,
		TranslationServer.translate(&"expedition.ui.continue"),
	)
	LocaleManager.set_locale(original_locale, false)


func test_first_persona_reveal_holds_the_rest_room_before_next_doors() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"nightwalker"] = 0
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
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.WAITING_PERSONA_REVEAL)
	assert_signal_emitted(screen, "persona_reveal_requested")
	assert_true(state.pending_persona_reveal_ids.has(&"nightwalker"))
	assert_true(screen.room_panel.visible)
	state.acknowledge_persona_reveal(&"nightwalker")
	screen.on_persona_reveals_completed()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DOORS)
	assert_false(screen.room_panel.visible)
	assert_true(state.expedition.is_discovered(&"home"))


func test_work_room_flips_wage_then_commits_money_on_leave() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 52)
	state.expedition.current_door_ids = [&"cold_storage"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"cold_storage")
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.REWARD)
	assert_true(screen.reward_back.visible)
	screen._flip_reward()
	assert_true(screen.reward_collected)
	assert_eq(state.wallet.money, 0)
	screen._leave_room()
	assert_eq(state.wallet.money, 12)
	assert_true(state.expedition.is_discovered(&"cold_storage"))


func test_boss_ui_runs_three_rounds_before_demo_completion() -> void:
	var state := QuestGameState.new()
	state.protagonist_persona_counts[&"nightwalker"] = 5
	state.expedition.begin_night(1, 61)
	state.expedition.current_door_ids = [&"scanner"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"scanner")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	var persona_card := PersonaMaskCatalog.card_for_persona(&"nightwalker")
	for round_index in 3:
		screen._choose_approach(round_index % 2)
		screen.stage_card(0, persona_card)
		screen._submit_slots()
		assert_eq(screen.phase, QuestExpeditionScreen.Phase.ROUND_RESULT)
		if round_index < 2:
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


func test_main_persona_reveal_overlay_resumes_waiting_rest_room() -> void:
	var main := await _spawn_main()
	main.state.protagonist_persona_counts[&"nightwalker"] = 0
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
	assert_true(main.persona_reveal_overlay.visible)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.WAITING_PERSONA_REVEAL)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._on_persona_reveal_input(click)
	assert_true(main.persona_reveal_flipped)
	main._on_persona_reveal_input(click)
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
	assert_true(main.state.select_synthesis_persona(&"nightwalker"))
	assert_true(
		main.state.select_synthesis_candidate(&"recipe_clear_white_flower_nightwalker")
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
	screen._finish_narrative_typewriter()
	screen._on_action_pressed()
