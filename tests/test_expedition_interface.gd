extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_empty_expedition_slot_plus_uses_the_full_centered_slot_rect() -> void:
	var slot := QuestExpeditionCardSlot.new()
	add_child_autofree(slot)
	await get_tree().process_frame
	assert_eq(slot.empty_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(slot.empty_label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	assert_eq(slot.empty_label.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(slot.empty_label.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_almost_eq(
		slot.empty_label.get_global_rect().get_center().x,
		slot.get_global_rect().get_center().x,
		0.01,
	)


func test_map_exposes_distinct_expedition_entrance_and_main_enters_full_screen_mode() -> void:
	var main := await _spawn_main()
	assert_not_null(main.map_screen.expedition_button)
	assert_false(main.map_screen.expedition_button.visible)
	assert_eq(
		main.map_screen.expedition_button.text,
		TranslationServer.translate(&"expedition.ui.enter"),
	)
	main._show_shop_immediate(&"toy")
	await get_tree().process_frame
	assert_true(main.state.has_visited_store(&"toy"))
	main._show_map_immediate()
	await get_tree().process_frame
	assert_true(main.map_screen.expedition_button.visible)
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
	assert_eq(main.state.wallet.money, 40)

	main._on_arc_advance_requested()
	await get_tree().process_frame
	assert_eq(main.state.wallet.money, 60)
	assert_true(task.settled)
	assert_null(main.state.card_by_instance_id(cake.instance_id))
	assert_eq(
		main.arc_reward_label.text,
		TranslationServer.translate(&"demo.ui.arc.money_reward") % 20,
	)
	assert_eq(main.arc_persona_growth_rows.get_child_count(), 1)
	var persona_growth_label := main.arc_persona_growth_rows.get_child(0) as Label
	assert_eq(
		persona_growth_label.text,
		TranslationServer.translate(&"demo.ui.arc.stat_reward") % [
			TranslationServer.translate(&"demo.persona.nightwatcher.name"),
			1,
		],
	)
	assert_eq(
		persona_growth_label.get_theme_color("font_color"),
		ShapeVisuals.color(CardPropertySet.SHAPE_TEAR),
	)
	var original_locale: String = LocaleManager.current_locale
	var alternate_locale: String = (
		LocaleManager.LOCALE_EN
		if original_locale == LocaleManager.LOCALE_ZH
		else LocaleManager.LOCALE_ZH
	)
	LocaleManager.set_locale(alternate_locale, false)
	persona_growth_label = main.arc_persona_growth_rows.get_child(0) as Label
	assert_eq(
		persona_growth_label.text,
		TranslationServer.translate(&"demo.ui.arc.stat_reward") % [
			TranslationServer.translate(&"demo.persona.nightwatcher.name"),
			1,
		],
	)
	assert_eq(
		persona_growth_label.get_theme_color("font_color"),
		ShapeVisuals.color(CardPropertySet.SHAPE_TEAR),
	)
	LocaleManager.set_locale(original_locale, false)
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
	assert_true(screen.narrative_display_text.contains("[b]"))
	assert_false(screen.narrative_label.get_parsed_text().contains("[b]"))
	assert_eq(
		screen.feedback_label.text,
		TranslationServer.translate(&"expedition.feedback.missing_input"),
	)
	assert_eq(screen.feedback_label.get_theme_color("font_color"), QuestExpeditionScreen.MUTED)
	var tape := state.grant_item(&"goldberg_variations", &"test")
	screen.stage_card(0, tape)
	assert_eq(
		screen.feedback_label.text,
		TranslationServer.translate(&"expedition.feedback.light.maybe"),
	)
	assert_eq(
		screen.feedback_label.get_theme_color("font_color"),
		ShapeVisuals.color(&"light"),
	)
	assert_false(screen.action_button.disabled)


func test_challenge_slot_focus_reuses_rule_popup_and_highlights_only_usable_cards() -> void:
	var state := QuestGameState.new()
	var usable_card := state.inventory[0]
	var disease_result := state.gain_disease(&"white_flower")
	var disease_card := state.card_by_instance_id(int(disease_result.granted_instance_ids[0]))
	var keepsake_card := state.grant_item(&"concrete_city_vol_2", &"test")
	state.expedition.begin_night(1, 109)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(0)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.slots[0]._on_gui_input(click)

	assert_true(screen.rule_detail_popup.visible)
	assert_eq(screen.focused_slot_index, 0)
	assert_eq(
		screen.rule_detail_popup.title_label.text,
		TranslationServer.translate(&"expedition.ui.slot.rule"),
	)
	assert_eq(
		screen.rule_detail_popup.current_rule.forbidden_any,
		[CardPropertySet.PROPERTY_DISEASE, CardPropertySet.PROPERTY_KEEPSAKE],
	)
	var usable_view := screen.hand_bar.card_views[usable_card.instance_id] as CardHandCard
	var disease_view := screen.hand_bar.card_views[disease_card.instance_id] as CardHandCard
	var keepsake_view := screen.hand_bar.card_views[keepsake_card.instance_id] as CardHandCard
	assert_true(usable_view.rule_match_highlighted)
	assert_lt(usable_view.offset_top, 0.0)
	assert_false(disease_view.rule_match_highlighted)
	assert_false(keepsake_view.rule_match_highlighted)
	assert_false(screen.rule_detail_popup.required_scroll.visible)
	assert_true(screen.rule_detail_popup.required_summary.visible)
	assert_eq(screen.rule_detail_popup.required_summary.get_child_count(), 1)
	var rejected_row := screen.rule_detail_popup.required_summary.get_child(0) as HBoxContainer
	assert_eq(
		(rejected_row.get_child(0) as Label).text,
		TranslationServer.translate(&"expedition.ui.slot.rejects"),
	)
	assert_eq((rejected_row.get_child(1) as HBoxContainer).get_child_count(), 2)


func test_restaurant_slot_focus_uses_room_types_and_background_clears_focus() -> void:
	var state := QuestGameState.new()
	var toy_card := state.inventory[0]
	var food_card := state.grant_item(&"mung_bean_cake", &"test")
	var wound_card := state.grant_item(&"expedition_wound", &"test")
	var white_flower_card := state.grant_item(&"white_flower", &"test")
	state.expedition.begin_night(1, 110)
	state.expedition.current_door_ids = [&"retro_restaurant"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"retro_restaurant")
	_advance_text_phase(screen)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.slots[0]._on_gui_input(click)

	assert_eq(
		screen.rule_detail_popup.current_rule.allowed_any,
		[&"food", &"drink"],
	)
	assert_eq(
		screen.rule_detail_popup.current_rule.accepted_item_ids,
		[],
	)
	assert_eq(
		screen.rule_detail_popup.current_rule.rejected_item_ids,
		[],
	)
	assert_eq(
		screen.rule_detail_popup.current_rule.hidden_detail_item_ids,
		[],
	)
	var food_view := screen.hand_bar.card_views[food_card.instance_id] as CardHandCard
	var toy_view := screen.hand_bar.card_views[toy_card.instance_id] as CardHandCard
	var wound_view := screen.hand_bar.card_views[wound_card.instance_id] as CardHandCard
	var white_flower_view := (
		screen.hand_bar.card_views[white_flower_card.instance_id] as CardHandCard
	)
	assert_true(food_view.rule_match_highlighted)
	assert_false(wound_view.rule_match_highlighted)
	assert_false(toy_view.rule_match_highlighted)
	assert_false(white_flower_view.rule_match_highlighted)
	assert_false(screen.rule_detail_popup.required_scroll.visible)
	assert_true(screen.rule_detail_popup.required_summary.visible)
	assert_eq(screen.rule_detail_popup.required_summary.get_child_count(), 1)
	var accepted_row := screen.rule_detail_popup.required_summary.get_child(0) as HBoxContainer
	assert_eq(
		(accepted_row.get_child(0) as Label).text,
		TranslationServer.translate(&"expedition.ui.slot.accepts"),
	)
	assert_eq((accepted_row.get_child(1) as HBoxContainer).get_child_count(), 2)

	screen._on_background_input(click)
	assert_false(screen.rule_detail_popup.visible)
	assert_eq(screen.focused_slot_index, -1)
	assert_false(food_view.rule_match_highlighted)


func test_expedition_slot_summary_groups_accepts_and_rejects_on_separate_lines() -> void:
	var popup := QuestRuleDetailPopup.new()
	add_child_autofree(popup)
	await get_tree().process_frame
	var rule := CardSlotRule.new()
	rule.id = &"test_mixed_expedition_slot"
	rule.detail_title_key = &"expedition.ui.slot.rule"
	rule.required_label_key = &"expedition.ui.slot.accepts"
	rule.allowed_label_key = &"expedition.ui.slot.accepts"
	rule.forbidden_label_key = &"expedition.ui.slot.rejects"
	rule.allowed_any = [&"food", &"drink"]
	rule.forbidden_any = [
		CardPropertySet.PROPERTY_DISEASE,
		CardPropertySet.PROPERTY_KEEPSAKE,
		CardPropertySet.PROPERTY_PERSONA,
	]

	popup.show_rule(rule)
	await get_tree().process_frame

	assert_false(popup.required_scroll.visible)
	assert_true(popup.required_summary.visible)
	assert_eq(popup.required_summary.get_child_count(), 2)
	var accepted_row := popup.required_summary.get_child(0) as HBoxContainer
	var rejected_row := popup.required_summary.get_child(1) as HBoxContainer
	assert_eq(
		(accepted_row.get_child(0) as Label).text,
		TranslationServer.translate(&"expedition.ui.slot.accepts"),
	)
	assert_eq(
		(rejected_row.get_child(0) as Label).text,
		TranslationServer.translate(&"expedition.ui.slot.rejects"),
	)
	var accepted_icons := accepted_row.get_child(1) as HBoxContainer
	var rejected_icons := rejected_row.get_child(1) as HBoxContainer
	assert_eq(accepted_icons.get_child_count(), 2)
	assert_eq(rejected_icons.get_child_count(), 3)
	assert_eq(accepted_icons.get_theme_constant("separation"), 9)
	assert_eq(rejected_icons.get_theme_constant("separation"), 9)
	assert_gt(rejected_row.global_position.y, accepted_row.global_position.y)
	assert_lte(
		accepted_row.get_combined_minimum_size().x,
		popup.panel.size.x - 14.0,
	)
	assert_lte(
		rejected_row.get_combined_minimum_size().x,
		popup.panel.size.x - 14.0,
	)


func test_spaceship_library_city_uses_one_room_image_for_every_stage() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 91)
	state.expedition.current_door_ids = [&"spaceship_library_city"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"spaceship_library_city")
	var expected_path := "res://resources/background/expedition/spaceship-library-city.png"
	assert_true(screen.room_image_texture.visible)
	assert_false(screen.room_image_label.visible)
	assert_eq(screen.room_image_texture.texture.resource_path, expected_path)
	assert_eq(
		screen.room_image_texture.stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED,
	)
	for stage_id in [&"intro", &"challenge", &"response", &"result"]:
		screen._set_room_image(stage_id)
		assert_true(screen.room_image_texture.visible, stage_id)
		assert_false(screen.room_image_label.visible, stage_id)
		assert_eq(screen.room_image_texture.texture.resource_path, expected_path, stage_id)


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


func test_failed_challenge_is_committed_when_reward_is_dragged_into_hand() -> void:
	var state := QuestGameState.new()
	state.gain_disease(&"white_flower")
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
	assert_true(state.expedition.is_discovered(&"birthday_party"))
	assert_eq(state.inventory[-1].definition_id, &"expedition_wound")
	assert_eq(state.disease_count(&"white_flower"), 0)
	assert_true(screen.disease_change_label.visible)
	assert_eq(
		screen.disease_change_label.text,
		TranslationServer.translate(&"expedition.disease.wound.removed_white_flower"),
	)
	assert_true(screen.hand_bar.card_views.has(state.inventory[-1].instance_id))
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
	assert_true(screen.hand_bar.temporarily_hidden_card_ids.has(card.instance_id))
	assert_false(screen.hand_bar.card_views.has(card.instance_id))
	slot.card_view._begin_drag_visual()
	assert_true(screen.staged_entries[0].is_empty())
	assert_true(screen.hand_bar._can_drop_data(Vector2.ZERO, drag_data))
	screen.hand_bar._drop_data(Vector2.ZERO, drag_data)
	slot.card_view._end_drag_visual(true)
	assert_false(slot.card_view.visible)
	assert_true(screen.hand_bar.card_views.has(card.instance_id))
	assert_eq(card.location, CardItemState.Location.HAND)
	screen.stage_card(0, card)
	assert_true(slot.card_view.visible)
	assert_almost_eq(slot.card_view.self_modulate.a, 1.0, 0.001)
	assert_eq(slot.card_view.mouse_filter, Control.MOUSE_FILTER_PASS)
	slot.card_view._begin_drag_visual()
	assert_true(screen.staged_entries[0].is_empty())
	assert_true(slot._can_drop_data(Vector2.ZERO, drag_data))
	slot._drop_data(Vector2.ZERO, drag_data)
	slot.card_view._end_drag_visual(true)
	assert_eq(screen.staged_entries[0].card, card)
	assert_true(slot.card_view.visible)
	assert_almost_eq(slot.card_view.self_modulate.a, 1.0, 0.001)
	assert_eq(slot.card_view.mouse_filter, Control.MOUSE_FILTER_PASS)


func test_staged_persona_leaves_hand_and_slot_to_slot_drag_has_one_visual_owner() -> void:
	var state := QuestGameState.new()
	var persona_card := PersonaCardCatalog.card_for_shape(&"light")
	state.expedition.begin_night(1, 30)
	state.expedition.current_door_ids = [&"birthday_party"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"birthday_party")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(1)
	var source_slot := screen.slots[0]
	var target_slot := screen.slots[1]
	source_slot._drop_data(Vector2.ZERO, {"kind": &"card_item", "card": persona_card})
	assert_true(screen.hand_bar.temporarily_hidden_card_ids.has(persona_card.instance_id))
	assert_false(screen.hand_bar.card_views.has(persona_card.instance_id))
	assert_true(source_slot.card_view.visible)

	source_slot.card_view._begin_drag_visual()
	var drag_data := {"kind": &"card_item", "card": persona_card}
	assert_true(target_slot._can_drop_data(Vector2.ZERO, drag_data))
	target_slot._drop_data(Vector2.ZERO, drag_data)
	source_slot.card_view._end_drag_visual(true)
	assert_true(screen.staged_entries[0].is_empty())
	assert_eq(screen.staged_entries[1].card, persona_card)
	assert_false(source_slot.card_view.visible)
	assert_true(target_slot.card_view.visible)
	assert_false(screen.hand_bar.card_views.has(persona_card.instance_id))


func test_missed_drag_from_slot_returns_only_to_hand_without_a_phantom() -> void:
	var state := QuestGameState.new()
	var card := state.inventory[0]
	state.expedition.begin_night(1, 33)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"gray_hall")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	screen._choose_approach(0)
	var slot := screen.slots[0]
	screen.stage_card(0, card)
	slot.card_view._begin_drag_visual()
	slot.card_view._end_drag_visual(false)
	assert_true(screen.staged_entries[0].is_empty())
	assert_false(slot.card_view.visible)
	assert_true(screen.hand_bar.card_views.has(card.instance_id))


func test_feedback_wraps_inside_the_right_column() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 31)
	state.expedition.current_door_ids = [&"gray_hall"]
	var screen := await _spawn_screen(state)
	assert_eq(screen.feedback_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(screen.feedback_label.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_lte(screen.feedback_label.size.x, screen.feedback_label.get_parent().size.x)


func test_reward_flip_is_below_right_copy_and_stays_collected_after_drag() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"sleep"] = 3
	state.expedition.begin_night(1, 32)
	state.expedition.current_door_ids = [&"birthday_party"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"birthday_party")
	screen.approach_index = 1
	screen.last_round_success = true
	screen.challenge_rounds = [{
		"approach_index": 1,
		"card_instance_ids": [],
		"persona_shape_ids": [&"sleep"],
	}]
	screen._show_reward(&"birthday_cake")
	assert_gt(screen.reward_host.get_global_rect().get_center().x, screen.size.x * 0.6)
	screen._flip_reward()
	var drag_data := {
		"kind": &"expedition_reward",
		"reward_id": &"birthday_cake",
		"card": screen.reward_card.card,
	}
	assert_true(screen.reward_target._can_drop_data(Vector2.ZERO, drag_data))
	screen.reward_card._begin_drag_visual()
	screen.reward_target._drop_data(Vector2.ZERO, drag_data)
	screen.reward_card._end_drag_visual(true)
	assert_true(screen.reward_collected)
	assert_false(screen.reward_card.visible)
	assert_false(screen.reward_target.visible)
	assert_true(screen.action_button.visible)
	assert_eq(state.inventory[-1].definition_id, &"birthday_cake")
	assert_true(screen.hand_bar.card_views.has(state.inventory[-1].instance_id))


func test_next_reward_reuse_restores_concrete_city_volume_two_drag_input() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"sleep"] = 3
	state.expedition.begin_night(1, 34)
	state.expedition.current_door_ids = [&"birthday_party"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"birthday_party")
	screen.approach_index = 1
	screen.last_round_success = true
	screen.challenge_rounds = [{
		"approach_index": 1,
		"card_instance_ids": [],
		"persona_shape_ids": [&"sleep"],
	}]
	screen._show_reward(&"birthday_cake")
	screen._flip_reward()
	var first_drag_data := {
		"kind": &"expedition_reward",
		"reward_id": &"birthday_cake",
		"card": screen.reward_card.card,
	}
	screen.reward_card._begin_drag_visual()
	screen.reward_target._drop_data(Vector2.ZERO, first_drag_data)
	screen.reward_card._end_drag_visual(true)
	assert_eq(screen.reward_card.self_modulate.a, 0.0)
	assert_eq(screen.reward_card.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	screen._show_reward(&"concrete_city_vol_2")
	screen._flip_reward()
	assert_eq(screen.reward_card.definition.id, &"concrete_city_vol_2")
	assert_true(screen.reward_card.visible)
	assert_true(screen.reward_card.drag_enabled)
	assert_almost_eq(screen.reward_card.self_modulate.a, 1.0, 0.001)
	assert_eq(screen.reward_card.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_true(screen.reward_target._can_drop_data(Vector2.ZERO, {
		"kind": &"expedition_reward",
		"reward_id": &"concrete_city_vol_2",
		"card": screen.reward_card.card,
	}))


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
		TranslationServer.translate(
			screen.room.challenge_round_at(0).challenge_text_keys[0]
		),
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
	assert_eq(screen.persona_growth_rows.get_child_count(), 1)
	var growth_label := screen.persona_growth_rows.get_child(0) as Label
	assert_eq(
		growth_label.text,
		TranslationServer.translate(&"demo.ui.arc.stat_reward") % [
			TranslationServer.translate(&"demo.persona.lamplighter.name"),
			1,
		],
	)
	assert_eq(
		growth_label.get_theme_color("font_color"),
		ShapeVisuals.color(CardPropertySet.SHAPE_LIGHT),
	)
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DOORS)
	assert_false(screen.room_panel.visible)
	assert_true(state.expedition.is_discovered(&"home"))
	assert_signal_not_emitted(screen, "persona_reveal_requested")
	assert_true(state.pending_persona_reveal_shape_ids.is_empty())


func test_work_room_writes_money_result_without_a_reward_flip() -> void:
	var state := QuestGameState.new()
	state.expedition.begin_night(1, 52)
	state.expedition.current_door_ids = [&"shelf_shift"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"shelf_shift")
	_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.WORK_RESULT)
	assert_false(screen.reward_host.visible)
	assert_eq(
		screen.narrative_display_text,
		TranslationServer.translate(&"expedition.room.work.result"),
	)
	assert_true(screen.narrative_display_text.contains("[money+20]"))
	assert_eq(state.wallet.money, 40)
	_advance_text_phase(screen)
	assert_eq(state.wallet.money, 60)
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
	assert_eq(state.wallet.money, 60)
	assert_eq(state.disease_count(&"white_flower"), 0)


func test_item_rest_without_growth_previews_and_heals_one_wound() -> void:
	var state := QuestGameState.new()
	for shape_id in CardPropertySet.SHAPES:
		state.protagonist_shape_levels[shape_id] = 10
	state.gain_disease(&"expedition_wound")
	var frog := state.inventory[0]
	state.expedition.begin_night(1, 55)
	state.expedition.current_door_ids = [&"home"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"home")
	_advance_text_phase(screen)
	screen.stage_card(0, frog)
	screen._preview_rest_result()
	assert_true(screen.current_rest_preview.shape_growth.is_empty())
	assert_true(screen.current_rest_preview.cleared_wound)
	assert_eq(
		screen.narrative_display_text,
		TranslationServer.translate(&"expedition.room.rest.no_growth_healed_wound"),
	)
	screen._leave_room()
	assert_eq(state.disease_count(&"expedition_wound"), 0)
	assert_eq(state.disease_count(&"white_flower"), 0)


func test_rainforest_persona_growth_reveals_one_white_flower_card() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 1
	state.expedition.begin_night(1, 54)
	state.expedition.current_door_ids = [&"rainforest"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"rainforest")
	_advance_text_phase(screen)
	screen.stage_card(0, PersonaCardCatalog.card_for_shape(&"light"))
	screen._preview_rest_result()
	assert_eq(screen.current_rest_preview.white_flower_amount, 1)
	screen._finish_narrative_typewriter()
	screen._on_action_pressed()
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.REWARD)
	assert_true(screen.reward_back.visible)
	assert_eq(screen.reward_card.definition.id, &"white_flower")
	screen._flip_reward()
	screen._on_reward_collected()
	assert_eq(state.disease_count(&"white_flower"), 1)


func test_boss_ui_runs_two_rounds_before_demo_completion() -> void:
	var state := QuestGameState.new()
	state.protagonist_shape_levels[&"light"] = 6
	state.protagonist_shape_levels[&"sleep"] = 6
	state.expedition.begin_night(1, 61)
	state.expedition.current_door_ids = [&"scanner"]
	var screen := await _spawn_screen(state)
	screen._enter_room(&"scanner")
	_advance_text_phase(screen)
	_advance_text_phase(screen)
	for round_index in 2:
		screen._choose_approach(0)
		var shape_id: StringName = &"light" if round_index == 0 else &"sleep"
		var persona_card := PersonaCardCatalog.card_for_shape(shape_id)
		screen.stage_card(0, persona_card)
		screen._submit_slots()
		assert_eq(screen.phase, QuestExpeditionScreen.Phase.ROUND_RESULT)
		if round_index < 1:
			assert_true(screen._has_next_boss_round())
			_advance_text_phase(screen)
			assert_eq(screen.phase, QuestExpeditionScreen.Phase.CHALLENGE_INTRO)
			_advance_text_phase(screen)
			assert_eq(screen.phase, QuestExpeditionScreen.Phase.APPROACH)
		else:
			assert_false(screen._has_next_boss_round())
			_advance_text_phase(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DEMO_COMPLETE)
	assert_true(state.expedition.boss_cleared)
	assert_false(screen.previous_night_button.visible)


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
	watch_signals(screen)
	assert_eq(screen.phase, QuestExpeditionScreen.Phase.DISEASE_END)
	assert_true(screen.demo_panel.visible)
	assert_false(screen.hand_bar.visible)
	assert_eq(
		screen.end_label.text,
		TranslationServer.translate(&"expedition.ui.disease_end.expedition_wound"),
	)
	assert_true(screen.previous_night_button.visible)
	assert_eq(
		screen.previous_night_button.text,
		TranslationServer.translate(&"expedition.ui.previous_night"),
	)
	screen.previous_night_button.pressed.emit()
	assert_signal_emitted(screen, "previous_night_requested")


func test_map_confirmation_warns_about_the_specific_lethal_disease() -> void:
	var state := QuestGameState.new()
	state.gain_disease(&"white_flower", 3)
	var map := QuestMapScreen.new()
	map.setup(state)
	add_child_autofree(map)
	await get_tree().process_frame
	map._refresh_expedition_text()
	assert_eq(
		map.expedition_confirm_dialog.warning_text,
		TranslationServer.translate(&"expedition.ui.confirm_enter.lethal_white_flower"),
	)


func test_map_confirmation_uses_compact_centered_paper_copy() -> void:
	var state := QuestGameState.new()
	state.mark_store_visited(&"toy")
	var map := QuestMapScreen.new()
	map.setup(state)
	add_child_autofree(map)
	await get_tree().process_frame
	var popup := map.expedition_confirm_dialog
	assert_null(popup.get_node_or_null("BackdropShade"))
	assert_eq(popup.paper_panel.size, popup.POPUP_SIZE)
	assert_eq(popup.paper_panel.texture.resource_path, popup.PAPER_TEXTURE.resource_path)
	var copy_column := popup.paper_panel.get_node("CenteredCopy") as Control
	var actions := popup.paper_panel.get_node("Actions") as Control
	assert_eq(Rect2(copy_column.position, copy_column.size), popup.COPY_COLUMN_RECT)
	assert_eq(Rect2(actions.position, actions.size), popup.ACTIONS_RECT)
	assert_gt(copy_column.position.y, 99.0)
	assert_gt(actions.position.y, copy_column.position.y + copy_column.size.y)
	assert_true(
		QuestArchiveWindow.BODY_BORDER_RECT.encloses(
			Rect2(actions.position, actions.size)
		)
	)
	assert_false(popup.primary_label.get_rect().intersects(popup.hint_label.get_rect()))
	assert_lt(
		copy_column.position.y + popup.hint_label.position.y + popup.hint_label.size.y,
		actions.position.y,
	)
	assert_eq(popup.primary_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(popup.hint_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_lt(
		popup.hint_label.get_theme_font_size("font_size"),
		popup.primary_label.get_theme_font_size("font_size"),
	)
	assert_eq(
		popup.dialog_text,
		TranslationServer.translate(&"expedition.ui.confirm_enter"),
	)
	assert_eq(
		popup.hint_text,
		TranslationServer.translate(&"expedition.ui.confirm_enter.hint"),
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
