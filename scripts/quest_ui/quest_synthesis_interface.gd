class_name QuestSynthesisInterface
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)
signal card_staging_changed(card: CardItemState, staged: bool)

var state: QuestGameState
var material_row: HBoxContainer
var candidate_button: Button
var candidate_hint_panel: PanelContainer
var candidate_hint_label: Label
var output_holder: CenterContainer
var action_button: Button
var empty_candidate_label: Label
var candidate_selected := false
var material_slots: Array[QuestSynthesisMaterialSlot] = []
var output_animation_seconds := 0.32
var refresh_queued := false


func setup(game_state: QuestGameState) -> void:
	state = game_state
	if state != null and not state.state_changed.is_connected(_queue_refresh):
		state.state_changed.connect(_queue_refresh)
	if is_node_ready():
		_prepare_recipe()
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	_prepare_recipe()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func refresh() -> void:
	if state == null or material_row == null:
		return
	_rebuild_materials()
	var has_materials := not state.synthesis_assignments.is_empty()
	var evaluation := state.synthesis_evaluation()
	empty_candidate_label.visible = not has_materials
	candidate_button.visible = has_materials
	candidate_button.text = (
		QuestArcCatalog.item_by_id(StringName(evaluation.output_id)).localized_name()
		if evaluation.is_complete
		else "◇"
	)
	candidate_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.inspect")
	candidate_hint_panel.visible = has_materials and candidate_selected
	if candidate_hint_panel.visible:
		var recipe := _recipe()
		candidate_hint_label.text = (
			TranslationServer.translate(recipe.preview_key_for_output(&"scissors"))
			if recipe != null
			else ""
		)
	_rebuild_output(evaluation)
	action_button.text = TranslationServer.translate(&"quest.ui.synthesis.action")
	action_button.visible = evaluation.is_complete
	action_button.disabled = not evaluation.is_complete


func can_stage_card(card: CardItemState) -> bool:
	if state == null or card == null or card not in state.inventory:
		return false
	if card.location != CardItemState.Location.HAND:
		return false
	return _available_rule_for_card(card) != null


func stage_card(card: CardItemState) -> bool:
	var rule := _available_rule_for_card(card)
	if rule == null:
		return false
	var result := state.assign_synthesis_card(rule.id, card)
	return bool(result.ok)


func remove_material(card: CardItemState) -> void:
	if state != null:
		state.return_card_to_hand(card)


func cancel_pending_inputs() -> void:
	candidate_selected = false
	if state != null:
		state.clear_synthesis_assignments()


func _prepare_recipe() -> void:
	if state == null:
		return
	if state.synthesis_recipe_id != &"recipe_scissors":
		state.select_synthesis_recipe(&"recipe_scissors")


func _recipe() -> SynthesisRecipeDefinition:
	return QuestArcCatalog.recipe_by_id(&"recipe_scissors")


func _available_rule_for_card(card: CardItemState) -> CardSlotRule:
	var recipe := _recipe()
	var definition := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	if recipe == null or definition == null:
		return null
	for raw_rule in recipe.slot_rules:
		var rule := raw_rule as CardSlotRule
		if state.synthesis_assignments.has(rule.id):
			continue
		if CardRuleEvaluator.evaluate(rule, definition).can_place:
			return rule
	return null


func _assigned_cards() -> Array[CardItemState]:
	var result: Array[CardItemState] = []
	var recipe := _recipe()
	if recipe == null:
		return result
	for raw_rule in recipe.slot_rules:
		var rule := raw_rule as CardSlotRule
		var card := state.card_by_instance_id(int(state.synthesis_assignments.get(rule.id, 0)))
		if card != null:
			result.append(card)
	return result


func _rebuild_materials() -> void:
	for child in material_row.get_children():
		child.free()
	material_slots.clear()
	var cards := _assigned_cards()
	for index in 2:
		var slot := QuestSynthesisMaterialSlot.new()
		slot.name = "MaterialSlot%d" % (index + 1)
		slot.setup(self, cards[index] if index < cards.size() else null)
		slot.item_inspected.connect(item_inspected.emit)
		material_row.add_child(slot)
		material_slots.append(slot)


func _rebuild_output(evaluation: Dictionary) -> void:
	for child in output_holder.get_children():
		child.free()
	if not evaluation.is_complete:
		var placeholder := Label.new()
		placeholder.text = "◇"
		placeholder.add_theme_font_size_override("font_size", 44)
		placeholder.add_theme_color_override("font_color", Color("556562"))
		output_holder.add_child(placeholder)
		return
	var definition := QuestArcCatalog.item_by_id(StringName(evaluation.output_id))
	var preview := CardHandCard.new()
	preview.name = "SynthesisOutputPreview"
	preview.setup(null, definition, false)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output_holder.add_child(preview)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("031014")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var inner_glow := ColorRect.new()
	inner_glow.color = Color("123936", 0.34)
	inner_glow.anchor_left = 0.03
	inner_glow.anchor_top = 0.05
	inner_glow.anchor_right = 0.97
	inner_glow.anchor_bottom = 0.95
	inner_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner_glow)

	var title := Label.new()
	title.name = "SynthesisTitle"
	title.anchor_left = 0.04
	title.anchor_top = 0.04
	title.anchor_right = 0.64
	title.anchor_bottom = 0.14
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("ddc985"))
	title.text = TranslationServer.translate(&"quest.ui.synthesis.title")
	add_child(title)

	var close_button := Button.new()
	close_button.name = "LeaveSynthesisButton"
	close_button.anchor_left = 0.91
	close_button.anchor_top = 0.035
	close_button.anchor_right = 0.97
	close_button.anchor_bottom = 0.12
	close_button.text = "×"
	close_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.leave")
	close_button.pressed.connect(leave_requested.emit)
	add_child(close_button)

	var material_panel := PanelContainer.new()
	material_panel.anchor_left = 0.055
	material_panel.anchor_top = 0.18
	material_panel.anchor_right = 0.60
	material_panel.anchor_bottom = 0.87
	material_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("07191d", 0.82), Color("58766f", 0.68))
	)
	add_child(material_panel)
	var material_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		material_margin.add_theme_constant_override("margin_%s" % side, 18)
	material_panel.add_child(material_margin)
	var material_column := VBoxContainer.new()
	material_column.alignment = BoxContainer.ALIGNMENT_CENTER
	material_column.add_theme_constant_override("separation", 18)
	material_margin.add_child(material_column)
	var material_heading := Label.new()
	material_heading.name = "MaterialHeading"
	material_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	material_heading.add_theme_font_size_override("font_size", 14)
	material_heading.add_theme_color_override("font_color", Color("86a39b"))
	material_heading.text = TranslationServer.translate(&"demo.ui.synthesis.materials")
	material_column.add_child(material_heading)
	material_row = HBoxContainer.new()
	material_row.name = "MaterialRow"
	material_row.alignment = BoxContainer.ALIGNMENT_CENTER
	material_row.add_theme_constant_override("separation", 18)
	material_column.add_child(material_row)

	var result_panel := PanelContainer.new()
	result_panel.anchor_left = 0.64
	result_panel.anchor_top = 0.18
	result_panel.anchor_right = 0.95
	result_panel.anchor_bottom = 0.87
	result_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("050a0c", 0.94), Color("876f47", 0.8))
	)
	add_child(result_panel)
	var result_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		result_margin.add_theme_constant_override("margin_%s" % side, 14)
	result_panel.add_child(result_margin)
	var result_column := VBoxContainer.new()
	result_column.add_theme_constant_override("separation", 10)
	result_margin.add_child(result_column)
	var candidate_heading := Label.new()
	candidate_heading.name = "CandidateHeading"
	candidate_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	candidate_heading.add_theme_color_override("font_color", Color("86a39b"))
	candidate_heading.text = TranslationServer.translate(&"demo.ui.synthesis.potential")
	result_column.add_child(candidate_heading)
	empty_candidate_label = Label.new()
	empty_candidate_label.custom_minimum_size = Vector2(0, 52)
	empty_candidate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_candidate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_candidate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_candidate_label.add_theme_color_override("font_color", Color("667d77"))
	empty_candidate_label.text = TranslationServer.translate(&"demo.ui.synthesis.empty")
	result_column.add_child(empty_candidate_label)
	candidate_button = Button.new()
	candidate_button.name = "PotentialRecipeButton"
	candidate_button.custom_minimum_size = Vector2(0, 48)
	candidate_button.add_theme_font_size_override("font_size", 19)
	candidate_button.pressed.connect(_on_candidate_pressed)
	result_column.add_child(candidate_button)
	candidate_hint_panel = PanelContainer.new()
	candidate_hint_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("10181a", 0.96), Color("5e6f69"))
	)
	result_column.add_child(candidate_hint_panel)
	candidate_hint_label = Label.new()
	candidate_hint_label.custom_minimum_size = Vector2(0, 62)
	candidate_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_hint_label.add_theme_font_size_override("font_size", 12)
	candidate_hint_label.add_theme_color_override("font_color", Color("c8bea0"))
	candidate_hint_panel.add_child(candidate_hint_label)
	var result_spacer := Control.new()
	result_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_column.add_child(result_spacer)
	output_holder = CenterContainer.new()
	output_holder.name = "SynthesisOutputHolder"
	output_holder.custom_minimum_size = Vector2(0, 140)
	result_column.add_child(output_holder)
	action_button = Button.new()
	action_button.name = "SynthesisActionButton"
	action_button.custom_minimum_size = Vector2(150, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.pressed.connect(_on_action_pressed)
	result_column.add_child(action_button)


func _on_candidate_pressed() -> void:
	candidate_selected = not candidate_selected
	refresh()


func _on_action_pressed() -> void:
	var begin_result := state.begin_synthesis()
	if not begin_result.ok:
		return
	var completed := state.advance_synthesis(999.0)
	if not completed.get("completed", false):
		return
	var output := completed.output as CardItemState
	card_staging_changed.emit(output, true)
	await _play_output_animation(output)
	card_staging_changed.emit(output, false)
	candidate_selected = false
	refresh()


func _play_output_animation(output: CardItemState) -> void:
	if output == null or output_animation_seconds <= 0.0 or not is_inside_tree():
		return
	var definition := QuestArcCatalog.item_by_id(output.definition_id)
	var overlay := CanvasLayer.new()
	overlay.layer = 300
	get_tree().root.add_child(overlay)
	var flying_card := CardHandCard.new()
	flying_card.setup(output, definition, false)
	flying_card.position = output_holder.get_global_rect().get_center() - Vector2(56, 64)
	flying_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(flying_card)
	var viewport_size := get_viewport_rect().size
	var tween := flying_card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		flying_card,
		"position",
		Vector2(viewport_size.x * 0.51, viewport_size.y - 145),
		output_animation_seconds,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		flying_card,
		"scale",
		Vector2(0.72, 0.72),
		output_animation_seconds,
	)
	await tween.finished
	overlay.queue_free()


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	refresh()


func _on_locale_changed(_locale: String) -> void:
	_build_text_refresh()
	refresh()


func _build_text_refresh() -> void:
	var title := find_child("SynthesisTitle", true, false) as Label
	var leave_button := find_child("LeaveSynthesisButton", true, false) as Button
	var material_heading := find_child("MaterialHeading", true, false) as Label
	var candidate_heading := find_child("CandidateHeading", true, false) as Label
	if title != null:
		title.text = TranslationServer.translate(&"quest.ui.synthesis.title")
	if leave_button != null:
		leave_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.leave")
	if material_heading != null:
		material_heading.text = TranslationServer.translate(&"demo.ui.synthesis.materials")
	if candidate_heading != null:
		candidate_heading.text = TranslationServer.translate(&"demo.ui.synthesis.potential")
	if empty_candidate_label != null:
		empty_candidate_label.text = TranslationServer.translate(&"demo.ui.synthesis.empty")
