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


func test_challenge_flow_exposes_two_irreversible_approaches_slots_and_feedback() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 9)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.INTRO)
	screen._on_action_pressed()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.CHALLENGE_INTRO)
	assert_false(screen.approach_row.visible)
	screen._on_action_pressed()
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
	screen._on_action_pressed()
	screen._on_action_pressed()
	screen._choose_approach(1)
	screen._submit_slots()
	assert_false(state.expedition.is_discovered(&"aquarium"))
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
	screen._on_action_pressed()
	screen._on_action_pressed()
	screen._choose_approach(0)
	screen.stage_card(0, card)
	assert_eq(card.location, CardItemState.Location.HAND)
	assert_true(state.inventory.has(card))
	assert_false(state.expedition.is_discovered(&"gray_hall"))


func test_room_phase_copy_refreshes_when_locale_changes_live() -> void:
	var original_locale := LocaleManager.current_locale
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 31)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	screen._on_action_pressed()
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
