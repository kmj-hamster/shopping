class_name QuestSynthesisInterface
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)
signal card_staging_changed(card: CardItemState, staged: bool)
signal details_cleared

enum Phase {
	DRAFT,
	NARRATIVE,
	RESULT,
}

enum NarrativeState {
	IDLE,
	FADING,
	HOLDING,
}

const NARRATIVE_FADE_SECONDS := 0.55
const NARRATIVE_HOLD_SECONDS := 1.25

var state: QuestGameState
var phase := Phase.DRAFT
var draft_layer: Control
var totals_row: HBoxContainer
var base_slot_host: CenterContainer
var fuel_slot_host: CenterContainer
var candidate_list: VBoxContainer
var candidate_empty_label: Label
var candidate_buttons: Dictionary = {}
var candidate_views: Dictionary = {}
var persona_row: HBoxContainer
var persona_buttons: Dictionary = {}
var persona_definitions: Dictionary = {}
var action_button: Button
var material_slots: Array[QuestSynthesisMaterialSlot] = []
var total_chip_views: Dictionary = {}
var totals_placeholder: Label
var narrative_overlay: ColorRect
var narrative_column: VBoxContainer
var narrative_lines: Array[String] = []
var narrative_index := -1
var narrative_state := NarrativeState.IDLE
var narrative_timer := 0.0
var current_narrative_label: Label
var result_layer: Control
var result_holder: CenterContainer
var result_hint: Label
var pending_output: CardItemState
var result_revealed := false
var debug_update_counts: Dictionary = {}
var last_delta_update_usec := 0
var max_delta_update_usec := 0


func setup(game_state: QuestGameState) -> void:
	if state != null and state.state_delta.is_connected(_on_state_delta):
		state.state_delta.disconnect(_on_state_delta)
	state = game_state
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)
	if is_node_ready():
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	set_process(false)
	refresh()


func refresh() -> void:
	if state == null or draft_layer == null or phase != Phase.DRAFT:
		return
	_record_update(&"full")
	var snapshot := state.synthesis_evaluation_snapshot()
	_rebuild_totals(snapshot)
	_rebuild_material_slots(snapshot, true)
	_rebuild_candidates(snapshot)
	_rebuild_personas()
	_update_action_button()


func reset_debug_update_counts() -> void:
	debug_update_counts.clear()
	last_delta_update_usec = 0
	max_delta_update_usec = 0


func _record_update(section: StringName) -> void:
	debug_update_counts[section] = int(debug_update_counts.get(section, 0)) + 1


func _update_action_button() -> void:
	_record_update(&"action")
	action_button.text = TranslationServer.translate(&"quest.ui.synthesis.action")
	action_button.visible = not state.synthesis_candidate_recipe_id.is_empty()
	action_button.disabled = state.synthesis_candidate_recipe_id.is_empty()


func can_stage_card(role_id: StringName, card: CardItemState) -> bool:
	if state == null or card == null or card not in state.inventory:
		return false
	if card.location != CardItemState.Location.HAND:
		return false
	return role_id in [&"base", &"fuel"]


func stage_card(role_id: StringName, card: CardItemState) -> bool:
	var result := (
		state.assign_synthesis_base(card)
		if role_id == &"base"
		else state.assign_synthesis_fuel(card)
	)
	return bool(result.ok)


func remove_material(_role_id: StringName, card: CardItemState) -> void:
	if state != null:
		state.return_card_to_hand(card)


func cancel_pending_inputs() -> void:
	set_process(false)
	if pending_output != null:
		card_staging_changed.emit(pending_output, false)
		pending_output = null
	if state != null:
		state.clear_synthesis_draft()
	phase = Phase.DRAFT
	narrative_state = NarrativeState.IDLE
	current_narrative_label = null
	if draft_layer != null:
		draft_layer.visible = true
	if narrative_overlay != null:
		narrative_overlay.visible = false
	if result_layer != null:
		result_layer.visible = false


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("020b10")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var distant_glow := ColorRect.new()
	distant_glow.color = Color("1a5b59", 0.24)
	distant_glow.anchor_left = 0.04
	distant_glow.anchor_top = 0.06
	distant_glow.anchor_right = 0.96
	distant_glow.anchor_bottom = 0.94
	distant_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(distant_glow)

	var title := Label.new()
	title.name = "SynthesisTitle"
	title.anchor_left = 0.035
	title.anchor_top = 0.025
	title.anchor_right = 0.38
	title.anchor_bottom = 0.11
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("ddc985"))
	title.text = TranslationServer.translate(&"quest.ui.synthesis.title")
	add_child(title)

	var close_button := Button.new()
	close_button.name = "LeaveSynthesisButton"
	close_button.anchor_left = 0.935
	close_button.anchor_top = 0.025
	close_button.anchor_right = 0.985
	close_button.anchor_bottom = 0.105
	close_button.text = "×"
	close_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.leave")
	close_button.pressed.connect(leave_requested.emit)
	add_child(close_button)

	draft_layer = Control.new()
	draft_layer.name = "SynthesisDraft"
	draft_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(draft_layer)
	_build_totals_panel()
	_build_material_region()
	_build_candidate_region()
	_build_persona_region()
	_build_narrative_overlay()
	_build_result_layer()


func _build_totals_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_top = 0.035
	panel.anchor_right = 0.75
	panel.anchor_bottom = 0.16
	panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("061216", 0.78), Color("607a73", 0.62))
	)
	draft_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var label := Label.new()
	label.name = "TotalsHeading"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("8ea59f"))
	label.text = TranslationServer.translate(&"demo.ui.synthesis.totals")
	column.add_child(label)
	totals_row = HBoxContainer.new()
	totals_row.alignment = BoxContainer.ALIGNMENT_CENTER
	totals_row.add_theme_constant_override("separation", 8)
	column.add_child(totals_row)
	totals_placeholder = Label.new()
	totals_placeholder.text = "—"
	totals_placeholder.add_theme_color_override("font_color", Color("62746f"))
	totals_row.add_child(totals_placeholder)
	_prebuild_total_chips()


func _build_material_region() -> void:
	base_slot_host = _make_slot_host(0.04, 0.28, 0.29, 0.67, &"demo.ui.synthesis.base")
	fuel_slot_host = _make_slot_host(0.71, 0.28, 0.96, 0.67, &"demo.ui.synthesis.fuel")
	for role_id in [&"base", &"fuel"]:
		var slot := QuestSynthesisMaterialSlot.new()
		slot.setup(self, role_id, null)
		slot.item_inspected.connect(item_inspected.emit)
		(base_slot_host if role_id == &"base" else fuel_slot_host).add_child(slot)
		material_slots.append(slot)


func _make_slot_host(
	left: float,
	top: float,
	right: float,
	bottom: float,
	label_key: StringName,
) -> CenterContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.add_theme_stylebox_override("panel", UiPalette.panel_style(Color("031014", 0.36)))
	draft_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("c8b67f"))
	label.text = TranslationServer.translate(label_key)
	column.add_child(label)
	var host := CenterContainer.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(host)
	return host


func _build_candidate_region() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.30
	panel.anchor_top = 0.19
	panel.anchor_right = 0.70
	panel.anchor_bottom = 0.68
	panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("040b0e", 0.84), Color("836f48", 0.72))
	)
	draft_layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := Label.new()
	heading.name = "CandidateHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color("ddc985"))
	heading.text = TranslationServer.translate(&"demo.ui.synthesis.candidates")
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	candidate_list = VBoxContainer.new()
	candidate_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_list.add_theme_constant_override("separation", 7)
	scroll.add_child(candidate_list)
	candidate_empty_label = Label.new()
	candidate_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	candidate_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	candidate_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_empty_label.add_theme_color_override("font_color", Color("62746f"))
	candidate_empty_label.text = TranslationServer.translate(&"demo.ui.synthesis.no_candidates")
	candidate_list.add_child(candidate_empty_label)
	_prebuild_candidate_views()
	action_button = Button.new()
	action_button.name = "SynthesisActionButton"
	action_button.custom_minimum_size = Vector2(150, 38)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.pressed.connect(_on_action_pressed)
	column.add_child(action_button)


func _build_persona_region() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_top = 0.70
	panel.anchor_right = 0.85
	panel.anchor_bottom = 0.985
	panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("031014", 0.56), Color("506b66", 0.54))
	)
	draft_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)
	var heading := Label.new()
	heading.name = "PersonaHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color("8ea59f"))
	heading.text = TranslationServer.translate(&"demo.ui.synthesis.personas")
	column.add_child(heading)
	persona_row = HBoxContainer.new()
	persona_row.alignment = BoxContainer.ALIGNMENT_CENTER
	persona_row.add_theme_constant_override("separation", 9)
	column.add_child(persona_row)
	_create_persona_buttons()


func _build_narrative_overlay() -> void:
	narrative_overlay = ColorRect.new()
	narrative_overlay.name = "SynthesisNarrative"
	narrative_overlay.color = Color.BLACK
	narrative_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	narrative_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	narrative_overlay.gui_input.connect(_on_narrative_input)
	add_child(narrative_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrative_overlay.add_child(center)
	narrative_column = VBoxContainer.new()
	narrative_column.custom_minimum_size = Vector2(560, 0)
	narrative_column.add_theme_constant_override("separation", 18)
	center.add_child(narrative_column)
	narrative_overlay.visible = false


func _build_result_layer() -> void:
	result_layer = Control.new()
	result_layer.name = "SynthesisResult"
	result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(result_layer)
	_add_result_empty_slot(0.08, 0.30, 0.28, 0.66)
	_add_result_empty_slot(0.72, 0.30, 0.92, 0.66)
	var center := CenterContainer.new()
	center.anchor_left = 0.28
	center.anchor_top = 0.18
	center.anchor_right = 0.72
	center.anchor_bottom = 0.76
	result_layer.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	result_holder = CenterContainer.new()
	result_holder.custom_minimum_size = Vector2(190, 190)
	column.add_child(result_holder)
	result_hint = Label.new()
	result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_hint.add_theme_font_size_override("font_size", 13)
	result_hint.add_theme_color_override("font_color", Color("c8bea0"))
	column.add_child(result_hint)
	result_layer.visible = false


func _add_result_empty_slot(left: float, top: float, right: float, bottom: float) -> void:
	var host := CenterContainer.new()
	host.anchor_left = left
	host.anchor_top = top
	host.anchor_right = right
	host.anchor_bottom = bottom
	result_layer.add_child(host)
	var empty_slot := PanelContainer.new()
	empty_slot.custom_minimum_size = QuestSynthesisMaterialSlot.SLOT_SIZE
	var style := UiPalette.panel_style(Color("050708", 0.54), Color("6e6958", 0.50))
	style.corner_radius_top_left = 58
	style.corner_radius_top_right = 58
	style.corner_radius_bottom_left = 58
	style.corner_radius_bottom_right = 58
	style.set_border_width_all(2)
	empty_slot.add_theme_stylebox_override("panel", style)
	host.add_child(empty_slot)
	var mark := Label.new()
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.text = "+"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 40)
	mark.add_theme_color_override("font_color", Color("65716d", 0.64))
	empty_slot.add_child(mark)


func _rebuild_totals(snapshot: Dictionary) -> void:
	_record_update(&"totals")
	var desired_tags: Array[StringName] = []
	var desired_amounts: Dictionary = {}
	var base := snapshot.get("base_item") as CardItemDefinition
	if base != null and base.property_set != null:
		for tag in base.property_set.tags:
			if not desired_tags.has(tag):
				desired_tags.append(tag)
			desired_amounts[tag] = 0
	var totals := snapshot.get("totals", {}) as Dictionary
	for aspect in CardPropertySet.ASPECTS:
		var amount := int(totals.get(aspect, 0))
		if amount > 0:
			if not desired_tags.has(aspect):
				desired_tags.append(aspect)
			desired_amounts[aspect] = amount

	for raw_tag in total_chip_views:
		var tag := StringName(raw_tag)
		var chip := total_chip_views[tag] as Dictionary
		var root := chip.get("root") as Control
		if root != null:
			root.visible = desired_tags.has(tag)

	for index in desired_tags.size():
		var tag := desired_tags[index]
		if not total_chip_views.has(tag):
			total_chip_views[tag] = _create_total_chip(tag)
		var chip := total_chip_views[tag] as Dictionary
		var root := chip.root as Control
		var value := chip.value as Label
		var amount := int(desired_amounts[tag])
		root.visible = true
		value.text = str(amount)
		value.visible = amount > 0
		if root.get_index() != index:
			totals_row.move_child(root, index)
	totals_placeholder.visible = desired_tags.is_empty()
	if totals_placeholder.visible:
		totals_row.move_child(totals_placeholder, 0)


func _prebuild_total_chips() -> void:
	var content := QuestArcCatalog.manifest()
	if content == null:
		return
	for raw_property in content.properties:
		var property := raw_property as PropertyDefinition
		if property == null or total_chip_views.has(property.id):
			continue
		var chip := _create_total_chip(property.id)
		(chip.root as Control).visible = false
		total_chip_views[property.id] = chip


func _create_total_chip(tag: StringName) -> Dictionary:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 3)
	var icon := ItemDetailPopup.make_property_icon_button(tag, 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var value := Label.new()
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", Color("e8ddbf"))
	chip.add_child(value)
	totals_row.add_child(chip)
	return {"root": chip, "value": value}


func _rebuild_material_slots(snapshot: Dictionary, force_refresh: bool = false) -> void:
	_record_update(&"materials")
	if material_slots.size() != 2:
		return
	material_slots[0].setup(
		self, &"base", snapshot.get("base_card") as CardItemState, force_refresh
	)
	material_slots[1].setup(
		self, &"fuel", snapshot.get("fuel_card") as CardItemState, force_refresh
	)


func _rebuild_candidates(snapshot: Dictionary) -> void:
	_record_update(&"candidates")
	var candidates := snapshot.get("candidates", []) as Array
	var desired_ids: Array[StringName] = []
	for candidate in candidates:
		desired_ids.append(StringName(candidate.recipe_id))

	for raw_recipe_id in candidate_views:
		var recipe_id := StringName(raw_recipe_id)
		var view := candidate_views[recipe_id] as Dictionary
		var button := view.get("button") as Button
		if button != null:
			button.visible = desired_ids.has(recipe_id)

	var totals := snapshot.get("totals", {}) as Dictionary
	for index in candidates.size():
		var candidate := candidates[index] as Dictionary
		var recipe_id := StringName(candidate.recipe_id)
		var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
		if not candidate_views.has(recipe_id):
			candidate_views[recipe_id] = _create_candidate_view(recipe)
		var view := candidate_views[recipe_id] as Dictionary
		var button := view.button as Button
		button.visible = true
		button.disabled = not candidate.is_complete
		button.button_pressed = state.synthesis_candidate_recipe_id == recipe_id
		button.text = (
			QuestArcCatalog.item_by_id(recipe.output_id).localized_name()
			if candidate.is_complete
			else TranslationServer.translate(&"demo.ui.synthesis.unknown_candidate")
		)
		button.add_theme_color_override(
			"font_color", Color("dfd5b7") if candidate.is_complete else Color("707673")
		)
		var requirement_values := view.requirement_values as Dictionary
		for raw_aspect in recipe.required_aspects:
			var aspect := StringName(raw_aspect)
			var value := requirement_values[aspect] as Label
			var actual := int(totals.get(aspect, 0))
			var required := int(recipe.required_aspects[raw_aspect])
			value.text = "%d/%d" % [actual, required]
			value.add_theme_color_override(
				"font_color", Color("d9c98f") if actual >= required else Color("777c79")
			)
		if button.get_index() != index:
			candidate_list.move_child(button, index)
	candidate_empty_label.text = TranslationServer.translate(&"demo.ui.synthesis.no_candidates")
	candidate_empty_label.visible = candidates.is_empty()
	if candidate_empty_label.visible:
		candidate_list.move_child(candidate_empty_label, 0)


func _prebuild_candidate_views() -> void:
	if state == null:
		return
	for recipe_id in state.available_synthesis_recipe_ids():
		var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
		if recipe == null or candidate_views.has(recipe_id):
			continue
		var view := _create_candidate_view(recipe)
		(view.button as Button).visible = false
		candidate_views[recipe_id] = view


func _create_candidate_view(recipe: SynthesisRecipeDefinition) -> Dictionary:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_candidate_pressed.bind(recipe.id))
	candidate_list.add_child(button)
	candidate_buttons[recipe.id] = button
	var requirements := HBoxContainer.new()
	requirements.alignment = BoxContainer.ALIGNMENT_CENTER
	requirements.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var requirement_values: Dictionary = {}
	for raw_aspect in recipe.required_aspects:
		var aspect := StringName(raw_aspect)
		requirement_values[aspect] = _add_requirement_chip(requirements, aspect)
	button.add_child(requirements)
	requirements.anchor_left = 0.58
	requirements.anchor_top = 0.12
	requirements.anchor_right = 0.96
	requirements.anchor_bottom = 0.88
	return {
		"button": button,
		"requirement_values": requirement_values,
	}


func _add_requirement_chip(
	parent: Container,
	aspect: StringName,
) -> Label:
	var icon := ItemDetailPopup.make_property_icon_button(aspect, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	var value := Label.new()
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 12)
	parent.add_child(value)
	return value


func _rebuild_personas() -> void:
	_record_update(&"persona_text")
	for persona_id in CardPropertySet.PROTAGONIST_STATS:
		var definition := _persona_definition(persona_id)
		var button := persona_buttons[persona_id] as Button
		button.button_pressed = state.synthesis_persona_id == persona_id
		button.text = "%s\n%s  %d" % [
			definition.localized_name(),
			TranslationServer.translate(
				QuestArcCatalog.property_by_id(CardPropertySet.aspect_for_persona(persona_id)).display_name_key
			),
			int(state.protagonist_aspect_counts.get(persona_id, 0)),
		]


func _update_persona_selection() -> void:
	_record_update(&"persona_selection")
	for persona_id in persona_buttons:
		(persona_buttons[persona_id] as Button).button_pressed = (
			state.synthesis_persona_id == persona_id
		)


func _update_candidate_selection() -> void:
	_record_update(&"candidate_selection")
	for recipe_id in candidate_buttons:
		(candidate_buttons[recipe_id] as Button).button_pressed = (
			state.synthesis_candidate_recipe_id == recipe_id
		)


func _create_persona_buttons() -> void:
	for persona_id in CardPropertySet.PROTAGONIST_STATS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(118, 82)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_persona_pressed.bind(persona_id))
		persona_row.add_child(button)
		persona_buttons[persona_id] = button


func _persona_definition(persona_id: StringName) -> CardItemDefinition:
	var definition := persona_definitions.get(persona_id) as CardItemDefinition
	if definition == null:
		definition = CardItemDefinition.new()
		definition.id = StringName("persona_%s" % persona_id)
		definition.display_name_key = StringName("demo.persona.%s.name" % persona_id)
		definition.description_key = StringName("demo.persona.%s.description" % persona_id)
		definition.can_recycle = false
		definition.can_be_synthesis_base = false
		definition.property_set = CardPropertySet.new()
		definition.image = ItemDetailPopup.property_icon_texture(
			CardPropertySet.aspect_for_persona(persona_id)
		)
		persona_definitions[persona_id] = definition
	definition.property_set.values = {
		CardPropertySet.aspect_for_persona(persona_id): int(
			state.protagonist_aspect_counts.get(persona_id, 0)
		),
	}
	return definition


func _on_persona_pressed(persona_id: StringName) -> void:
	if state.select_synthesis_persona(persona_id):
		item_inspected.emit(_persona_definition(persona_id))


func _on_candidate_pressed(recipe_id: StringName) -> void:
	if not state.select_synthesis_candidate(recipe_id):
		return
	var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
	item_inspected.emit(QuestArcCatalog.item_by_id(recipe.output_id))


func _on_action_pressed() -> void:
	var result := state.begin_synthesis()
	if not result.ok:
		return
	pending_output = result.output as CardItemState
	card_staging_changed.emit(pending_output, true)
	details_cleared.emit()
	_start_narrative(result.process_text_keys)


func _start_narrative(text_keys: Array) -> void:
	phase = Phase.NARRATIVE
	draft_layer.visible = false
	result_layer.visible = false
	narrative_overlay.visible = true
	for child in narrative_column.get_children():
		child.free()
	narrative_lines.clear()
	for raw_key in text_keys:
		narrative_lines.append(TranslationServer.translate(StringName(raw_key)))
	narrative_index = -1
	narrative_state = NarrativeState.IDLE
	_advance_narrative()
	set_process(true)


func _process(delta: float) -> void:
	if phase != Phase.NARRATIVE or current_narrative_label == null:
		return
	match narrative_state:
		NarrativeState.FADING:
			var alpha := minf(1.0, current_narrative_label.modulate.a + delta / NARRATIVE_FADE_SECONDS)
			current_narrative_label.modulate.a = alpha
			if alpha >= 1.0:
				narrative_state = NarrativeState.HOLDING
				narrative_timer = NARRATIVE_HOLD_SECONDS
		NarrativeState.HOLDING:
			narrative_timer -= delta
			if narrative_timer <= 0.0:
				_advance_narrative()


func _on_narrative_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if narrative_state == NarrativeState.FADING:
		current_narrative_label.modulate.a = 1.0
		narrative_state = NarrativeState.HOLDING
		narrative_timer = NARRATIVE_HOLD_SECONDS
	elif narrative_state == NarrativeState.HOLDING:
		_advance_narrative()


func _advance_narrative() -> void:
	narrative_index += 1
	if narrative_index >= narrative_lines.size():
		_show_result()
		return
	current_narrative_label = Label.new()
	current_narrative_label.text = narrative_lines[narrative_index]
	current_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_narrative_label.add_theme_font_size_override("font_size", 18)
	current_narrative_label.add_theme_color_override("font_color", Color("e4dfd2"))
	current_narrative_label.modulate.a = 0.0
	narrative_column.add_child(current_narrative_label)
	narrative_state = NarrativeState.FADING


func _show_result() -> void:
	set_process(false)
	phase = Phase.RESULT
	narrative_state = NarrativeState.IDLE
	narrative_overlay.visible = false
	result_layer.visible = true
	result_revealed = false
	_rebuild_result()


func _rebuild_result() -> void:
	for child in result_holder.get_children():
		child.free()
	if pending_output == null:
		return
	if not result_revealed:
		var back := Button.new()
		back.custom_minimum_size = CardHandCard.CARD_SIZE
		back.text = "◇\n◇\n◇"
		back.add_theme_font_size_override("font_size", 24)
		back.pressed.connect(_reveal_result)
		result_holder.add_child(back)
		result_hint.text = TranslationServer.translate(&"demo.ui.synthesis.flip_result")
		return
	var definition := QuestArcCatalog.item_by_id(pending_output.definition_id)
	var card_view := CardHandCard.new()
	card_view.setup(pending_output, definition, true)
	card_view.inspect_requested.connect(item_inspected.emit)
	card_view.drag_finished.connect(_on_result_drag_finished)
	result_holder.add_child(card_view)
	result_hint.text = TranslationServer.translate(&"demo.ui.synthesis.drag_result")


func _reveal_result() -> void:
	result_revealed = true
	_rebuild_result()


func _on_result_drag_finished(_card: CardItemState, succeeded: bool) -> void:
	if not succeeded or pending_output == null:
		return
	card_staging_changed.emit(pending_output, false)
	pending_output = null
	phase = Phase.DRAFT
	result_layer.visible = false
	draft_layer.visible = true
	refresh()


func _on_state_delta(delta: QuestStateDelta) -> void:
	if (
		delta == null
		or not delta.affects_synthesis()
		or phase != Phase.DRAFT
		or draft_layer == null
	):
		return
	var started_usec := Time.get_ticks_usec()
	if delta.full_reconcile:
		refresh()
	elif delta.synthesis_draft_changed:
		var snapshot := state.synthesis_evaluation_snapshot()
		_rebuild_material_slots(snapshot)
		_rebuild_totals(snapshot)
		_rebuild_candidates(snapshot)
		_update_action_button()
	elif delta.synthesis_persona_changed:
		var snapshot := state.synthesis_evaluation_snapshot()
		_update_persona_selection()
		_rebuild_totals(snapshot)
		_rebuild_candidates(snapshot)
		_update_action_button()
	elif delta.synthesis_candidate_changed:
		_update_candidate_selection()
		_update_action_button()
	last_delta_update_usec = Time.get_ticks_usec() - started_usec
	max_delta_update_usec = maxi(max_delta_update_usec, last_delta_update_usec)


func _on_locale_changed(_locale: String) -> void:
	var title := find_child("SynthesisTitle", true, false) as Label
	var leave_button := find_child("LeaveSynthesisButton", true, false) as Button
	var totals_heading := find_child("TotalsHeading", true, false) as Label
	var candidate_heading := find_child("CandidateHeading", true, false) as Label
	var persona_heading := find_child("PersonaHeading", true, false) as Label
	if title != null:
		title.text = TranslationServer.translate(&"quest.ui.synthesis.title")
	if leave_button != null:
		leave_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.leave")
	if totals_heading != null:
		totals_heading.text = TranslationServer.translate(&"demo.ui.synthesis.totals")
	if candidate_heading != null:
		candidate_heading.text = TranslationServer.translate(&"demo.ui.synthesis.candidates")
	if persona_heading != null:
		persona_heading.text = TranslationServer.translate(&"demo.ui.synthesis.personas")
	refresh()
