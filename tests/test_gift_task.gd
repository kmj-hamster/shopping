extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.LEGACY_MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func before_each() -> void:
	GameState.reset_game()


func test_gift_task_preserves_flip_state_and_only_disappears_after_claimed_close() -> void:
	var original_locale := LocaleManager.current_locale
	var main := await _spawn_main()
	var task := main.state.task_instance_for_definition(&"tin_boy_gift")
	assert_not_null(task)
	assert_false(task.gift_revealed)
	assert_false(task.gift_claimed)
	assert_null(_card_by_definition(main.state, &"tin_frog"))

	main.task_dock._toggle_task(task.instance_id)
	var window := main.task_dock.task_window
	var gift_slot := window.gift_slot
	assert_not_null(gift_slot)
	assert_almost_eq(
		window.body_viewport.custom_minimum_size.y,
		PaperActivityPopup.LETTER_BODY_HEIGHT,
		0.01,
	)
	assert_almost_eq(
		window.size.y,
		main.task_popup_layer.size.y * (
			PaperActivityPopup.PAPER_ANCHOR_BOTTOM - PaperActivityPopup.PAPER_ANCHOR_TOP
		),
		0.5,
	)
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(window.body_label.get_line_count(), PaperActivityPopup.LETTER_BODY_MAX_LINES)
	assert_almost_eq(
		window.size.y,
		main.task_popup_layer.size.y * (
			PaperActivityPopup.PAPER_ANCHOR_BOTTOM - PaperActivityPopup.PAPER_ANCHOR_TOP
		),
		0.5,
	)
	LocaleManager.set_locale(original_locale, false)
	assert_true(gift_slot.back_button.visible)
	assert_false(gift_slot.card_view.visible)
	assert_eq(
		window.feedback_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.flip_result"),
	)

	window.closed.emit()
	assert_null(main.task_dock.task_window)
	assert_false(task.gift_revealed)
	assert_false(task.settled)

	main.task_dock._toggle_task(task.instance_id)
	window = main.task_dock.task_window
	gift_slot = window.gift_slot
	gift_slot.back_button.pressed.emit()
	assert_true(task.gift_revealed)
	assert_false(gift_slot.back_button.visible)
	assert_true(gift_slot.card_view.visible)
	assert_eq(gift_slot.card_view.definition.id, &"tin_frog")
	assert_eq(
		window.feedback_label.text,
		TranslationServer.translate(&"demo.ui.synthesis.drag_result"),
	)

	window.closed.emit()
	assert_true(task.gift_revealed)
	assert_false(task.gift_claimed)
	assert_false(task.settled)
	assert_null(_card_by_definition(main.state, &"tin_frog"))

	main.task_dock._toggle_task(task.instance_id)
	window = main.task_dock.task_window
	gift_slot = window.gift_slot
	assert_false(gift_slot.back_button.visible)
	assert_true(gift_slot.card_view.visible)
	var preview_card := gift_slot.virtual_card
	var drag_data := {"kind": &"card_item", "card": preview_card}
	assert_true(main.hand_bar._can_drop_data(Vector2.ZERO, drag_data))
	gift_slot.card_view._begin_drag_visual()
	main.hand_bar._drop_data(Vector2.ZERO, drag_data)
	gift_slot.card_view._end_drag_visual(true)
	await get_tree().process_frame

	assert_true(task.gift_claimed)
	assert_false(task.settled)
	assert_false(gift_slot.visible)
	assert_false(gift_slot.back_button.visible)
	assert_false(gift_slot.card_view.visible)
	var claimed_card := _card_by_definition(main.state, &"tin_frog")
	assert_not_null(claimed_card)
	assert_eq(claimed_card.location, CardItemState.Location.HAND)
	assert_true(main.hand_bar.card_views.has(claimed_card.instance_id))
	assert_false(main.hand_bar._can_drop_data(Vector2.ZERO, drag_data))

	window.closed.emit()
	assert_true(task.settled)
	assert_null(main.state.task_instance_for_definition(&"tin_boy_gift"))
	assert_false(main.task_dock.bookmark_buttons.has(task.instance_id))
	assert_same(_card_by_definition(main.state, &"tin_frog"), claimed_card)


func test_tin_frog_has_the_declared_properties() -> void:
	var frog := QuestArcCatalog.item_by_id(&"tin_frog")
	assert_not_null(frog)
	assert_true(frog.has_property(&"toy"))
	assert_true(frog.has_property(&"metal"))
	assert_eq(frog.property_value(CardPropertySet.ASPECT_LAMP), 2)


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
