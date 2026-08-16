class_name QuestTaskOfferOverlay
extends ColorRect

signal offers_completed

const CARD_SIZE := Vector2(286, 396)
const CARD_GAP := 28

var state: QuestGameState
var heading_label: Label
var cards_row: HBoxContainer
var feedback_label: Label
var selection_locked := false


func setup(game_state: QuestGameState) -> void:
	state = game_state
	if is_node_ready() and visible:
		_refresh_offer()


func _ready() -> void:
	color = Color("010204")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 540
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)
	heading_label = Label.new()
	heading_label.custom_minimum_size = Vector2(920, 44)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading_label.add_theme_font_size_override("font_size", 25)
	heading_label.add_theme_color_override("font_color", Color("d9d3bd"))
	column.add_child(heading_label)
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(cards_row)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(920, 36)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 20)
	feedback_label.add_theme_color_override("font_color", Color("e1c870"))
	column.add_child(feedback_label)
	LocaleManager.locale_changed.connect(_on_locale_changed)


func show_current_offer() -> void:
	if state == null or not state.has_pending_task_offers():
		visible = false
		return
	selection_locked = false
	visible = true
	_refresh_offer()


func _refresh_offer() -> void:
	if cards_row == null or state == null:
		return
	for child in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	feedback_label.text = ""
	var offer := state.current_task_offer()
	var kind := StringName(offer.get("kind", ""))
	heading_label.text = TranslationServer.translate(
		&"quest.ui.offer.self_care.heading"
		if kind == QuestGameState.OFFER_KIND_SELF_CARE
		else &"quest.ui.offer.daily.heading"
	)
	for raw_candidate_id in offer.get("candidate_ids", []):
		var candidate_id := StringName(raw_candidate_id)
		cards_row.add_child(_create_offer_card(candidate_id, kind))


func _create_offer_card(candidate_id: StringName, kind: StringName) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("0b151a", 0.97), Color("738481", 0.62))
	)
	button.add_theme_stylebox_override(
		"hover", UiPalette.panel_style(Color("13232a", 0.99), Color("8aaab4", 0.94))
	)
	button.add_theme_stylebox_override(
		"pressed", UiPalette.panel_style(Color("182a31", 1.0), Color("a5bcc0", 1.0))
	)
	button.add_theme_stylebox_override(
		"focus", UiPalette.panel_style(Color("0b151a", 0.97), Color("738481", 0.62))
	)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var copy := _candidate_copy(candidate_id, kind)
	var title := _offer_label(copy.title, 23, Color("e3dcc3"), 62)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _offer_label(copy.subtitle, 14, Color("829b9b"), 42)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var divider := HSeparator.new()
	divider.modulate = Color("738481", 0.42)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)
	var body := _offer_label(copy.body, 16, Color("c5cbc3"), 190)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	column.add_child(body)
	var footer := _offer_label(copy.footer, 16, Color("dfc878"), 32)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)
	button.pressed.connect(_select_candidate.bind(candidate_id))
	return button


func _candidate_copy(candidate_id: StringName, kind: StringName) -> Dictionary:
	if candidate_id == QuestGameState.DEEP_NIGHT_JOB_ID:
		return {
			"title": TranslationServer.translate(&"quest.ui.offer.deep_job.name"),
			"subtitle": TranslationServer.translate(&"quest.ui.offer.deep_job.subtitle"),
			"body": TranslationServer.translate(&"quest.ui.offer.deep_job.body"),
			"footer": TranslationServer.translate(&"quest.ui.offer.deep_job.reward"),
		}
	var definition := QuestArcCatalog.task_by_id(candidate_id)
	if definition == null:
		return {"title": "", "subtitle": "", "body": "", "footer": ""}
	return {
		"title": TranslationServer.translate(definition.offer_title_key),
		"subtitle": TranslationServer.translate(definition.offer_subtitle_key),
		"body": TranslationServer.translate(definition.offer_body_key),
		"footer": (
			TranslationServer.translate(&"quest.ui.offer.reward") % definition.reward_money()
			if kind == QuestGameState.OFFER_KIND_DAILY
			else ""
		),
	}


func _offer_label(text: String, font_size: int, color_value: Color, height: float) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, height)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color_value)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _select_candidate(candidate_id: StringName) -> void:
	if selection_locked or state == null:
		return
	selection_locked = true
	for child in cards_row.get_children():
		(child as BaseButton).disabled = true
	var result := state.choose_current_task_offer(candidate_id)
	if not result.ok:
		selection_locked = false
		_refresh_offer()
		return
	if int(result.money_reward) > 0:
		feedback_label.text = "+%d" % int(result.money_reward)
		await get_tree().create_timer(0.55).timeout
	if state.has_pending_task_offers():
		selection_locked = false
		_refresh_offer()
		return
	visible = false
	selection_locked = false
	offers_completed.emit()


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_offer()
