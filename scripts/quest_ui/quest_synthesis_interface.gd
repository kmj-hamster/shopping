class_name QuestSynthesisInterface
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)
signal property_inspected(property_id: StringName)
signal hand_tab_requested(tab_id: StringName)
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

const BACKGROUND_TEXTURE := preload("res://resources/ui/synthesis/bg-inbag.png")
const NARRATIVE_FADE_SECONDS := 0.55
const NARRATIVE_HOLD_SECONDS := 1.25
const FIELD_CENTER := Vector2(640, 292)
const CANDIDATE_NODE_SIZE := Vector2(44, 44)
const PERSONA_ICON_SIZE := Vector2(150, 84)
const PERSONA_DIRECTIONS := {
	CardPropertySet.PERSONA_NIGHTWALKER: Vector2(-0.72, -0.69),
	CardPropertySet.PERSONA_MOURNER: Vector2(-0.72, 0.69),
	CardPropertySet.PERSONA_DREAMWALKER: Vector2(0.72, -0.69),
	CardPropertySet.PERSONA_HOMECOMER: Vector2(0.72, 0.69),
}
const PERSONA_ICON_POSITIONS := {
	CardPropertySet.PERSONA_NIGHTWALKER: Vector2(244, 70),
	CardPropertySet.PERSONA_MOURNER: Vector2(244, 394),
	CardPropertySet.PERSONA_DREAMWALKER: Vector2(886, 70),
	CardPropertySet.PERSONA_HOMECOMER: Vector2(886, 394),
}

var state: QuestGameState
var phase := Phase.DRAFT
var draft_layer: Control
var ray_layer: Control
var candidate_layer: Control
var base_slot_host: CenterContainer
var base_slot: QuestSynthesisMaterialSlot
var persona_slot: QuestSynthesisMaterialSlot
var helper_slot: QuestSynthesisMaterialSlot
var material_slots: Array[QuestSynthesisMaterialSlot] = []
var strengthen_button: Button
var reinforcement_popup: PanelContainer
var reinforcement_title: Label
var reinforcement_labels: Dictionary = {}
var candidate_buttons: Dictionary = {}
var candidate_views: Dictionary = {}
var candidate_hover_tweens: Dictionary = {}
var persona_buttons: Dictionary = {}
var persona_value_labels: Dictionary = {}
var persona_rays: Dictionary = {}
var possibility_definitions: Dictionary = {}
var action_button: Button
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
var result_back_button: Button
var result_card_view: CardHandCard
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
	# This screen sits below the persistent hand and bag button. Its full-screen
	# shell must never become a GUI hit target, or it shields those global controls.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	resized.connect(_layout_draft)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	set_process(false)
	_on_locale_changed(LocaleManager.current_locale)
	refresh()


func refresh() -> void:
	if state == null or draft_layer == null or phase != Phase.DRAFT:
		return
	_record_update(&"full")
	var snapshot := state.synthesis_evaluation_snapshot()
	_rebuild_material_slots(snapshot, true)
	_rebuild_persona_field(snapshot)
	_rebuild_candidates(snapshot)
	_update_action_button(snapshot)
	strengthen_button.visible = snapshot.get("base_card") != null
	if snapshot.get("base_card") == null:
		reinforcement_popup.visible = false


func reset_debug_update_counts() -> void:
	debug_update_counts.clear()
	last_delta_update_usec = 0
	max_delta_update_usec = 0


func _record_update(section: StringName) -> void:
	debug_update_counts[section] = int(debug_update_counts.get(section, 0)) + 1


func can_stage_card(role_id: StringName, card: CardItemState) -> bool:
	if state == null or card == null:
		return false
	if role_id == &"persona":
		var persona_id := PersonaMaskCatalog.persona_for_card(card)
		return (
			not persona_id.is_empty()
			and state.synthesis_base_instance_id > 0
			and card.location == CardItemState.Location.HAND
			and state.synthesis_persona_id != persona_id
		)
	if card not in state.inventory or not PersonaMaskCatalog.persona_for_card(card).is_empty():
		return false
	if card.location not in [CardItemState.Location.HAND, CardItemState.Location.ACTIVITY_SLOT]:
		return false
	if (
		card.location == CardItemState.Location.ACTIVITY_SLOT
		and card.activity_id == &"synthesis"
		and card.slot_id == role_id
	):
		return false
	var definition := QuestArcCatalog.item_by_id(card.definition_id)
	if role_id == &"base":
		return definition != null and definition.can_be_synthesis_base
	if role_id == &"helper":
		return (
			state.synthesis_base_instance_id > 0
			and card.instance_id != state.synthesis_base_instance_id
		)
	return false


func stage_card(role_id: StringName, card: CardItemState) -> bool:
	if not can_stage_card(role_id, card):
		return false
	if role_id == &"persona":
		return state.select_synthesis_persona(PersonaMaskCatalog.persona_for_card(card))
	var result := (
		state.assign_synthesis_base(card)
		if role_id == &"base"
		else state.assign_synthesis_helper(card)
	)
	return bool(result.ok)


func definition_for_card(card: CardItemState) -> CardItemDefinition:
	var persona_definition := PersonaMaskCatalog.definition_for_card(
		card,
		state.protagonist_persona_counts if state != null else {},
	)
	if persona_definition != null:
		return persona_definition
	return QuestArcCatalog.item_by_id(card.definition_id) if card != null else null


func request_hand_tab_for_role(role_id: StringName) -> void:
	hand_tab_requested.emit(
		QuestHandBar.TAB_MASKS if role_id == &"persona" else QuestHandBar.TAB_ITEMS
	)


func show_drop_targets_for_card(card: CardItemState) -> void:
	var is_persona := not PersonaMaskCatalog.persona_for_card(card).is_empty()
	for slot in material_slots:
		var visible_target := slot == base_slot or reinforcement_popup.visible
		var should_highlight := visible_target and slot.card == null
		if is_persona:
			should_highlight = should_highlight and slot.role_id == &"persona"
		else:
			should_highlight = should_highlight and slot.role_id in [&"base", &"helper"]
		slot.set_drop_highlight(should_highlight and can_stage_card(slot.role_id, card))


func clear_drop_target_highlights() -> void:
	for slot in material_slots:
		slot.set_drop_highlight(false)


func cancel_pending_inputs() -> void:
	set_process(false)
	clear_drop_target_highlights()
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
	if reinforcement_popup != null:
		reinforcement_popup.visible = false


func _build_interface() -> void:
	var background := TextureRect.new()
	background.name = "InBagBackground"
	background.texture = BACKGROUND_TEXTURE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	draft_layer = Control.new()
	draft_layer.name = "SynthesisDraft"
	draft_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(draft_layer)
	ray_layer = Control.new()
	ray_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ray_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draft_layer.add_child(ray_layer)
	_build_persona_field()
	_build_base_slot()
	_build_candidate_layer()
	_build_reinforcement_popup()
	_build_narrative_overlay()
	_build_result_layer()
	_layout_draft()


func _build_persona_field() -> void:
	for persona_id in CardPropertySet.PERSONAS:
		var ray := Line2D.new()
		ray.width = 4.0
		ray.default_color = Color("e6edf0", 0.34)
		ray.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ray.end_cap_mode = Line2D.LINE_CAP_ROUND
		ray_layer.add_child(ray)
		persona_rays[persona_id] = ray
		var button := Button.new()
		button.name = "%sPersonaButton" % String(persona_id).to_pascal_case()
		button.custom_minimum_size = PERSONA_ICON_SIZE
		button.size = PERSONA_ICON_SIZE
		button.flat = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_persona_pressed.bind(persona_id))
		button.mouse_entered.connect(_on_persona_hovered.bind(persona_id))
		button.mouse_exited.connect(_on_persona_unhovered.bind(persona_id))
		draft_layer.add_child(button)
		var image := TextureRect.new()
		image.texture = ItemDetailPopup.property_icon_texture(persona_id)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		var value := Label.new()
		value.anchor_left = 0.72
		value.anchor_top = 0.60
		value.anchor_right = 1.0
		value.anchor_bottom = 1.0
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 21)
		value.add_theme_color_override("font_color", Color("f1f2e8"))
		value.add_theme_color_override("font_outline_color", Color("132229"))
		value.add_theme_constant_override("outline_size", 4)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(value)
		persona_buttons[persona_id] = button
		persona_value_labels[persona_id] = value


func _build_base_slot() -> void:
	base_slot_host = CenterContainer.new()
	base_slot_host.position = FIELD_CENTER - QuestTaskSlot.CARD_SIZE * 0.5
	base_slot_host.size = QuestTaskSlot.CARD_SIZE
	base_slot_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draft_layer.add_child(base_slot_host)
	base_slot = QuestSynthesisMaterialSlot.new()
	base_slot.setup(self, &"base", null)
	base_slot.item_inspected.connect(item_inspected.emit)
	base_slot.help_requested.connect(_on_material_help_requested)
	base_slot_host.add_child(base_slot)
	material_slots.append(base_slot)
	strengthen_button = Button.new()
	strengthen_button.name = "StrengthenButton"
	strengthen_button.custom_minimum_size = Vector2(136, 34)
	strengthen_button.position = Vector2(FIELD_CENTER.x - 68, FIELD_CENTER.y + 84)
	strengthen_button.pressed.connect(_open_reinforcement_popup)
	draft_layer.add_child(strengthen_button)


func _build_candidate_layer() -> void:
	candidate_layer = Control.new()
	candidate_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	candidate_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draft_layer.add_child(candidate_layer)
	action_button = Button.new()
	action_button.name = "SynthesisActionButton"
	action_button.custom_minimum_size = Vector2(104, 34)
	action_button.pressed.connect(_on_action_pressed)
	candidate_layer.add_child(action_button)
	action_button.visible = false


func _build_reinforcement_popup() -> void:
	reinforcement_popup = PanelContainer.new()
	reinforcement_popup.name = "ReinforcementPopup"
	reinforcement_popup.anchor_left = 0.33
	reinforcement_popup.anchor_top = 0.10
	reinforcement_popup.anchor_right = 0.67
	reinforcement_popup.anchor_bottom = 0.70
	reinforcement_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	reinforcement_popup.z_index = 40
	reinforcement_popup.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071117", 0.94), Color("b9c7c8", 0.35))
	)
	draft_layer.add_child(reinforcement_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	reinforcement_popup.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	reinforcement_title = Label.new()
	reinforcement_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reinforcement_title.add_theme_font_size_override("font_size", 22)
	reinforcement_title.add_theme_color_override("font_color", Color("eef0e8"))
	header.add_child(reinforcement_title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.pressed.connect(_close_reinforcement_popup)
	header.add_child(close_button)
	var explanation := Label.new()
	explanation.name = "ReinforcementExplanation"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.add_theme_font_size_override("font_size", 14)
	explanation.add_theme_color_override("font_color", Color("c7d1d0"))
	column.add_child(explanation)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 38)
	slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(slots)
	for role_id in [&"persona", &"helper"]:
		var slot_column := VBoxContainer.new()
		slot_column.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_column.add_theme_constant_override("separation", 5)
		slots.add_child(slot_column)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("e5d6a5"))
		slot_column.add_child(label)
		reinforcement_labels[role_id] = label
		var slot := QuestSynthesisMaterialSlot.new()
		slot.setup(self, role_id, null)
		slot.item_inspected.connect(item_inspected.emit)
		slot.help_requested.connect(_on_material_help_requested)
		slot_column.add_child(slot)
		material_slots.append(slot)
		if role_id == &"persona":
			persona_slot = slot
		else:
			helper_slot = slot
	reinforcement_popup.visible = false


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
	result_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_layer)
	var center := CenterContainer.new()
	center.anchor_left = 0.32
	center.anchor_top = 0.12
	center.anchor_right = 0.68
	center.anchor_bottom = 0.74
	result_layer.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	result_holder = CenterContainer.new()
	result_holder.custom_minimum_size = Vector2(190, 190)
	column.add_child(result_holder)
	result_back_button = Button.new()
	result_back_button.name = "SynthesisResultBack"
	result_back_button.custom_minimum_size = CardHandCard.CARD_SIZE
	result_back_button.text = "◇\n◇\n◇"
	result_back_button.add_theme_font_size_override("font_size", 24)
	result_back_button.pressed.connect(_reveal_result)
	result_holder.add_child(result_back_button)
	result_card_view = CardHandCard.new()
	result_card_view.name = "SynthesisResultCard"
	result_card_view.inspect_requested.connect(item_inspected.emit)
	result_card_view.drag_finished.connect(_on_result_drag_finished)
	result_holder.add_child(result_card_view)
	result_back_button.visible = false
	result_card_view.visible = false
	result_hint = Label.new()
	result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_hint.add_theme_font_size_override("font_size", 13)
	result_hint.add_theme_color_override("font_color", Color("c8bea0"))
	column.add_child(result_hint)
	result_layer.visible = false


func _layout_draft() -> void:
	if draft_layer == null:
		return
	base_slot_host.position = FIELD_CENTER - QuestTaskSlot.CARD_SIZE * 0.5
	strengthen_button.position = Vector2(FIELD_CENTER.x - 68, FIELD_CENTER.y + 84)
	for persona_id in persona_buttons:
		(persona_buttons[persona_id] as Button).position = PERSONA_ICON_POSITIONS[persona_id]


func _rebuild_material_slots(snapshot: Dictionary, force_refresh: bool = false) -> void:
	_record_update(&"materials")
	PersonaMaskCatalog.sync_selection(state.synthesis_persona_id)
	base_slot.setup(self, &"base", snapshot.get("base_card") as CardItemState, force_refresh)
	persona_slot.setup(
		self,
		&"persona",
		PersonaMaskCatalog.card_for_persona(state.synthesis_persona_id)
		if not state.synthesis_persona_id.is_empty()
		else null,
		force_refresh,
	)
	helper_slot.setup(
		self, &"helper", snapshot.get("helper_card") as CardItemState, force_refresh
	)


func _rebuild_persona_field(snapshot: Dictionary) -> void:
	_record_update(&"personas")
	var totals := snapshot.get("totals", {}) as Dictionary
	for persona_id in CardPropertySet.PERSONAS:
		var amount := int(totals.get(persona_id, 0))
		(persona_value_labels[persona_id] as Label).text = str(amount)
		var direction := PERSONA_DIRECTIONS[persona_id] as Vector2
		var length := minf(44.0 + amount * 19.0, 250.0)
		var ray := persona_rays[persona_id] as Line2D
		ray.points = PackedVector2Array([FIELD_CENTER, FIELD_CENTER + direction * length])
		ray.default_color = (
			Color("f0f1e8", 0.76) if amount > 0 else Color("9aabb0", 0.22)
		)


func _rebuild_candidates(snapshot: Dictionary) -> void:
	_record_update(&"candidates")
	var candidates := snapshot.get("candidates", []) as Array
	var desired_ids: Array[StringName] = []
	var occupied_positions: Dictionary = {}
	for candidate in candidates:
		desired_ids.append(StringName(candidate.recipe_id))
	for raw_recipe_id in candidate_views:
		var old_view := candidate_views[raw_recipe_id] as Dictionary
		(old_view.button as Button).visible = desired_ids.has(StringName(raw_recipe_id))
	for candidate in candidates:
		var recipe_id := StringName(candidate.recipe_id)
		var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
		if not candidate_views.has(recipe_id):
			candidate_views[recipe_id] = _create_candidate_view(recipe)
		var view := candidate_views[recipe_id] as Dictionary
		var button := view.button as Button
		var position := _candidate_position(recipe, occupied_positions)
		button.position = position - CANDIDATE_NODE_SIZE * 0.5
		button.visible = true
		button.disabled = false
		button.button_pressed = state.synthesis_candidate_recipe_id == recipe_id
		button.text = "◆" if candidate.is_complete else "◇"
		button.add_theme_font_size_override("font_size", 31)
		button.add_theme_color_override(
			"font_color", Color("f5f1e2") if candidate.is_complete else Color("657278")
		)
		button.add_theme_color_override(
			"font_hover_color", Color("ffffff") if candidate.is_complete else Color("9ca9ad")
		)
		view["candidate"] = candidate
		view["position"] = position
	_update_candidate_hover_state(&"")


func _create_candidate_view(recipe: SynthesisRecipeDefinition) -> Dictionary:
	var button := Button.new()
	button.name = "%sCandidate" % String(recipe.id).to_pascal_case()
	button.custom_minimum_size = CANDIDATE_NODE_SIZE
	button.size = CANDIDATE_NODE_SIZE
	button.toggle_mode = true
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_candidate_pressed.bind(recipe.id))
	candidate_layer.add_child(button)
	candidate_buttons[recipe.id] = button
	return {"button": button, "candidate": {}, "position": Vector2.ZERO}


func _candidate_position(
	recipe: SynthesisRecipeDefinition,
	occupied_positions: Dictionary,
) -> Vector2:
	var offset := Vector2.ZERO
	for raw_persona in recipe.required_personas:
		var persona_id := StringName(raw_persona)
		var amount := recipe.required_value(persona_id)
		offset += (PERSONA_DIRECTIONS[persona_id] as Vector2) * (56.0 + amount * 18.0)
	if recipe.required_personas.size() > 1:
		offset *= 0.72
	if offset.length() < 72.0:
		var seed: int = absi(String(recipe.id).hash()) % 360
		offset = Vector2.RIGHT.rotated(deg_to_rad(float(seed))) * 86.0
	var position := FIELD_CENTER + offset
	position.x = clampf(position.x, 392.0, 888.0)
	position.y = clampf(position.y, 104.0, 480.0)
	var key := Vector2i(roundi(position.x / 16.0), roundi(position.y / 16.0))
	var overlap_index := int(occupied_positions.get(key, 0))
	occupied_positions[key] = overlap_index + 1
	if overlap_index > 0:
		var angle := float((overlap_index - 1) % 8) * TAU / 8.0
		position += Vector2.RIGHT.rotated(angle) * (16.0 + 8.0 * ((overlap_index - 1) / 8))
	return position


func _update_action_button(snapshot: Dictionary = {}) -> void:
	_record_update(&"action")
	action_button.text = TranslationServer.translate(&"quest.ui.synthesis.action")
	var selected: Dictionary = {}
	var candidates := (
		snapshot.get("candidates", []) as Array
		if not snapshot.is_empty()
		else state.synthesis_candidates()
	)
	for candidate in candidates:
		if StringName(candidate.recipe_id) == state.synthesis_candidate_recipe_id:
			selected = candidate
			break
	var can_craft := not selected.is_empty() and bool(selected.is_complete)
	action_button.visible = can_craft
	action_button.disabled = not can_craft
	if can_craft:
		var view := candidate_views.get(state.synthesis_candidate_recipe_id) as Dictionary
		var node_position := view.get("position", FIELD_CENTER) as Vector2
		action_button.position = Vector2(node_position.x - 52.0, node_position.y + 28.0)
		action_button.move_to_front()


func _on_persona_pressed(persona_id: StringName) -> void:
	property_inspected.emit(persona_id)


func _on_persona_hovered(persona_id: StringName) -> void:
	_update_candidate_hover_state(persona_id)


func _on_persona_unhovered(persona_id: StringName) -> void:
	var button := persona_buttons.get(persona_id) as Button
	if button != null and not button.get_global_rect().has_point(get_global_mouse_position()):
		_update_candidate_hover_state(&"")


func _update_candidate_hover_state(persona_id: StringName) -> void:
	for raw_recipe_id in candidate_views:
		var recipe_id := StringName(raw_recipe_id)
		var view := candidate_views[recipe_id] as Dictionary
		var button := view.button as Button
		var tween := candidate_hover_tweens.get(recipe_id) as Tween
		if tween != null and tween.is_valid():
			tween.kill()
		candidate_hover_tweens.erase(recipe_id)
		button.modulate = Color.WHITE
		if persona_id.is_empty() or not button.visible:
			continue
		var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
		var output := QuestArcCatalog.item_by_id(recipe.output_id) if recipe != null else null
		if output == null or not output.has_property(persona_id):
			continue
		var pulse := button.create_tween().set_loops()
		pulse.tween_property(button, "modulate", Color(1.38, 1.38, 1.38, 1.0), 0.34)
		pulse.tween_property(button, "modulate", Color.WHITE, 0.34)
		candidate_hover_tweens[recipe_id] = pulse


func _open_reinforcement_popup() -> void:
	if state == null or state.synthesis_base_instance_id <= 0:
		return
	reinforcement_popup.visible = true
	reinforcement_popup.move_to_front()


func _close_reinforcement_popup() -> void:
	reinforcement_popup.visible = false
	clear_drop_target_highlights()


func _on_material_help_requested(role_id: StringName) -> void:
	var definition := _material_help_definition(role_id)
	if definition != null:
		item_inspected.emit(definition)


func _material_help_definition(role_id: StringName) -> CardItemDefinition:
	if role_id not in [&"base", &"helper", &"persona"]:
		return null
	var definition := CardItemDefinition.new()
	definition.id = StringName("synthesis_%s_help" % role_id)
	definition.display_name_key = StringName("demo.ui.synthesis.%s" % role_id)
	definition.description_key = StringName("demo.ui.synthesis.%s.description" % role_id)
	definition.can_recycle = false
	definition.can_be_synthesis_base = false
	definition.property_set = CardPropertySet.new()
	return definition


func _on_candidate_pressed(recipe_id: StringName) -> void:
	if not state.select_synthesis_candidate(recipe_id):
		return
	var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
	var candidate := _candidate_by_id(recipe_id)
	if candidate.get("shows_output", false) or candidate.get("is_complete", false):
		item_inspected.emit(QuestArcCatalog.item_by_id(recipe.output_id))
	else:
		item_inspected.emit(_possibility_definition(recipe))
	_update_action_button()
	_update_candidate_selection()


func _candidate_by_id(recipe_id: StringName) -> Dictionary:
	for candidate in state.synthesis_candidates():
		if StringName(candidate.recipe_id) == recipe_id:
			return candidate
	return {}


func _possibility_definition(recipe: SynthesisRecipeDefinition) -> CardItemDefinition:
	var definition := possibility_definitions.get(recipe.id) as CardItemDefinition
	if definition == null:
		definition = CardItemDefinition.new()
		definition.id = StringName("possibility_%s" % recipe.id)
		definition.display_name_key = &"quest.ui.synthesis.possibility.title"
		definition.can_recycle = false
		definition.can_be_synthesis_base = false
		definition.property_set = CardPropertySet.new()
		possibility_definitions[recipe.id] = definition
	definition.description_key = recipe.possibility_hint_key
	definition.property_set.tags.clear()
	var output := QuestArcCatalog.item_by_id(recipe.output_id)
	if output != null and output.property_set != null:
		for property_id in output.property_set.tags:
			var property := QuestArcCatalog.property_by_id(property_id)
			if property != null and property.is_item_category:
				definition.property_set.tags.append(property_id)
	definition.property_set.values = recipe.required_personas.duplicate()
	return definition


func _update_candidate_selection() -> void:
	_record_update(&"candidate_selection")
	for recipe_id in candidate_buttons:
		(candidate_buttons[recipe_id] as Button).button_pressed = (
			state.synthesis_candidate_recipe_id == recipe_id
		)


func _on_action_pressed() -> void:
	var result := state.begin_synthesis()
	if not result.ok:
		return
	pending_output = result.output as CardItemState
	card_staging_changed.emit(pending_output, true)
	details_cleared.emit()
	reinforcement_popup.visible = false
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
	result_back_button.visible = false
	result_card_view.visible = false
	if pending_output == null:
		return
	if not result_revealed:
		result_back_button.visible = true
		result_hint.text = TranslationServer.translate(&"demo.ui.synthesis.flip_result")
		return
	var definition := QuestArcCatalog.item_by_id(pending_output.definition_id)
	result_card_view.setup(pending_output, definition, true)
	result_card_view.visible = true
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
	if delta == null or not delta.affects_synthesis() or phase != Phase.DRAFT:
		return
	var started_usec := Time.get_ticks_usec()
	if delta.full_reconcile:
		refresh()
	elif delta.synthesis_draft_changed or delta.synthesis_persona_changed:
		var snapshot := state.synthesis_evaluation_snapshot()
		_rebuild_material_slots(snapshot)
		_rebuild_persona_field(snapshot)
		_rebuild_candidates(snapshot)
		_update_action_button(snapshot)
		strengthen_button.visible = snapshot.get("base_card") != null
		if snapshot.get("base_card") == null:
			reinforcement_popup.visible = false
	elif delta.synthesis_candidate_changed:
		_update_candidate_selection()
		_update_action_button()
	last_delta_update_usec = Time.get_ticks_usec() - started_usec
	max_delta_update_usec = maxi(max_delta_update_usec, last_delta_update_usec)


func _on_locale_changed(_locale: String) -> void:
	strengthen_button.text = TranslationServer.translate(&"quest.ui.synthesis.strengthen")
	reinforcement_title.text = TranslationServer.translate(&"quest.ui.synthesis.reinforcement")
	var explanation := reinforcement_popup.find_child("ReinforcementExplanation", true, false) as Label
	if explanation != null:
		explanation.text = TranslationServer.translate(&"quest.ui.synthesis.reinforcement.description")
	(reinforcement_labels[&"persona"] as Label).text = TranslationServer.translate(
		&"quest.ui.synthesis.borrow_self"
	)
	(reinforcement_labels[&"helper"] as Label).text = TranslationServer.translate(
		&"quest.ui.synthesis.borrow_item"
	)
	if phase == Phase.DRAFT:
		refresh()
