class_name QuestMain
extends Control

signal arc_text_revealed
signal arc_text_advanced

const UI_THEME: Theme = preload("res://resources/fonts/shancha_ui_theme.tres")
const CONTENT_LEFT := 136.0 / 1920.0
const CONTENT_TOP := 97.0 / 1080.0
const CONTENT_RIGHT := 1780.0 / 1920.0
const CONTENT_BOTTOM := 920.0 / 1080.0

var state: QuestGameState
var current_screen: Control
var art_canvas: Control
var content_viewport_region: Control
var screen_host: Control
var task_popup_layer: Control
var global_frame: TextureRect
var global_shadow: TextureRect
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
var next_day_blocked_dialog: AcceptDialog
var screen_transition_overlay: ColorRect
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
var arc_waiting_for_click := false
var arc_typewriter_timer: Timer
var arc_typewriter_full_text := ""
var arc_typewriter_index := 0
var debug_hud_refresh_count := 0
var drag_return_layer: CanvasLayer
var drag_return_card: CardHandCard
var drag_return_tween: Tween
var drag_return_source: CardHandCard
var persona_reveal_overlay: ColorRect
var persona_reveal_title: Label
var persona_reveal_back: Button
var persona_reveal_card: CardHandCard
var persona_reveal_hint: Label
var persona_reveal_persona_id: StringName
var persona_reveal_flipped := false


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
	_show_map_immediate()
	if state.pending_arc != null:
		call_deferred("_resume_arc")
	elif not state.pending_persona_reveal_ids.is_empty():
		call_deferred("_run_pending_persona_reveals")


func _build_shell() -> void:
	var background := ColorRect.new()
	background.name = "NightMallBackground"
	background.color = Color("071923")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	art_canvas = Control.new()
	art_canvas.name = "ArtCanvas"
	art_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_canvas)

	content_viewport_region = Control.new()
	content_viewport_region.name = "ContentViewportRegion"
	content_viewport_region.anchor_left = CONTENT_LEFT
	content_viewport_region.anchor_top = CONTENT_TOP
	content_viewport_region.anchor_right = CONTENT_RIGHT
	content_viewport_region.anchor_bottom = CONTENT_BOTTOM
	content_viewport_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_viewport_region.clip_contents = true
	art_canvas.add_child(content_viewport_region)

	screen_host = Control.new()
	screen_host.name = "ContentViewport"
	screen_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_host.clip_contents = true
	content_viewport_region.add_child(screen_host)
	task_popup_layer = Control.new()
	task_popup_layer.name = "TaskPopupLayer"
	task_popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_popup_layer.clip_contents = true
	task_popup_layer.z_index = 80
	content_viewport_region.add_child(task_popup_layer)

	global_frame = TextureRect.new()
	global_frame.name = "ContentViewportFrame"
	global_frame.texture = load("res://resources/ui/shell/frame-global.png") as Texture2D
	global_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	global_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	global_frame.stretch_mode = TextureRect.STRETCH_SCALE
	global_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	global_frame.z_index = 30
	art_canvas.add_child(global_frame)

	protagonist_button = TextureButton.new()
	protagonist_button.name = "SynthesisBagButton"
	protagonist_button.texture_normal = load(
		"res://resources/ui/shell/bag-synthesis.png"
	) as Texture2D
	protagonist_button.texture_hover = protagonist_button.texture_normal
	protagonist_button.anchor_left = 0.79
	protagonist_button.anchor_top = 0.62
	protagonist_button.anchor_right = 0.985
	protagonist_button.anchor_bottom = 1.0
	protagonist_button.ignore_texture_size = true
	protagonist_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	protagonist_button.tooltip_text = TranslationServer.translate(&"quest.ui.synthesis.open")
	protagonist_button.pressed.connect(_show_synthesis)
	protagonist_button.z_index = 45
	art_canvas.add_child(protagonist_button)

	global_shadow = TextureRect.new()
	global_shadow.name = "GlobalShellShadow"
	global_shadow.texture = load("res://resources/ui/shell/shadow-global.png") as Texture2D
	global_shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	global_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	global_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	global_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	global_shadow.z_index = 60
	art_canvas.add_child(global_shadow)

	debug_button_row = HBoxContainer.new()
	debug_button_row.name = "DebugButtonRow"
	debug_button_row.anchor_left = 0.84
	debug_button_row.anchor_top = 0.008
	debug_button_row.anchor_right = 0.995
	debug_button_row.anchor_bottom = 0.052
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
	next_day_blocked_dialog = AcceptDialog.new()
	next_day_blocked_dialog.ok_button_text = TranslationServer.translate(&"demo.ui.confirm")
	add_child(next_day_blocked_dialog)


func _build_global_interface() -> void:
	task_dock = QuestTaskDock.new()
	task_dock.name = "QuestTaskDock"
	task_dock.setup(state, task_popup_layer)
	task_dock.rule_focused.connect(_on_rule_focused)
	task_dock.item_inspected.connect(_show_item)
	art_canvas.add_child(task_dock)

	hand_bar = QuestHandBar.new()
	hand_bar.name = "QuestHandBar"
	hand_bar.anchor_left = 0.15
	hand_bar.anchor_top = 0.775
	hand_bar.anchor_right = 0.82
	hand_bar.anchor_bottom = 0.998
	hand_bar.z_index = 45
	hand_bar.setup(state)
	hand_bar.item_inspected.connect(_show_item)
	hand_bar.card_drag_started.connect(_on_hand_card_drag_started)
	hand_bar.card_drag_finished.connect(_on_hand_card_drag_finished)
	art_canvas.add_child(hand_bar)

	detail_popup = ItemDetailPopup.new()
	add_child(detail_popup)
	rule_detail_popup = QuestRuleDetailPopup.new()
	rule_detail_popup.name = "QuestRuleDetailPopup"
	add_child(rule_detail_popup)
	_build_drag_return_layer()
	_build_screen_transition_overlay()
	_build_persona_reveal_overlay()
	_build_arc_overlay()


func _build_drag_return_layer() -> void:
	drag_return_layer = CanvasLayer.new()
	drag_return_layer.name = "CardDragReturnLayer"
	drag_return_layer.layer = 200
	add_child(drag_return_layer)
	drag_return_card = CardHandCard.new()
	drag_return_card.name = "CardDragReturnPreview"
	drag_return_card.drag_enabled = false
	drag_return_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_return_card.z_index = 4096
	drag_return_card.z_as_relative = false
	drag_return_card.visible = false
	drag_return_layer.add_child(drag_return_card)


func _build_screen_transition_overlay() -> void:
	screen_transition_overlay = ColorRect.new()
	screen_transition_overlay.name = "ScreenTransitionOverlay"
	screen_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_transition_overlay.color = Color("05090d")
	screen_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_transition_overlay.z_index = 400
	screen_transition_overlay.visible = false
	add_child(screen_transition_overlay)


func _run_screen_transition(
	switcher: Callable,
	fade_out_seconds: float,
	fade_in_seconds: float,
	color: Color = Color("05090d"),
	hold_seconds: float = 0.0,
) -> void:
	if transition_in_progress or not switcher.is_valid():
		return
	if not GameState.autosave_enabled:
		switcher.call()
		return
	transition_in_progress = true
	screen_transition_overlay.color = color
	screen_transition_overlay.modulate.a = 0.0
	screen_transition_overlay.visible = true
	var fade_out := create_tween()
	fade_out.tween_property(
		screen_transition_overlay, "modulate:a", 1.0, fade_out_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished
	switcher.call()
	if hold_seconds > 0.0:
		await get_tree().create_timer(hold_seconds).timeout
	var fade_in := create_tween()
	fade_in.tween_property(
		screen_transition_overlay, "modulate:a", 0.0, fade_in_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished
	screen_transition_overlay.visible = false
	transition_in_progress = false
func _build_persona_reveal_overlay() -> void:
	persona_reveal_overlay = ColorRect.new()
	persona_reveal_overlay.name = "PersonaRevealOverlay"
	persona_reveal_overlay.color = Color("02050a", 0.97)
	persona_reveal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	persona_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	persona_reveal_overlay.z_index = 450
	persona_reveal_overlay.visible = false
	persona_reveal_overlay.gui_input.connect(_on_persona_reveal_input)
	add_child(persona_reveal_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	persona_reveal_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	persona_reveal_title = Label.new()
	persona_reveal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	persona_reveal_title.add_theme_font_size_override("font_size", 24)
	persona_reveal_title.add_theme_color_override("font_color", Color("d8c480"))
	column.add_child(persona_reveal_title)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(220, 260)
	column.add_child(holder)
	persona_reveal_back = Button.new()
	persona_reveal_back.custom_minimum_size = Vector2(170, 230)
	persona_reveal_back.text = "◇\n◇\n◇"
	persona_reveal_back.add_theme_font_size_override("font_size", 30)
	persona_reveal_back.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("071013"), Color("8ba19a"))
	)
	persona_reveal_back.pressed.connect(_flip_persona_reveal)
	holder.add_child(persona_reveal_back)
	persona_reveal_card = CardHandCard.new()
	persona_reveal_card.drag_enabled = false
	persona_reveal_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	persona_reveal_card.scale = Vector2(1.5, 1.5)
	holder.add_child(persona_reveal_card)
	persona_reveal_hint = Label.new()
	persona_reveal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	persona_reveal_hint.add_theme_color_override("font_color", Color("9db0aa"))
	column.add_child(persona_reveal_hint)


func _run_pending_persona_reveals() -> void:
	if state.pending_persona_reveal_ids.is_empty():
		persona_reveal_overlay.visible = false
		return
	transition_in_progress = true
	persona_reveal_overlay.visible = true
	_show_next_persona_reveal()


func _show_next_persona_reveal() -> void:
	if state.pending_persona_reveal_ids.is_empty():
		persona_reveal_overlay.visible = false
		transition_in_progress = false
		return
	persona_reveal_persona_id = state.pending_persona_reveal_ids[0]
	persona_reveal_flipped = false
	persona_reveal_title.text = TranslationServer.translate(&"opening.ui.persona.reveal")
	persona_reveal_hint.text = TranslationServer.translate(&"opening.ui.persona.flip")
	persona_reveal_back.visible = true
	persona_reveal_card.visible = false
	var amount := int(state.protagonist_aspect_counts.get(persona_reveal_persona_id, 0))
	persona_reveal_card.setup(
		PersonaMaskCatalog.card_for_persona(persona_reveal_persona_id),
		PersonaMaskCatalog.definition_for_persona(persona_reveal_persona_id, amount),
		false,
	)


func _flip_persona_reveal() -> void:
	if persona_reveal_flipped:
		return
	persona_reveal_flipped = true
	persona_reveal_back.visible = false
	persona_reveal_card.visible = true
	persona_reveal_hint.text = TranslationServer.translate(&"opening.ui.persona.continue")


func _on_persona_reveal_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var key := event as InputEventKey
	if not (
		(click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed)
		or (key != null and key.pressed and not key.echo and key.is_action("ui_accept"))
	):
		return
	if not persona_reveal_flipped:
		_flip_persona_reveal()
		return
	state.acknowledge_persona_reveal(persona_reveal_persona_id)
	_show_next_persona_reveal()


func _bind_state() -> void:
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)


func _show_map() -> void:
	_run_screen_transition(Callable(self, "_show_map_immediate"), 0.16, 0.18)


func _show_map_immediate() -> void:
	_deactivate_current_screen()
	if map_screen == null:
		map_screen = QuestMapScreen.new()
		map_screen.name = "QuestMapScreen"
		map_screen.setup(state)
		map_screen.shop_requested.connect(_show_shop)
		map_screen.card_staging_changed.connect(_on_card_staging_changed)
		map_screen.rule_focused.connect(_on_rule_focused)
		map_screen.item_inspected.connect(_show_item)
		map_screen.background_pressed.connect(_on_activity_background_pressed)
		screen_host.add_child(map_screen)
		map_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activate_screen(map_screen)
	map_screen.refresh()
	hand_bar.visible = true


func _show_shop(store_id: StringName) -> void:
	var first_visit := not state.has_visited_store(store_id)
	_run_screen_transition(
		Callable(self, "_show_shop_immediate").bind(store_id),
		0.42 if first_visit else 0.16,
		0.50 if first_visit else 0.18,
		Color("05090d") if not first_visit else Color("18110b"),
		0.12 if first_visit else 0.0,
	)


func _show_shop_immediate(store_id: StringName) -> void:
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
		shop.background_pressed.connect(_on_activity_background_pressed)
		screen_host.add_child(shop)
		shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shop_screens[store_id] = shop
	_activate_screen(shop)
	shop.refresh()
	shop.set_highlight_rule(focused_rule)
	hand_bar.visible = true
	state.mark_store_visited(store_id)


func _show_synthesis() -> void:
	if current_screen is QuestSynthesisInterface:
		_return_from_synthesis()
		return
	_run_screen_transition(
		Callable(self, "_show_synthesis_immediate"),
		0.15,
		0.15,
		Color("05090d"),
	)


func _show_synthesis_immediate() -> void:
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
		synthesis_interface.property_inspected.connect(_show_primary_property)
		synthesis_interface.hand_tab_requested.connect(hand_bar.show_tab)
		synthesis_interface.card_staging_changed.connect(_on_card_staging_changed)
		synthesis_interface.details_cleared.connect(_close_detail_popups)
		synthesis_interface.background_pressed.connect(_on_activity_background_pressed)
		screen_host.add_child(synthesis_interface)
		synthesis_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activate_screen(synthesis_interface)
	synthesis_interface.refresh()
	_on_rule_focused(null)
	hand_bar.visible = true


func _return_from_synthesis() -> void:
	var switcher := (
		Callable(self, "_show_shop_immediate").bind(synthesis_return_store_id)
		if not synthesis_return_store_id.is_empty()
		else Callable(self, "_show_map_immediate")
	)
	_run_screen_transition(switcher, 0.15, 0.15, Color("05090d"))


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


func _show_primary_property(property_id: StringName) -> void:
	if detail_popup.visible and detail_popup.primary_property_id == property_id:
		detail_popup.close()
		return
	rule_detail_popup.close()
	detail_popup.show_primary_property(property_id)


func _on_shop_checkout_completed() -> void:
	_close_detail_popups()


func _close_detail_popups() -> void:
	detail_popup.close()
	rule_detail_popup.close()


func _on_activity_background_pressed() -> void:
	if task_dock != null:
		task_dock.close_open_task()


func _on_card_staging_changed(card: CardItemState, staged: bool) -> void:
	hand_bar.set_card_temporarily_hidden(card, staged)


func _on_hand_card_drag_started(card: CardItemState) -> void:
	if current_screen is QuestSynthesisInterface:
		(current_screen as QuestSynthesisInterface).show_drop_targets_for_card(card)


func _on_hand_card_drag_finished(_card: CardItemState, _succeeded: bool) -> void:
	if synthesis_interface != null:
		synthesis_interface.clear_drop_target_highlights()


func play_card_return_animation(
	source: CardHandCard,
	start_position: Vector2,
	end_position: Vector2,
	duration: float,
) -> void:
	_cancel_card_return_animation()
	if source == null or source.card == null or source.definition == null:
		return
	drag_return_source = source
	drag_return_card.setup(source.card, source.definition, false)
	drag_return_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_return_card.position = start_position
	drag_return_card.modulate = Color.WHITE
	drag_return_card.visible = true
	drag_return_tween = drag_return_card.create_tween()
	drag_return_tween.tween_property(
		drag_return_card,
		"position",
		end_position,
		duration,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drag_return_tween.finished.connect(_on_card_return_finished)


func _cancel_card_return_animation() -> void:
	if drag_return_tween != null and drag_return_tween.is_valid():
		drag_return_tween.kill()
	drag_return_tween = null
	if drag_return_source != null and is_instance_valid(drag_return_source):
		drag_return_source._restore_after_drag()
	drag_return_source = null
	if drag_return_card != null:
		drag_return_card.visible = false


func _on_card_return_finished() -> void:
	drag_return_tween = null
	if drag_return_source != null and is_instance_valid(drag_return_source):
		drag_return_source._restore_after_drag()
	drag_return_source = null
	drag_return_card.visible = false


func _on_rule_focused(rule: CardSlotRule) -> void:
	focused_rule = rule
	hand_bar.show_tab_for_rule(rule)
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
		if definition == null:
			continue
		for raw_rule in definition.slot_rules:
			var definition_rule := raw_rule as CardSlotRule
			if definition_rule != null and definition_rule.id == rule.id:
				return definition
	return null


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
	elif result.reason == QuestGameState.RESULT_REQUIRED_TASK_INCOMPLETE:
		next_day_blocked_dialog.title = TranslationServer.translate(&"demo.ui.next_day")
		next_day_blocked_dialog.dialog_text = TranslationServer.translate(
			&"opening.ui.next_day.self_care_required"
		)
		next_day_blocked_dialog.popup_centered(Vector2i(520, 190))


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
	_show_map_immediate()
	if not state.pending_persona_reveal_ids.is_empty():
		_run_pending_persona_reveals()


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
	arc_typewriter_timer = Timer.new()
	arc_typewriter_timer.one_shot = true
	arc_typewriter_timer.timeout.connect(_advance_arc_typewriter_character)
	arc_overlay.add_child(arc_typewriter_timer)
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
	arc_typewriter_timer.stop()
	arc_typewriter_full_text = full_text
	arc_typewriter_index = 0
	arc_result_label.text = full_text
	arc_result_label.visible_characters = 0
	arc_typing = true
	arc_waiting_for_click = false
	_advance_arc_typewriter_character()
	if arc_typing:
		await arc_text_revealed
	arc_waiting_for_click = true
	_start_arc_cursor()
	await arc_text_advanced
	arc_waiting_for_click = false
	_stop_arc_cursor()


func _advance_arc_typewriter_character() -> void:
	if not arc_typing:
		return
	if arc_typewriter_char_seconds <= 0.0:
		_finish_arc_typewriter()
		return
	arc_typewriter_index += 1
	arc_result_label.visible_characters = arc_typewriter_index
	if arc_typewriter_index >= arc_typewriter_full_text.length():
		_finish_arc_typewriter()
	else:
		arc_typewriter_timer.start(arc_typewriter_char_seconds)


func _finish_arc_typewriter() -> void:
	if not arc_typing:
		return
	arc_typewriter_timer.stop()
	arc_result_label.visible_characters = -1
	arc_typing = false
	arc_text_revealed.emit()


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
		_finish_arc_typewriter()
	elif arc_waiting_for_click:
		arc_text_advanced.emit()


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
	if state == null:
		return
	_refresh_hud_state()
	if next_day_button != null:
		next_day_button.text = TranslationServer.translate(&"demo.ui.next_day")
	if language_button != null:
		language_button.text = LocaleManager.switch_button_text()
	if clear_save_button != null:
		clear_save_button.text = TranslationServer.translate(&"demo.ui.clear_save")
		clear_save_button.tooltip_text = TranslationServer.translate(&"demo.ui.clear_save.tooltip")
	if protagonist_button != null:
		protagonist_button.tooltip_text = TranslationServer.translate(&"quest.ui.synthesis.open")
	next_day_dialog.title = TranslationServer.translate(&"demo.ui.next_day")
	next_day_dialog.dialog_text = TranslationServer.translate(&"demo.ui.next_day.question")
	next_day_dialog.ok_button_text = TranslationServer.translate(&"demo.ui.confirm")
	next_day_dialog.cancel_button_text = TranslationServer.translate(&"demo.ui.cancel")
	next_day_blocked_dialog.ok_button_text = TranslationServer.translate(&"demo.ui.confirm")


func _refresh_hud_state() -> void:
	if state == null:
		return
	debug_hud_refresh_count += 1
	if money_label != null:
		money_label.text = TranslationServer.translate(&"demo.ui.money") % state.wallet.money
	if day_label != null:
		day_label.text = TranslationServer.translate(&"demo.ui.night") % state.day


func _on_state_delta(delta: QuestStateDelta) -> void:
	if delta != null and delta.affects_hud():
		_refresh_hud_state()


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
