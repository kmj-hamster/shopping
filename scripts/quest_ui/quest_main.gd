class_name QuestMain
extends Control

const UI_THEME: Theme = preload("res://resources/fonts/shancha_ui_theme.tres")

var state: QuestGameState
var current_screen: Control
var screen_host: Control
var map_screen: QuestMapScreen
var shop_screens: Dictionary = {}
var task_dock: QuestTaskDock
var synthesis_interface: QuestSynthesisInterface
var protagonist_button: TextureButton
var hand_bar: QuestHandBar
var detail_popup: ItemDetailPopup
var rule_detail_popup: QuestRuleDetailPopup
var money_label: Label
var day_label: Label
var next_day_button: Button
var debug_button_row: HBoxContainer
var language_button: Button
var clear_save_button: Button
var forbidden_cursor_texture: Texture2D
var next_day_dialog: ConfirmationDialog
var arc_overlay: ColorRect
var arc_day_label: Label
var arc_result_label: Label
var arc_money_label: Label
var arc_image: TextureRect
var arc_reward_label: Label
var arc_cursor_label: Label
var arc_cursor_tween: Tween
var transition_in_progress := false
var focused_rule: CardSlotRule
var synthesis_return_store_id: StringName
var arc_fade_seconds := 0.35
var arc_typewriter_char_seconds := 0.028
var arc_typing := false
var arc_skip_typing := false
var arc_waiting_for_click := false
var arc_continue_requested := false


func _ready() -> void:
	theme = UI_THEME
	state = GameState.quest_state
	state.clear_synthesis_draft()
	_configure_cursor()
	_build_shell()
	_build_global_interface()
	_bind_state()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_refresh_global_text()
	_show_map()
	if state.pending_arc != null:
		call_deferred("_resume_arc")


func _build_shell() -> void:
	var background := ColorRect.new()
	background.name = "NightMallBackground"
	background.color = Color("031216")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var left_glow := ColorRect.new()
	left_glow.color = Color("163b3b", 0.2)
	left_glow.anchor_right = 0.19
	left_glow.anchor_bottom = 1.0
	left_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_glow)

	var sidebar := PanelContainer.new()
	sidebar.name = "PersistentSidebar"
	sidebar.anchor_left = 0.018
	sidebar.anchor_top = 0.035
	sidebar.anchor_right = 0.18
	sidebar.anchor_bottom = 0.94
	sidebar.add_theme_stylebox_override(
		"panel",
		UiPalette.panel_style(Color("061b20", 0.88), Color("63867d", 0.72)),
	)
	add_child(sidebar)
	var sidebar_margin := MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 16)
	sidebar_margin.add_theme_constant_override("margin_right", 16)
	sidebar_margin.add_theme_constant_override("margin_top", 14)
	sidebar_margin.add_theme_constant_override("margin_bottom", 16)
	sidebar.add_child(sidebar_margin)
	var sidebar_column := VBoxContainer.new()
	sidebar_column.add_theme_constant_override("separation", 3)
	sidebar_margin.add_child(sidebar_column)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color("efd38a"))
	sidebar_column.add_child(money_label)
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 12)
	day_label.add_theme_color_override("font_color", Color("7f9c95"))
	sidebar_column.add_child(day_label)
	var sidebar_spacer := Control.new()
	sidebar_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_column.add_child(sidebar_spacer)
	next_day_button = Button.new()
	next_day_button.name = "NextDayButton"
	next_day_button.custom_minimum_size = Vector2(126, 126)
	next_day_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_day_button.add_theme_font_size_override("font_size", 18)
	next_day_button.add_theme_stylebox_override(
		"normal", UiPalette.round_button_style(Color("b69255"), Color("f0d69c"), 64)
	)
	next_day_button.add_theme_stylebox_override(
		"hover", UiPalette.round_button_style(Color("d0aa63"), Color("fff0c4"), 64)
	)
	next_day_button.pressed.connect(_on_next_day_pressed)
	sidebar_column.add_child(next_day_button)

	var screen_frame := PanelContainer.new()
	screen_frame.name = "ContentViewportFrame"
	screen_frame.anchor_left = 0.19
	screen_frame.anchor_top = 0.045
	screen_frame.anchor_right = 0.96
	screen_frame.anchor_bottom = 0.755
	screen_frame.add_theme_stylebox_override(
		"panel",
		UiPalette.panel_style(Color("061015", 0.98), Color("77958c", 0.78)),
	)
	add_child(screen_frame)
	var screen_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		screen_margin.add_theme_constant_override("margin_%s" % side, 6)
	screen_frame.add_child(screen_margin)
	screen_host = Control.new()
	screen_host.name = "ContentViewport"
	screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_host.clip_contents = true
	screen_margin.add_child(screen_host)

	protagonist_button = TextureButton.new()
	protagonist_button.name = "ProtagonistPortrait"
	protagonist_button.texture_normal = load("res://resources/character/bag-head.png") as Texture2D
	protagonist_button.texture_hover = load("res://resources/character/bag-light.png") as Texture2D
	protagonist_button.anchor_left = 0.79
	protagonist_button.anchor_top = 0.70
	protagonist_button.anchor_right = 0.99
	protagonist_button.anchor_bottom = 1.0
	protagonist_button.ignore_texture_size = true
	protagonist_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	protagonist_button.tooltip_text = TranslationServer.translate(&"quest.ui.synthesis.open")
	protagonist_button.pressed.connect(_show_synthesis)
	add_child(protagonist_button)

	debug_button_row = HBoxContainer.new()
	debug_button_row.name = "DebugButtonRow"
	debug_button_row.anchor_left = 0.004
	debug_button_row.anchor_top = 0.945
	debug_button_row.anchor_right = 0.17
	debug_button_row.anchor_bottom = 0.992
	debug_button_row.add_theme_constant_override("separation", 5)
	debug_button_row.z_index = 60
	add_child(debug_button_row)
	language_button = Button.new()
	language_button.name = "LanguageButton"
	language_button.custom_minimum_size = Vector2(42, 0)
	language_button.add_theme_font_size_override("font_size", 11)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	debug_button_row.add_child(language_button)
	clear_save_button = Button.new()
	clear_save_button.name = "ClearSaveButton"
	clear_save_button.custom_minimum_size = Vector2(104, 0)
	clear_save_button.add_theme_font_size_override("font_size", 11)
	clear_save_button.pressed.connect(_on_clear_save_pressed)
	debug_button_row.add_child(clear_save_button)

	next_day_dialog = ConfirmationDialog.new()
	next_day_dialog.confirmed.connect(_on_next_day_requested)
	add_child(next_day_dialog)


func _build_global_interface() -> void:
	task_dock = QuestTaskDock.new()
	task_dock.name = "QuestTaskDock"
	task_dock.setup(state)
	task_dock.rule_focused.connect(_on_rule_focused)
	task_dock.item_inspected.connect(_show_item)
	task_dock.owner_result_presented.connect(_on_owner_result_presented)
	add_child(task_dock)

	hand_bar = QuestHandBar.new()
	hand_bar.name = "QuestHandBar"
	hand_bar.anchor_left = 0.235
	hand_bar.anchor_top = 0.775
	hand_bar.anchor_right = 0.79
	hand_bar.anchor_bottom = 0.985
	hand_bar.setup(state)
	hand_bar.item_inspected.connect(_show_item)
	add_child(hand_bar)

	detail_popup = ItemDetailPopup.new()
	add_child(detail_popup)
	rule_detail_popup = QuestRuleDetailPopup.new()
	rule_detail_popup.name = "QuestRuleDetailPopup"
	add_child(rule_detail_popup)
	_build_arc_overlay()


func _bind_state() -> void:
	if state != null and not state.state_changed.is_connected(_refresh_global_text):
		state.state_changed.connect(_refresh_global_text)


func _show_map() -> void:
	_deactivate_current_screen()
	if map_screen == null:
		map_screen = QuestMapScreen.new()
		map_screen.name = "QuestMapScreen"
		map_screen.setup(state)
		map_screen.shop_requested.connect(_show_shop)
		map_screen.card_staging_changed.connect(_on_card_staging_changed)
		map_screen.rule_focused.connect(_on_rule_focused)
		screen_host.add_child(map_screen)
		map_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activate_screen(map_screen)
	map_screen.refresh()
	task_dock.set_store_context(&"")
	hand_bar.visible = true


func _show_shop(store_id: StringName) -> void:
	hand_bar.clear_temporarily_hidden_cards()
	_deactivate_current_screen()
	var shop := shop_screens.get(store_id) as QuestShopScreen
	if shop == null:
		shop = QuestShopScreen.new()
		shop.name = "%sShopScreen" % String(store_id).to_pascal_case()
		shop.setup(state, store_id)
		shop.leave_requested.connect(_show_map)
		shop.item_inspected.connect(_show_item)
		shop.checkout_completed.connect(_on_shop_checkout_completed)
		screen_host.add_child(shop)
		shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shop_screens[store_id] = shop
	_activate_screen(shop)
	shop.refresh()
	task_dock.set_store_context(store_id)
	shop.set_highlight_rule(focused_rule)
	hand_bar.visible = true


func _show_synthesis() -> void:
	if current_screen is QuestSynthesisInterface:
		_return_from_synthesis()
		return
	synthesis_return_store_id = (
		(current_screen as QuestShopScreen).store_id
		if current_screen is QuestShopScreen
		else &""
	)
	_deactivate_current_screen()
	if synthesis_interface == null:
		synthesis_interface = QuestSynthesisInterface.new()
		synthesis_interface.name = "QuestSynthesisInterface"
		synthesis_interface.setup(state)
		synthesis_interface.leave_requested.connect(_return_from_synthesis)
		synthesis_interface.item_inspected.connect(_show_item)
		synthesis_interface.card_staging_changed.connect(_on_card_staging_changed)
		synthesis_interface.details_cleared.connect(_close_detail_popups)
		screen_host.add_child(synthesis_interface)
		synthesis_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activate_screen(synthesis_interface)
	synthesis_interface.refresh()
	task_dock.set_store_context(&"")
	_on_rule_focused(null)
	hand_bar.visible = true


func _return_from_synthesis() -> void:
	if not synthesis_return_store_id.is_empty():
		_show_shop(synthesis_return_store_id)
	else:
		_show_map()


func _deactivate_current_screen() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		if current_screen is QuestSynthesisInterface:
			(current_screen as QuestSynthesisInterface).cancel_pending_inputs()
		elif current_screen is QuestMapScreen:
			(current_screen as QuestMapScreen)._close_location_popup()
		elif current_screen is QuestShopScreen:
			(current_screen as QuestShopScreen).cancel_pending_purchase()
		current_screen.visible = false
	current_screen = null
	if hand_bar != null:
		hand_bar.clear_temporarily_hidden_cards()
	if detail_popup != null:
		detail_popup.close()


func _activate_screen(screen: Control) -> void:
	if screen == null:
		return
	screen.visible = true
	current_screen = screen


func _show_item(definition: CardItemDefinition) -> void:
	if detail_popup.visible and detail_popup.current_definition == definition:
		detail_popup.close()
		return
	rule_detail_popup.close()
	detail_popup.show_item(definition)


func _on_shop_checkout_completed() -> void:
	_close_detail_popups()


func _close_detail_popups() -> void:
	detail_popup.close()
	rule_detail_popup.close()


func _on_card_staging_changed(card: CardItemState, staged: bool) -> void:
	hand_bar.set_card_temporarily_hidden(card, staged)


func _on_rule_focused(rule: CardSlotRule) -> void:
	focused_rule = rule
	hand_bar.set_highlight_rule(rule)
	if rule == null:
		rule_detail_popup.close()
	else:
		detail_popup.close()
		rule_detail_popup.show_rule(rule, _task_definition_for_rule(rule))
	if current_screen != null and current_screen.has_method("set_highlight_rule"):
		current_screen.set_highlight_rule(rule)


func _task_definition_for_rule(rule: CardSlotRule) -> TaskDefinition:
	if rule == null:
		return null
	for task in state.active_tasks():
		var definition := QuestArcCatalog.task_by_id(task.definition_id)
		if definition != null and rule in definition.slot_rules:
			return definition
	return null


func _on_owner_result_presented(store_id: StringName, text_key: StringName) -> void:
	if current_screen is QuestShopScreen and (current_screen as QuestShopScreen).store_id == store_id:
		(current_screen as QuestShopScreen).show_owner_result(text_key)


func _on_next_day_pressed() -> void:
	if transition_in_progress:
		return
	next_day_dialog.popup_centered(Vector2i(400, 180))


func _on_clear_save_pressed() -> void:
	if transition_in_progress:
		return
	GameState.start_new_game()
	get_tree().reload_current_scene()


func _on_next_day_requested() -> void:
	if transition_in_progress:
		return
	if current_screen is QuestSynthesisInterface:
		(current_screen as QuestSynthesisInterface).cancel_pending_inputs()
	elif current_screen is QuestMapScreen:
		(current_screen as QuestMapScreen)._close_location_popup()
	hand_bar.clear_temporarily_hidden_cards()
	detail_popup.close()
	rule_detail_popup.close()
	var result := state.begin_next_day()
	if result.ok:
		_run_arc()


func _resume_arc() -> void:
	if not transition_in_progress and state.pending_arc != null:
		_run_arc()


func _run_arc() -> void:
	transition_in_progress = true
	hand_bar.visible = false
	detail_popup.close()
	arc_day_label.text = TranslationServer.translate(&"quest.ui.arc.night") % state.day
	arc_result_label.text = ""
	arc_reward_label.text = ""
	arc_money_label.text = TranslationServer.translate(&"demo.ui.money") % state.wallet.money
	arc_overlay.visible = true
	arc_overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(arc_overlay, "modulate:a", 1.0, arc_fade_seconds)
	await fade.finished
	var applied := state.apply_arc_effects()
	if not applied.ok:
		push_error("Arc application failed: %s" % applied.reason)
		transition_in_progress = false
		return
	arc_money_label.text = TranslationServer.translate(&"demo.ui.money") % state.wallet.money
	if state.pending_arc.entries.is_empty():
		arc_image.texture = load("res://resources/character/bag-head.png") as Texture2D
		await _present_arc_text(TranslationServer.translate(&"quest.ui.arc.empty"))
	while state.pending_arc != null and state.pending_arc.next_entry_index < state.pending_arc.entries.size():
		var entry := state.pending_arc.entries[state.pending_arc.next_entry_index]
		_prepare_arc_entry(entry)
		await _present_arc_text(TranslationServer.translate(StringName(entry.result_text_key)))
		state.mark_arc_entry_shown()
	var finish := state.finish_arc()
	if not finish.ok:
		push_error("Arc finish failed: %s" % finish.reason)
		transition_in_progress = false
		return
	arc_day_label.text = TranslationServer.translate(&"quest.ui.arc.new_day") % state.day
	arc_money_label.text = TranslationServer.translate(&"demo.ui.money") % state.wallet.money
	arc_image.texture = load("res://resources/character/bag-head.png") as Texture2D
	arc_reward_label.text = ""
	await _present_arc_text(TranslationServer.translate(&"demo.ui.arc.new_day.body"))
	var fade_out := create_tween()
	fade_out.tween_property(arc_overlay, "modulate:a", 0.0, arc_fade_seconds)
	await fade_out.finished
	arc_overlay.visible = false
	transition_in_progress = false
	hand_bar.visible = true
	_show_map()


func _build_arc_overlay() -> void:
	arc_overlay = ColorRect.new()
	arc_overlay.name = "QuestArcOverlay"
	arc_overlay.color = Color("010204")
	arc_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	arc_overlay.z_index = 500
	arc_overlay.visible = false
	arc_overlay.gui_input.connect(_on_arc_gui_input)
	add_child(arc_overlay)
	arc_money_label = Label.new()
	arc_money_label.anchor_left = 0.035
	arc_money_label.anchor_top = 0.035
	arc_money_label.anchor_right = 0.22
	arc_money_label.anchor_bottom = 0.10
	arc_money_label.add_theme_font_size_override("font_size", 23)
	arc_money_label.add_theme_color_override("font_color", Color("e4c978"))
	arc_overlay.add_child(arc_money_label)
	var center := CenterContainer.new()
	center.anchor_left = 0.18
	center.anchor_top = 0.08
	center.anchor_right = 0.82
	center.anchor_bottom = 0.92
	arc_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(820, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 15)
	center.add_child(column)
	arc_day_label = Label.new()
	arc_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arc_day_label.add_theme_font_size_override("font_size", 16)
	arc_day_label.add_theme_color_override("font_color", Color("718582"))
	column.add_child(arc_day_label)
	var image_frame := PanelContainer.new()
	image_frame.name = "ArcImageFrame"
	image_frame.custom_minimum_size = Vector2(820, 230)
	image_frame.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("061116", 0.98), Color("647874", 0.7))
	)
	column.add_child(image_frame)
	arc_image = TextureRect.new()
	arc_image.name = "ArcResultImage"
	arc_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arc_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arc_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_frame.add_child(arc_image)
	arc_result_label = Label.new()
	arc_result_label.custom_minimum_size = Vector2(790, 92)
	arc_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	arc_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arc_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arc_result_label.add_theme_font_size_override("font_size", 23)
	arc_result_label.add_theme_color_override("font_color", Color("d7d0b9"))
	column.add_child(arc_result_label)
	arc_reward_label = Label.new()
	arc_reward_label.custom_minimum_size = Vector2(790, 32)
	arc_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	arc_reward_label.add_theme_font_size_override("font_size", 17)
	arc_reward_label.add_theme_color_override("font_color", Color("e4c978"))
	column.add_child(arc_reward_label)
	arc_cursor_label = Label.new()
	arc_cursor_label.text = "◆"
	arc_cursor_label.custom_minimum_size = Vector2(790, 24)
	arc_cursor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arc_cursor_label.add_theme_color_override("font_color", Color("9fb2ac"))
	arc_cursor_label.visible = false
	column.add_child(arc_cursor_label)


func _prepare_arc_entry(entry: Dictionary) -> void:
	arc_image.texture = null
	var item_ids := entry.get("item_definition_ids", []) as Array
	if not item_ids.is_empty():
		var definition := QuestArcCatalog.item_by_id(StringName(item_ids[0]))
		if definition != null:
			arc_image.texture = definition.image
	var reward_parts: Array[String] = []
	var reward_money := int(entry.get("reward_money", 0))
	if reward_money > 0:
		reward_parts.append(
			TranslationServer.translate(&"demo.ui.arc.money_reward") % reward_money
		)
	var reward_stats := entry.get("reward_stats", {}) as Dictionary
	for raw_stat_id in reward_stats:
		var stat_id := StringName(raw_stat_id)
		var property := QuestArcCatalog.property_by_id(stat_id)
		var stat_name := TranslationServer.translate(
			property.display_name_key
			if property != null
			else StringName("demo.stat.%s.name" % stat_id)
		)
		reward_parts.append(
			TranslationServer.translate(&"demo.ui.arc.stat_reward") % [
				stat_name,
				int(reward_stats[raw_stat_id]),
			]
		)
	arc_reward_label.text = "  ·  ".join(reward_parts)


func _present_arc_text(full_text: String) -> void:
	arc_result_label.text = ""
	arc_typing = true
	arc_skip_typing = false
	arc_waiting_for_click = false
	arc_continue_requested = false
	for index in full_text.length():
		if arc_skip_typing:
			break
		arc_result_label.text = full_text.substr(0, index + 1)
		if arc_typewriter_char_seconds > 0.0:
			await get_tree().create_timer(arc_typewriter_char_seconds).timeout
	arc_result_label.text = full_text
	arc_typing = false
	arc_waiting_for_click = true
	_start_arc_cursor()
	while not arc_continue_requested:
		await get_tree().process_frame
	arc_waiting_for_click = false
	arc_continue_requested = false
	_stop_arc_cursor()


func _on_arc_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var key := event as InputEventKey
	if (
		(mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed)
		or (key != null and key.pressed and not key.echo and key.is_action("ui_accept"))
	):
		_on_arc_advance_requested()


func _on_arc_advance_requested() -> void:
	if arc_typing:
		arc_skip_typing = true
	elif arc_waiting_for_click:
		arc_continue_requested = true


func _start_arc_cursor() -> void:
	_stop_arc_cursor()
	arc_cursor_label.visible = true
	arc_cursor_label.modulate.a = 1.0
	arc_cursor_tween = create_tween().set_loops()
	arc_cursor_tween.tween_property(arc_cursor_label, "modulate:a", 0.2, 0.42)
	arc_cursor_tween.tween_property(arc_cursor_label, "modulate:a", 1.0, 0.42)


func _stop_arc_cursor() -> void:
	if arc_cursor_tween != null and arc_cursor_tween.is_valid():
		arc_cursor_tween.kill()
	arc_cursor_tween = null
	if arc_cursor_label != null:
		arc_cursor_label.visible = false
		arc_cursor_label.modulate.a = 1.0


func _refresh_global_text() -> void:
	if state == null or money_label == null:
		return
	money_label.text = TranslationServer.translate(&"demo.ui.money") % state.wallet.money
	day_label.text = TranslationServer.translate(&"demo.ui.night") % state.day
	next_day_button.text = TranslationServer.translate(&"demo.ui.next_day")
	language_button.text = LocaleManager.switch_button_text()
	clear_save_button.text = TranslationServer.translate(&"demo.ui.clear_save")
	clear_save_button.tooltip_text = TranslationServer.translate(&"demo.ui.clear_save.tooltip")
	protagonist_button.tooltip_text = TranslationServer.translate(&"quest.ui.synthesis.open")
	next_day_dialog.title = TranslationServer.translate(&"demo.ui.next_day")
	next_day_dialog.dialog_text = TranslationServer.translate(&"demo.ui.next_day.question")
	next_day_dialog.ok_button_text = TranslationServer.translate(&"demo.ui.confirm")
	next_day_dialog.cancel_button_text = TranslationServer.translate(&"demo.ui.cancel")


func _configure_cursor() -> void:
	forbidden_cursor_texture = load("res://resources/ui/cursor-arrow.svg") as Texture2D
	if forbidden_cursor_texture != null:
		Input.set_custom_mouse_cursor(
			forbidden_cursor_texture,
			Input.CURSOR_FORBIDDEN,
			Vector2(1, 1),
		)


func _on_locale_changed(_locale: String) -> void:
	_refresh_global_text()
