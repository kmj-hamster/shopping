class_name QuestExpeditionScreen
extends Control

signal expedition_finished
signal demo_completed
signal persona_reveal_requested
signal checkpoint_reached

enum Phase {
	DOORS,
	INTRO,
	CHALLENGE_INTRO,
	APPROACH,
	SLOTS,
	ROUND_RESULT,
	REWARD,
	REST_RESULT,
	WAITING_PERSONA_REVEAL,
	DEMO_COMPLETE,
	DISEASE_END,
}

const INK := Color("e6ece8")
const MUTED := Color("91aaa7")
const ACCENT := Color("d2bd7d")
const TYPEWRITER_CHARACTER_SECONDS := 0.024

var state: QuestGameState
var phase := Phase.DOORS
var room: MallRoomDefinition
var approach_index := -1
var boss_round_index := 0
var challenge_rounds: Array[Dictionary] = []
var staged_entries: Array[Dictionary] = []
var used_card_ids: Dictionary = {}
var reward_collected := false
var last_round_success := false
var current_reward_id: StringName
var pending_completion_result: Dictionary = {}
var narrative_timer: Timer
var narrative_typing := false
var narrative_character_index := 0
var suppress_narrative_animation := false

var background_input: Control
var door_prompt: Label
var door_host: HBoxContainer
var room_panel: Control
var room_title: Label
var room_image_panel: PanelContainer
var room_image_label: Label
var narrative_label: RichTextLabel
var approach_row: HBoxContainer
var approach_buttons: Array[Button] = []
var feedback_label: Label
var slot_row: HBoxContainer
var slots: Array[QuestExpeditionCardSlot] = []
var action_button: Button
var reward_host: CenterContainer
var reward_back: Button
var reward_card: QuestExpeditionRewardCard
var reward_target: QuestExpeditionRewardTarget
var hand_bar: QuestHandBar
var detail_popup: ItemDetailPopup
var demo_panel: CenterContainer


func setup(game_state: QuestGameState) -> void:
	state = game_state
	if is_node_ready():
		hand_bar.setup(state)
		show_checkpoint()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	z_index = 500
	_build_interface()
	narrative_timer = Timer.new()
	narrative_timer.one_shot = true
	narrative_timer.timeout.connect(_advance_narrative_typewriter)
	add_child(narrative_timer)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	if state != null:
		show_checkpoint()


func show_checkpoint() -> void:
	_clear_room_draft()
	if state != null and not state.expedition.disease_game_over_id.is_empty():
		_show_disease_end()
		return
	phase = Phase.DOORS
	room = null
	door_prompt.visible = true
	door_host.visible = true
	room_panel.visible = false
	demo_panel.visible = false
	_rebuild_doors()
	hand_bar.refresh()
	detail_popup.close()


func definition_for_card(card: CardItemState) -> CardItemDefinition:
	return state.definition_for_card(card) if state != null else null


func can_stage_card(slot_index: int, card: CardItemState) -> bool:
	if phase != Phase.SLOTS or room == null or card == null:
		return false
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var persona_id := PersonaMaskCatalog.persona_for_card(card)
	if persona_id.is_empty() and used_card_ids.has(card.instance_id):
		return false
	for index in staged_entries.size():
		if index != slot_index and staged_entries[index].get("card") == card:
			return false
	return state.expedition_room_accepts_card(room.id, card, persona_id)


func stage_card(slot_index: int, card: CardItemState) -> void:
	if not can_stage_card(slot_index, card):
		return
	_unhide_entry(staged_entries[slot_index])
	var persona_id := PersonaMaskCatalog.persona_for_card(card)
	staged_entries[slot_index] = {"card": card, "persona_id": persona_id}
	hand_bar.set_card_temporarily_hidden(card, true)
	_refresh_slots()
	_refresh_feedback()


func unstage_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= staged_entries.size():
		return
	_unhide_entry(staged_entries[slot_index])
	staged_entries[slot_index] = {}
	_refresh_slots()
	_refresh_feedback()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.name = "ExpeditionBlackBackground"
	background.color = Color("02070b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background_input = Control.new()
	background_input.name = "ExpeditionBackgroundInput"
	background_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_input.mouse_filter = Control.MOUSE_FILTER_STOP
	background_input.gui_input.connect(_on_background_input)
	add_child(background_input)

	door_prompt = Label.new()
	door_prompt.anchor_left = 0.16
	door_prompt.anchor_top = 0.045
	door_prompt.anchor_right = 0.84
	door_prompt.anchor_bottom = 0.12
	door_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	door_prompt.add_theme_font_size_override("font_size", 21)
	door_prompt.add_theme_color_override("font_color", INK)
	door_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(door_prompt)
	door_host = HBoxContainer.new()
	door_host.name = "ExpeditionDoorHost"
	door_host.anchor_left = 0.18
	door_host.anchor_top = 0.13
	door_host.anchor_right = 0.82
	door_host.anchor_bottom = 0.79
	door_host.alignment = BoxContainer.ALIGNMENT_CENTER
	door_host.add_theme_constant_override("separation", 145)
	add_child(door_host)

	_build_room_panel()
	hand_bar = QuestHandBar.new()
	hand_bar.name = "ExpeditionHandBar"
	hand_bar.anchor_left = 0.12
	hand_bar.anchor_top = 0.805
	hand_bar.anchor_right = 0.88
	hand_bar.anchor_bottom = 1.0
	hand_bar.z_index = 20
	hand_bar.setup(state)
	hand_bar.item_inspected.connect(_show_item)
	hand_bar.card_drag_started.connect(_on_hand_drag_started)
	hand_bar.card_drag_finished.connect(_on_hand_drag_finished)
	add_child(hand_bar)
	reward_target = QuestExpeditionRewardTarget.new()
	reward_target.name = "RewardCollectTarget"
	reward_target.anchor_left = 0.10
	reward_target.anchor_top = 0.78
	reward_target.anchor_right = 0.90
	reward_target.anchor_bottom = 1.0
	reward_target.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_target.z_index = 30
	reward_target.reward_collected.connect(_on_reward_collected)
	reward_target.visible = false
	add_child(reward_target)
	detail_popup = ItemDetailPopup.new()
	detail_popup.z_index = 100
	add_child(detail_popup)
	_build_demo_panel()
	_refresh_localized_text()


func _build_room_panel() -> void:
	room_panel = Control.new()
	room_panel.name = "ExpeditionRoomPanel"
	room_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_panel.visible = false
	add_child(room_panel)
	room_title = Label.new()
	room_title.anchor_left = 0.12
	room_title.anchor_top = 0.035
	room_title.anchor_right = 0.88
	room_title.anchor_bottom = 0.12
	room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_title.add_theme_font_size_override("font_size", 30)
	room_title.add_theme_color_override("font_color", INK)
	room_panel.add_child(room_title)
	room_image_panel = PanelContainer.new()
	room_image_panel.anchor_left = 0.075
	room_image_panel.anchor_top = 0.18
	room_image_panel.anchor_right = 0.47
	room_image_panel.anchor_bottom = 0.69
	room_image_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("0b171d"), Color("54706f"))
	)
	room_panel.add_child(room_image_panel)
	room_image_label = Label.new()
	room_image_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_image_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_image_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_image_label.add_theme_font_size_override("font_size", 22)
	room_image_label.add_theme_color_override("font_color", MUTED)
	room_image_panel.add_child(room_image_label)

	var right_column := VBoxContainer.new()
	right_column.anchor_left = 0.52
	right_column.anchor_top = 0.17
	right_column.anchor_right = 0.94
	right_column.anchor_bottom = 0.76
	right_column.add_theme_constant_override("separation", 12)
	right_column.mouse_filter = Control.MOUSE_FILTER_PASS
	room_panel.add_child(right_column)
	narrative_label = RichTextLabel.new()
	narrative_label.custom_minimum_size = Vector2(0, 180)
	narrative_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narrative_label.fit_content = false
	narrative_label.scroll_active = false
	narrative_label.bbcode_enabled = true
	narrative_label.add_theme_font_size_override("normal_font_size", 20)
	narrative_label.add_theme_color_override("default_color", INK)
	narrative_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_column.add_child(narrative_label)
	approach_row = HBoxContainer.new()
	approach_row.alignment = BoxContainer.ALIGNMENT_CENTER
	approach_row.add_theme_constant_override("separation", 12)
	right_column.add_child(approach_row)
	for index in 2:
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 56)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_choose_approach.bind(index))
		approach_buttons.append(button)
		approach_row.add_child(button)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(0, 34)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 18)
	feedback_label.add_theme_color_override("font_color", ACCENT)
	right_column.add_child(feedback_label)
	slot_row = HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 16)
	right_column.add_child(slot_row)
	for index in 3:
		var slot := QuestExpeditionCardSlot.new()
		slot.name = "ExpeditionSlot%d" % (index + 1)
		slot.setup(self, index)
		slot.item_inspected.connect(_show_item)
		slots.append(slot)
		slot_row.add_child(slot)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(190, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.pressed.connect(_on_action_pressed)
	right_column.add_child(action_button)
	reward_host = CenterContainer.new()
	reward_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_host.z_index = 12
	room_panel.add_child(reward_host)
	reward_back = Button.new()
	reward_back.custom_minimum_size = CardHandCard.CARD_SIZE * 1.45
	reward_back.text = "◇\n◇\n◇"
	reward_back.add_theme_font_size_override("font_size", 22)
	reward_back.add_theme_stylebox_override(
		"normal", _panel_style(Color("09141a"), Color("adbdaf"))
	)
	reward_back.pressed.connect(_flip_reward)
	reward_host.add_child(reward_back)
	reward_card = QuestExpeditionRewardCard.new()
	reward_card.scale = Vector2(1.45, 1.45)
	reward_card.drag_finished.connect(_on_reward_drag_finished)
	reward_host.add_child(reward_card)
	reward_host.visible = false


func _build_demo_panel() -> void:
	demo_panel = CenterContainer.new()
	demo_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demo_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	demo_panel.visible = false
	demo_panel.z_index = 60
	add_child(demo_panel)
	var label := Label.new()
	label.name = "DemoCompleteLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", ACCENT)
	demo_panel.add_child(label)


func _rebuild_doors() -> void:
	for child in door_host.get_children():
		child.queue_free()
	if state == null:
		return
	for room_id in state.expedition.current_door_ids:
		var definition := QuestArcCatalog.mall_room_by_id(room_id)
		if definition == null:
			continue
		var door := QuestExpeditionDoor.new()
		door.setup(state, definition)
		door.chosen.connect(_enter_room)
		door_host.add_child(door)


func _enter_room(room_id: StringName) -> void:
	room = QuestArcCatalog.mall_room_by_id(room_id)
	if room == null:
		return
	_clear_room_draft()
	phase = Phase.INTRO
	door_prompt.visible = false
	door_host.visible = false
	room_panel.visible = true
	room_title.text = TranslationServer.translate(room.display_name_key)
	_set_room_image(&"intro")
	_set_narrative(room.intro_text_keys)
	approach_row.visible = false
	feedback_label.visible = false
	slot_row.visible = false
	action_button.visible = true
	action_button.disabled = false
	action_button.text = TranslationServer.translate(&"expedition.ui.continue")
	reward_host.visible = false
	reward_target.visible = false


func _on_action_pressed() -> void:
	if narrative_typing:
		_finish_narrative_typewriter()
		return
	match phase:
		Phase.INTRO:
			_advance_from_intro()
		Phase.CHALLENGE_INTRO:
			_show_approaches()
		Phase.SLOTS:
			_submit_slots()
		Phase.ROUND_RESULT:
			if _has_next_boss_round():
				_start_next_boss_round()
			else:
				_show_reward(
					&"expedition_salvage" if last_round_success else &"expedition_wound"
				)
		Phase.REST_RESULT:
			_leave_room()
		Phase.REWARD:
			if reward_collected:
				_leave_room()


func _advance_from_intro() -> void:
	match room.category:
		MallRoomDefinition.Category.CHALLENGE, MallRoomDefinition.Category.BOSS:
			_show_challenge_intro()
		MallRoomDefinition.Category.REST:
			_show_rest_slots()
		MallRoomDefinition.Category.WORK:
			_show_reward(&"expedition_wage")


func _show_challenge_intro() -> void:
	phase = Phase.CHALLENGE_INTRO
	_set_room_image(&"challenge")
	_set_narrative(room.challenge_text_keys)
	approach_row.visible = false
	slot_row.visible = false
	feedback_label.visible = false
	action_button.visible = true
	action_button.disabled = false
	action_button.text = TranslationServer.translate(&"expedition.ui.continue")


func _show_approaches() -> void:
	phase = Phase.APPROACH
	_set_room_image(&"challenge")
	narrative_label.visible_characters = -1
	narrative_typing = false
	approach_row.visible = true
	for index in approach_buttons.size():
		approach_buttons[index].text = TranslationServer.translate(
			room.approach_title_keys[index]
		)
	action_button.visible = false
	slot_row.visible = false
	feedback_label.visible = false


func _choose_approach(index: int) -> void:
	if phase != Phase.APPROACH:
		return
	approach_index = index
	phase = Phase.SLOTS
	approach_row.visible = false
	var narrative_lines: PackedStringArray = [
		TranslationServer.translate(room.approach_text_keys[index])
	]
	if not room.post_choice_text_key.is_empty():
		narrative_lines.append(TranslationServer.translate(room.post_choice_text_key))
	_set_narrative_text("\n\n".join(narrative_lines))
	_set_room_image(&"response")
	_prepare_slots(room.slot_count)
	feedback_label.visible = true
	action_button.visible = true
	action_button.disabled = false
	action_button.text = TranslationServer.translate(&"expedition.ui.submit")
	_refresh_feedback()


func _show_rest_slots() -> void:
	phase = Phase.SLOTS
	_prepare_slots(room.slot_count)
	feedback_label.visible = false
	action_button.visible = true
	action_button.text = TranslationServer.translate(
		&"expedition.ui.sell" if room.rest_mode == MallRoomDefinition.RestMode.SALVAGE else &"expedition.ui.confirm"
	)
	action_button.disabled = room.rest_mode == MallRoomDefinition.RestMode.PERSONA_GROWTH


func _prepare_slots(count: int) -> void:
	staged_entries.clear()
	for index in slots.size():
		staged_entries.append({})
		slots[index].visible = index < count
		slots[index].setup(self, index)
	slot_row.visible = true


func _submit_slots() -> void:
	if room.category in [MallRoomDefinition.Category.CHALLENGE, MallRoomDefinition.Category.BOSS]:
		_submit_challenge_round()
	else:
		_preview_rest_result()


func _submit_challenge_round() -> void:
	var round := _current_round_dictionary()
	var evaluation := state.evaluate_expedition_challenge_round(
		room.id,
		round.card_instance_ids,
		round.persona_ids,
		approach_index,
		boss_round_index,
	)
	if not bool(evaluation.ok):
		return
	challenge_rounds.append(round)
	last_round_success = bool(evaluation.success)
	for card_id in round.card_instance_ids:
		used_card_ids[card_id] = true
	_release_current_personas_only()
	phase = Phase.ROUND_RESULT
	_set_room_image(&"result")
	_set_narrative_text(TranslationServer.translate(
		room.success_text_key if bool(evaluation.success) else room.failure_text_key
	))
	slot_row.visible = false
	feedback_label.visible = false
	action_button.visible = true
	action_button.text = TranslationServer.translate(
		&"expedition.ui.next_round"
		if _has_next_boss_round()
		else &"expedition.ui.continue"
	)
	reward_host.visible = false
	reward_target.visible = false


func _has_next_boss_round() -> bool:
	return (
		room != null
		and room.category == MallRoomDefinition.Category.BOSS
		and last_round_success
		and boss_round_index + 1 < room.boss_round_count
	)


func _start_next_boss_round() -> void:
	boss_round_index += 1
	approach_index = -1
	_clear_slot_entries(false)
	_show_approaches()
	room_title.text = "%s  %d/%d" % [
		TranslationServer.translate(room.display_name_key),
		boss_round_index + 1,
		room.boss_round_count,
	]


func _preview_rest_result() -> void:
	if room.rest_mode == MallRoomDefinition.RestMode.PERSONA_GROWTH and _current_persona_ids().size() != 1:
		return
	phase = Phase.REST_RESULT
	slot_row.visible = false
	feedback_label.visible = false
	_set_room_image(&"result")
	_set_narrative_text(TranslationServer.translate(
		&"expedition.room.salvage.result"
		if room.rest_mode == MallRoomDefinition.RestMode.SALVAGE
		else &"expedition.room.rest.result"
	))
	action_button.visible = true
	action_button.text = TranslationServer.translate(&"expedition.ui.leave")


func _show_reward(reward_id: StringName) -> void:
	phase = Phase.REWARD
	current_reward_id = reward_id
	reward_collected = false
	reward_host.visible = true
	reward_back.visible = true
	reward_card.visible = false
	reward_target.visible = false
	action_button.visible = false
	var definition := QuestArcCatalog.item_by_id(reward_id)
	var preview_state := CardItemState.new(-900, reward_id, state.day, &"expedition_preview")
	reward_card.setup(preview_state, definition, reward_id != &"expedition_wage")


func _flip_reward() -> void:
	if phase != Phase.REWARD:
		return
	reward_back.visible = false
	reward_card.visible = true
	if reward_card.definition.id == &"expedition_wage":
		reward_collected = true
		reward_card.drag_enabled = false
		action_button.visible = true
		action_button.text = TranslationServer.translate(&"expedition.ui.leave")
	else:
		reward_card.drag_enabled = true
		reward_target.visible = true


func _on_reward_collected() -> void:
	if phase != Phase.REWARD:
		return
	reward_collected = true
	reward_target.visible = false
	reward_card.visible = false
	action_button.visible = true
	action_button.text = TranslationServer.translate(&"expedition.ui.leave")


func _on_reward_drag_finished(_card: CardItemState, succeeded: bool) -> void:
	if not succeeded:
		reward_card.visible = true


func _leave_room() -> void:
	var result: Dictionary
	if room.category in [MallRoomDefinition.Category.CHALLENGE, MallRoomDefinition.Category.BOSS]:
		result = state.complete_expedition_room(room.id, [], [], challenge_rounds)
	else:
		result = state.complete_expedition_room(
			room.id, _current_card_ids(), _current_persona_ids()
		)
	if not bool(result.get("ok", false)):
		return
	_clear_room_draft()
	if not (result.get("new_persona_ids", []) as Array).is_empty():
		pending_completion_result = result
		phase = Phase.WAITING_PERSONA_REVEAL
		action_button.visible = false
		persona_reveal_requested.emit()
		return
	_finalize_committed_room(result)


func on_persona_reveals_completed() -> void:
	if phase != Phase.WAITING_PERSONA_REVEAL or pending_completion_result.is_empty():
		return
	var result := pending_completion_result
	pending_completion_result = {}
	_finalize_committed_room(result)


func _finalize_committed_room(result: Dictionary) -> void:
	if bool(result.demo_complete):
		_show_demo_complete()
		demo_completed.emit()
	elif bool(result.night_finished):
		expedition_finished.emit()
	else:
		show_checkpoint()
		checkpoint_reached.emit()


func _show_demo_complete() -> void:
	phase = Phase.DEMO_COMPLETE
	door_prompt.visible = false
	door_host.visible = false
	room_panel.visible = false
	hand_bar.visible = false
	detail_popup.close()
	demo_panel.visible = true
	var label := demo_panel.get_node("DemoCompleteLabel") as Label
	label.text = TranslationServer.translate(&"expedition.ui.demo_complete")


func _show_disease_end() -> void:
	phase = Phase.DISEASE_END
	door_prompt.visible = false
	door_host.visible = false
	room_panel.visible = false
	hand_bar.visible = false
	detail_popup.close()
	demo_panel.visible = true
	var label := demo_panel.get_node("DemoCompleteLabel") as Label
	label.text = TranslationServer.translate(
		StringName(
			"expedition.ui.disease_end.%s" % String(state.expedition.disease_game_over_id)
		)
	)


func _refresh_feedback() -> void:
	if room == null or phase != Phase.SLOTS:
		return
	if room.category not in [MallRoomDefinition.Category.CHALLENGE, MallRoomDefinition.Category.BOSS]:
		action_button.disabled = (
			room.rest_mode == MallRoomDefinition.RestMode.PERSONA_GROWTH
			and _current_persona_ids().size() != 1
		)
		return
	var round := _current_round_dictionary()
	var evaluation := state.evaluate_expedition_challenge_round(
		room.id,
		round.card_instance_ids,
		round.persona_ids,
		approach_index,
		boss_round_index,
	)
	if not bool(evaluation.ok):
		feedback_label.text = TranslationServer.translate(&"expedition.feedback.hopeless")
		return
	feedback_label.text = TranslationServer.translate(
		StringName("expedition.feedback.%s" % evaluation.feedback_tier)
	)


func _current_round_dictionary() -> Dictionary:
	return {
		"approach_index": approach_index,
		"card_instance_ids": _current_card_ids(),
		"persona_ids": _current_persona_ids(),
	}


func _current_card_ids() -> Array[int]:
	var result: Array[int] = []
	for entry in staged_entries:
		var card := entry.get("card") as CardItemState
		if card != null and StringName(entry.get("persona_id", "")).is_empty():
			result.append(card.instance_id)
	return result


func _current_persona_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in staged_entries:
		var persona_id := StringName(entry.get("persona_id", ""))
		if not persona_id.is_empty():
			result.append(persona_id)
	return result


func _refresh_slots() -> void:
	for index in slots.size():
		var entry := staged_entries[index] if index < staged_entries.size() else {}
		slots[index].setup(
			self,
			index,
			entry.get("card") as CardItemState,
			StringName(entry.get("persona_id", "")),
		)


func _clear_room_draft() -> void:
	_clear_slot_entries(true)
	used_card_ids.clear()
	challenge_rounds.clear()
	boss_round_index = 0
	approach_index = -1
	reward_collected = false
	last_round_success = false
	current_reward_id = &""
	pending_completion_result = {}
	if narrative_timer != null:
		narrative_timer.stop()
	narrative_typing = false
	narrative_character_index = 0
	if hand_bar != null:
		hand_bar.clear_temporarily_hidden_cards()


func _clear_slot_entries(unhide_used_items: bool) -> void:
	for entry in staged_entries:
		var card := entry.get("card") as CardItemState
		if card == null:
			continue
		var persona_id := StringName(entry.get("persona_id", ""))
		if not persona_id.is_empty() or unhide_used_items or not used_card_ids.has(card.instance_id):
			hand_bar.set_card_temporarily_hidden(card, false)
	staged_entries.clear()
	for index in slots.size():
		staged_entries.append({})
		slots[index].setup(self, index)


func _release_current_personas_only() -> void:
	for entry in staged_entries:
		var persona_id := StringName(entry.get("persona_id", ""))
		if persona_id.is_empty():
			continue
		var card := entry.get("card") as CardItemState
		if card != null:
			hand_bar.set_card_temporarily_hidden(card, false)


func _unhide_entry(entry: Dictionary) -> void:
	var card := entry.get("card") as CardItemState
	if card != null and not used_card_ids.has(card.instance_id):
		hand_bar.set_card_temporarily_hidden(card, false)


func _on_hand_drag_started(card: CardItemState) -> void:
	for index in slots.size():
		slots[index].set_drop_highlight(slots[index].visible and can_stage_card(index, card))


func _on_hand_drag_finished(_card: CardItemState, _succeeded: bool) -> void:
	for slot in slots:
		slot.set_drop_highlight(false)


func _show_item(definition: CardItemDefinition) -> void:
	detail_popup.show_item(definition)


func _on_background_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		detail_popup.close()


func _set_narrative(keys: Array[StringName]) -> void:
	var lines: PackedStringArray = []
	for key in keys:
		lines.append(TranslationServer.translate(key))
	_set_narrative_text("\n".join(lines))


func _set_narrative_text(full_text: String) -> void:
	if narrative_timer != null:
		narrative_timer.stop()
	narrative_label.text = full_text
	narrative_character_index = 0
	if suppress_narrative_animation or full_text.is_empty():
		narrative_label.visible_characters = -1
		narrative_typing = false
		return
	narrative_label.visible_characters = 0
	narrative_typing = true
	_advance_narrative_typewriter()


func _advance_narrative_typewriter() -> void:
	if not narrative_typing:
		return
	narrative_character_index += 1
	narrative_label.visible_characters = narrative_character_index
	if narrative_character_index >= narrative_label.get_total_character_count():
		_finish_narrative_typewriter()
	elif narrative_timer != null:
		narrative_timer.start(TYPEWRITER_CHARACTER_SECONDS)


func _finish_narrative_typewriter() -> void:
	if narrative_timer != null:
		narrative_timer.stop()
	narrative_label.visible_characters = -1
	narrative_character_index = narrative_label.get_total_character_count()
	narrative_typing = false


func _set_room_image(stage_id: StringName) -> void:
	room_image_label.text = TranslationServer.translate(
		StringName("expedition.ui.placeholder.%s" % stage_id)
	)


func _refresh_localized_text() -> void:
	door_prompt.text = TranslationServer.translate(&"expedition.ui.door_prompt")
	if phase == Phase.DOORS:
		_rebuild_doors()
	elif phase == Phase.DEMO_COMPLETE:
		(demo_panel.get_node("DemoCompleteLabel") as Label).text = TranslationServer.translate(
			&"expedition.ui.demo_complete"
		)
	elif phase == Phase.DISEASE_END:
		_show_disease_end()
	elif room != null and room_panel.visible:
		_refresh_room_phase_text()


func _on_locale_changed(_locale: String) -> void:
	suppress_narrative_animation = true
	_refresh_localized_text()
	suppress_narrative_animation = false


func _refresh_room_phase_text() -> void:
	room_title.text = TranslationServer.translate(room.display_name_key)
	if room.category == MallRoomDefinition.Category.BOSS and boss_round_index > 0:
		room_title.text = "%s  %d/%d" % [
			TranslationServer.translate(room.display_name_key),
			boss_round_index + 1,
			room.boss_round_count,
		]
	match phase:
		Phase.INTRO:
			_set_room_image(&"intro")
			_set_narrative(room.intro_text_keys)
			action_button.text = TranslationServer.translate(&"expedition.ui.continue")
		Phase.CHALLENGE_INTRO:
			_set_room_image(&"challenge")
			_set_narrative(room.challenge_text_keys)
			action_button.text = TranslationServer.translate(&"expedition.ui.continue")
		Phase.APPROACH:
			_set_room_image(&"challenge")
			_set_narrative(room.challenge_text_keys)
			for index in approach_buttons.size():
				approach_buttons[index].text = TranslationServer.translate(
					room.approach_title_keys[index]
				)
		Phase.SLOTS:
			if room.category in [
				MallRoomDefinition.Category.CHALLENGE,
				MallRoomDefinition.Category.BOSS,
			]:
				_set_room_image(&"response")
				var narrative_keys: Array[StringName] = [room.approach_text_keys[approach_index]]
				if not room.post_choice_text_key.is_empty():
					narrative_keys.append(room.post_choice_text_key)
				var lines: PackedStringArray = []
				for key in narrative_keys:
					lines.append(TranslationServer.translate(key))
				_set_narrative_text("\n\n".join(lines))
				action_button.text = TranslationServer.translate(&"expedition.ui.submit")
				_refresh_feedback()
			else:
				_set_room_image(&"intro")
				_set_narrative(room.intro_text_keys)
				action_button.text = TranslationServer.translate(
					&"expedition.ui.sell"
					if room.rest_mode == MallRoomDefinition.RestMode.SALVAGE
					else &"expedition.ui.confirm"
				)
		Phase.ROUND_RESULT:
			_set_room_image(&"result")
			_set_narrative_text(TranslationServer.translate(
				room.success_text_key if last_round_success else room.failure_text_key
			))
			action_button.text = TranslationServer.translate(
				&"expedition.ui.next_round"
				if _has_next_boss_round()
				else &"expedition.ui.continue"
			)
		Phase.REST_RESULT:
			_set_room_image(&"result")
			_set_narrative_text(TranslationServer.translate(
				&"expedition.room.salvage.result"
				if room.rest_mode == MallRoomDefinition.RestMode.SALVAGE
				else &"expedition.room.rest.result"
			))
			action_button.text = TranslationServer.translate(&"expedition.ui.leave")
		Phase.REWARD:
			if room.category != MallRoomDefinition.Category.WORK:
				_set_room_image(&"result")
				_set_narrative_text(TranslationServer.translate(
					room.success_text_key if last_round_success else room.failure_text_key
				))
			else:
				_set_room_image(&"intro")
				_set_narrative(room.intro_text_keys)
			if not current_reward_id.is_empty():
				var definition := QuestArcCatalog.item_by_id(current_reward_id)
				var preview_state := CardItemState.new(
					-900, current_reward_id, state.day, &"expedition_preview"
				)
				reward_card.setup(
					preview_state,
					definition,
					current_reward_id != &"expedition_wage",
				)
			if reward_collected:
				action_button.text = TranslationServer.translate(&"expedition.ui.leave")


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
