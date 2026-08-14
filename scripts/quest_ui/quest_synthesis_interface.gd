class_name QuestSynthesisInterface
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)
signal property_inspected(property_id: StringName)
signal hand_tab_requested(tab_id: StringName)
signal hand_highlight_requested(role_id: StringName)
signal hand_highlight_cleared
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
const FIELD_CENTER := PersonaStarChart.FIELD_CENTER
const CANDIDATE_NODE_SIZE := Vector2(44, 44)
const PERSONA_ICON_SIZE := PersonaStarChart.PERSONA_ICON_SIZE
const PERSONA_RAY_LEVEL_ONE_LENGTH := PersonaStarChart.LEVEL_ONE_LENGTH
const PERSONA_RAY_FULL_LEVEL := PersonaStarChart.MAX_LEVEL
const PERSONA_ICON_POSITIONS := PersonaStarChart.PERSONA_ICON_POSITIONS
const REINFORCEMENT_SLOT_GAP := 14.0
const REINFORCEMENT_TOP_GAP := 12.0
const REINFORCEMENT_LABEL_HEIGHT := 20.0

var state: QuestGameState
var phase := Phase.DRAFT
var background_input: QuestSynthesisBackgroundInput
var draft_layer: Control
var star_chart: PersonaStarChart
var candidate_layer: Control
var base_slot_host: CenterContainer
var base_slot: QuestSynthesisMaterialSlot
var persona_slot: QuestSynthesisMaterialSlot
var helper_slot: QuestSynthesisMaterialSlot
var material_slots: Array[QuestSynthesisMaterialSlot] = []
var reinforcement_group: Control
var reinforcement_columns: Dictionary = {}
var reinforcement_labels: Dictionary = {}
var candidate_buttons: Dictionary = {}
var candidate_views: Dictionary = {}
var candidate_hover_tweens: Dictionary = {}
var persona_buttons: Dictionary = {}
var persona_value_labels: Dictionary = {}
var possibility_definitions: Dictionary = {}
var candidate_ready_tweens: Dictionary = {}
var candidate_breath_tweens: Dictionary = {}
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


func set_background_passthrough_controls(controls: Array) -> void:
	if background_input != null:
		background_input.set_passthrough_controls(controls)


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
	_update_reinforcement_visibility(snapshot)


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
	var staged := false
	if role_id == &"persona":
		staged = state.select_synthesis_persona(PersonaMaskCatalog.persona_for_card(card))
	else:
		var result := (
			state.assign_synthesis_base(card)
			if role_id == &"base"
			else state.assign_synthesis_helper(card)
		)
		staged = bool(result.ok)
	if staged:
		hand_highlight_cleared.emit()
	return staged


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
	hand_highlight_requested.emit(role_id)


func show_drop_targets_for_card(card: CardItemState) -> void:
	var is_persona := not PersonaMaskCatalog.persona_for_card(card).is_empty()
	for slot in material_slots:
		var visible_target := slot == base_slot or (
			reinforcement_group != null and reinforcement_group.visible
		)
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
	hand_highlight_cleared.emit()
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
	if reinforcement_group != null:
		reinforcement_group.visible = true


func _build_interface() -> void:
	star_chart = PersonaStarChart.new()
	star_chart.name = "PersonaStarChart"
	add_child(star_chart)
	background_input = QuestSynthesisBackgroundInput.new()
	background_input.name = "SynthesisBackgroundInput"
	background_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_input.mouse_filter = Control.MOUSE_FILTER_STOP
	background_input.gui_input.connect(_on_background_gui_input)
	add_child(background_input)
	draft_layer = Control.new()
	draft_layer.name = "SynthesisDraft"
	draft_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(draft_layer)
	_build_persona_field()
	_build_base_slot()
	_build_candidate_layer()
	_build_reinforcement_slots()
	_build_narrative_overlay()
	_build_result_layer()
	_layout_draft()


func _build_persona_field() -> void:
	for persona_id in CardPropertySet.PERSONAS:
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
	base_slot_host.add_child(base_slot)
	material_slots.append(base_slot)


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


func _build_reinforcement_slots() -> void:
	reinforcement_group = Control.new()
	reinforcement_group.name = "ReinforcementSlots"
	reinforcement_group.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reinforcement_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draft_layer.add_child(reinforcement_group)
	for role_id in [&"persona", &"helper"]:
		var slot_column := VBoxContainer.new()
		slot_column.name = "%sReinforcementColumn" % String(role_id).to_pascal_case()
		slot_column.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_column.add_theme_constant_override("separation", 6)
		slot_column.custom_minimum_size = Vector2(
			QuestTaskSlot.CARD_SIZE.x,
			QuestTaskSlot.CARD_SIZE.y + REINFORCEMENT_LABEL_HEIGHT + 6.0,
		)
		slot_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reinforcement_group.add_child(slot_column)
		reinforcement_columns[role_id] = slot_column
		var slot := QuestSynthesisMaterialSlot.new()
		slot.setup(self, role_id, null)
		slot.item_inspected.connect(item_inspected.emit)
		slot_column.add_child(slot)
		material_slots.append(slot)
		var label := Label.new()
		label.custom_minimum_size = Vector2(
			QuestTaskSlot.CARD_SIZE.x, REINFORCEMENT_LABEL_HEIGHT
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("d7d4c8"))
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.gui_input.connect(_on_reinforcement_label_gui_input.bind(role_id))
		slot_column.add_child(label)
		reinforcement_labels[role_id] = label
		if role_id == &"persona":
			persona_slot = slot
		else:
			helper_slot = slot
	reinforcement_group.visible = true


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
	result_holder.custom_minimum_size = Vector2(150, 150)
	column.add_child(result_holder)
	result_back_button = Button.new()
	result_back_button.name = "SynthesisResultBack"
	result_back_button.custom_minimum_size = CardHandCard.CARD_SIZE
	result_back_button.text = "◇\n◇\n◇"
	result_back_button.add_theme_font_size_override("font_size", 18)
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
	var total_width := QuestTaskSlot.CARD_SIZE.x * 2.0 + REINFORCEMENT_SLOT_GAP
	var first_x := FIELD_CENTER.x - total_width * 0.5
	var slots_y := (
		FIELD_CENTER.y
		+ QuestTaskSlot.CARD_SIZE.y * 0.5
		+ REINFORCEMENT_TOP_GAP
	)
	for index in range(2):
		var role_id: StringName = [&"persona", &"helper"][index]
		var column := reinforcement_columns.get(role_id) as VBoxContainer
		if column != null:
			column.position = Vector2(
				first_x + index * (QuestTaskSlot.CARD_SIZE.x + REINFORCEMENT_SLOT_GAP),
				slots_y,
			)
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


func _update_reinforcement_visibility(_snapshot: Dictionary) -> void:
	if reinforcement_group != null:
		reinforcement_group.visible = true


func _rebuild_persona_field(snapshot: Dictionary) -> void:
	_record_update(&"personas")
	var totals := snapshot.get("totals", {}) as Dictionary
	star_chart.set_totals(totals)
	for persona_id in CardPropertySet.PERSONAS:
		var amount := int(totals.get(persona_id, 0))
		(persona_value_labels[persona_id] as Label).text = str(amount)


func _persona_ray_points(persona_id: StringName, amount: int) -> PackedVector2Array:
	if star_chart == null:
		return PackedVector2Array([FIELD_CENTER, FIELD_CENTER])
	return star_chart.axis_progress_points(persona_id, float(amount))


func _rebuild_candidates(snapshot: Dictionary) -> void:
	_record_update(&"candidates")
	var candidates := snapshot.get("candidates", []) as Array
	var desired_ids: Array[StringName] = []
	var active_recipes: Array[SynthesisRecipeDefinition] = []
	for candidate in candidates:
		desired_ids.append(StringName(candidate.recipe_id))
	for raw_recipe_id in candidate_views:
		var old_recipe_id := StringName(raw_recipe_id)
		var old_view := candidate_views[raw_recipe_id] as Dictionary
		var remains_visible := desired_ids.has(old_recipe_id)
		(old_view.button as Button).visible = remains_visible
		(old_view.halo as Label).visible = remains_visible
		if not remains_visible:
			_set_candidate_breathing(old_recipe_id, old_view, false)
	for candidate in candidates:
		var recipe_id := StringName(candidate.recipe_id)
		var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
		if recipe == null:
			continue
		active_recipes.append(recipe)
		if not candidate_views.has(recipe_id):
			candidate_views[recipe_id] = _create_candidate_view(recipe)
		var view := candidate_views[recipe_id] as Dictionary
		var button := view.button as Button
		var position := _candidate_position(recipe)
		button.position = position - CANDIDATE_NODE_SIZE * 0.5
		var halo := view.halo as Label
		halo.position = button.position
		halo.visible = true
		button.visible = true
		button.disabled = false
		button.button_pressed = state.synthesis_candidate_recipe_id == recipe_id
		var was_initialized := bool(view.get("initialized", false))
		var was_complete := bool(view.get("is_complete", false))
		_apply_candidate_visual(
			recipe_id,
			view,
			bool(candidate.is_complete),
			button.button_pressed,
		)
		if bool(candidate.is_complete) and (not was_initialized or not was_complete):
			_pulse_candidate_ready(recipe_id)
		view["initialized"] = true
		view["is_complete"] = bool(candidate.is_complete)
		view["candidate"] = candidate
		view["position"] = position
	star_chart.set_candidate_recipes(active_recipes)
	_update_candidate_hover_state(&"")


func _create_candidate_view(recipe: SynthesisRecipeDefinition) -> Dictionary:
	var halo := Label.new()
	halo.name = "%sCandidateHalo" % String(recipe.id).to_pascal_case()
	halo.custom_minimum_size = CANDIDATE_NODE_SIZE
	halo.size = CANDIDATE_NODE_SIZE
	halo.pivot_offset = CANDIDATE_NODE_SIZE * 0.5
	halo.text = "◆"
	halo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	halo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	halo.add_theme_font_size_override("font_size", 39)
	halo.add_theme_color_override("font_color", Color("8ba2b7", 0.52))
	halo.add_theme_color_override("font_outline_color", Color("8ba2b7", 0.18))
	halo.add_theme_constant_override("outline_size", 5)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	candidate_layer.add_child(halo)
	var button := Button.new()
	button.name = "%sCandidate" % String(recipe.id).to_pascal_case()
	button.custom_minimum_size = CANDIDATE_NODE_SIZE
	button.size = CANDIDATE_NODE_SIZE
	button.pivot_offset = CANDIDATE_NODE_SIZE * 0.5
	button.toggle_mode = true
	button.flat = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	button.pressed.connect(_on_candidate_pressed.bind(recipe.id))
	candidate_layer.add_child(button)
	candidate_buttons[recipe.id] = button
	return {
		"halo": halo,
		"button": button,
		"candidate": {},
		"position": Vector2.ZERO,
		"initialized": false,
		"is_complete": false,
	}


func _apply_candidate_visual(
	recipe_id: StringName,
	view: Dictionary,
	is_complete: bool,
	is_selected: bool,
) -> void:
	var button := view.button as Button
	var halo := view.halo as Label
	button.text = "◆"
	button.add_theme_font_size_override("font_size", 29)
	button.add_theme_color_override(
		"font_color", Color("f4f6ed") if is_complete else Color("71869c", 0.98)
	)
	button.add_theme_color_override(
		"font_hover_color", Color("ffffff") if is_complete else Color("dce7ef")
	)
	button.add_theme_color_override("font_pressed_color", Color("f2d99a"))
	button.add_theme_color_override("font_hover_pressed_color", Color("fff2c7"))
	button.add_theme_color_override(
		"font_outline_color",
		Color("f2d99a", 0.88) if is_selected else Color("bcd1e2", 0.60),
	)
	button.add_theme_constant_override("outline_size", 5 if is_complete or is_selected else 3)
	if is_complete:
		halo.add_theme_color_override("font_color", Color("f2d99a", 0.62))
		halo.add_theme_color_override("font_outline_color", Color("fff2c7", 0.24))
		halo.modulate = Color.WHITE
		_set_candidate_breathing(recipe_id, view, false)
	else:
		halo.add_theme_color_override("font_color", Color("8ba2b7", 0.52))
		halo.add_theme_color_override("font_outline_color", Color("8ba2b7", 0.18))
		_set_candidate_breathing(recipe_id, view, true)


func _set_candidate_breathing(
	recipe_id: StringName,
	view: Dictionary,
	enabled: bool,
) -> void:
	var previous := candidate_breath_tweens.get(recipe_id) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	candidate_breath_tweens.erase(recipe_id)
	var halo := view.get("halo") as Label
	if halo == null:
		return
	halo.modulate = Color(1.0, 1.0, 1.0, 0.48 if enabled else 1.0)
	if not enabled or not halo.visible or not halo.is_inside_tree():
		return
	var breathe := halo.create_tween().set_loops()
	breathe.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(halo, "modulate:a", 0.96, 1.35)
	breathe.tween_property(halo, "modulate:a", 0.48, 1.35)
	candidate_breath_tweens[recipe_id] = breathe


func _pulse_candidate_ready(recipe_id: StringName) -> void:
	var button := candidate_buttons.get(recipe_id) as Button
	if button == null or not button.is_inside_tree():
		return
	var previous_tween := candidate_ready_tweens.get(recipe_id) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	button.scale = Vector2.ONE
	var pulse := button.create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(button, "scale", Vector2.ONE * 1.30, 0.16)
	pulse.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pulse.tween_property(button, "scale", Vector2.ONE, 0.24)
	candidate_ready_tweens[recipe_id] = pulse


func _candidate_position(
	recipe: SynthesisRecipeDefinition,
	_occupied_positions: Dictionary = {},
) -> Vector2:
	return star_chart.candidate_position(recipe) if star_chart != null else FIELD_CENTER


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
	star_chart.set_hovered_persona(persona_id)
	_update_candidate_hover_state(persona_id)


func _on_persona_unhovered(persona_id: StringName) -> void:
	var button := persona_buttons.get(persona_id) as Button
	if button != null and not button.get_global_rect().has_point(get_global_mouse_position()):
		star_chart.set_hovered_persona(&"")
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
			button.modulate = Color(0.46, 0.50, 0.55, 0.68)
			continue
		var pulse := button.create_tween().set_loops()
		pulse.tween_property(button, "modulate", Color(1.38, 1.38, 1.38, 1.0), 0.34)
		pulse.tween_property(button, "modulate", Color.WHITE, 0.34)
		candidate_hover_tweens[recipe_id] = pulse


func _on_background_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	details_cleared.emit()
	hand_highlight_cleared.emit()


func _on_reinforcement_label_gui_input(event: InputEvent, role_id: StringName) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		request_hand_tab_for_role(role_id)


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
		var button := candidate_buttons[recipe_id] as Button
		var selected: bool = state.synthesis_candidate_recipe_id == recipe_id
		button.button_pressed = selected
		var view := candidate_views.get(recipe_id) as Dictionary
		_apply_candidate_visual(
			StringName(recipe_id),
			view,
			bool(view.get("is_complete", false)),
			selected,
		)


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
		_update_reinforcement_visibility(snapshot)
	elif delta.synthesis_candidate_changed:
		_update_candidate_selection()
		_update_action_button()
	last_delta_update_usec = Time.get_ticks_usec() - started_usec
	max_delta_update_usec = maxi(max_delta_update_usec, last_delta_update_usec)


func _on_locale_changed(_locale: String) -> void:
	(reinforcement_labels[&"persona"] as Label).text = TranslationServer.translate(
		&"quest.ui.synthesis.borrow_self"
	)
	(reinforcement_labels[&"helper"] as Label).text = TranslationServer.translate(
		&"quest.ui.synthesis.borrow_item"
	)
	if phase == Phase.DRAFT:
		refresh()
