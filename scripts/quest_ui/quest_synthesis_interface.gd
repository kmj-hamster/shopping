class_name QuestSynthesisInterface
extends Control

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var head_button: TextureButton
var panel: PanelContainer
var title_label: Label
var recipe_tabs: HBoxContainer
var aspect_row: HBoxContainer
var slots_row: HBoxContainer
var preview_label: Label
var progress_bar: ProgressBar
var action_button: Button
var refresh_queued := false


func setup(game_state: QuestGameState) -> void:
	state = game_state
	if state != null and not state.state_changed.is_connected(_queue_refresh):
		state.state_changed.connect(_queue_refresh)
	if is_node_ready():
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	_build_head_button()
	_build_panel()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	set_process(state != null and state.active_synthesis != null)
	refresh()


func _process(delta: float) -> void:
	if state == null or state.active_synthesis == null:
		set_process(false)
		return
	var result := state.advance_synthesis(delta)
	if result.get("completed", false):
		preview_label.text = TranslationServer.translate(StringName(result.preview_key))
		set_process(false)
		refresh()
	elif progress_bar != null:
		progress_bar.value = float(result.get("progress", 0.0)) * 100.0


func refresh() -> void:
	if state == null or panel == null:
		return
	for child in aspect_row.get_children():
		child.free()
	for aspect in CardPropertySet.ASPECTS:
		var badge := Label.new()
		badge.text = "%s  %d" % [
			_aspect_symbol(aspect), int(state.protagonist_aspect_counts.get(aspect, 0))
		]
		badge.tooltip_text = TranslationServer.translate(
			QuestArcCatalog.property_by_id(aspect).description_key
		)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", _aspect_color(aspect))
		aspect_row.add_child(badge)
	for child in recipe_tabs.get_children():
		child.free()
	var available_recipes := state.available_synthesis_recipe_ids()
	if state.synthesis_recipe_id not in available_recipes and not available_recipes.is_empty():
		state.select_synthesis_recipe(available_recipes[0])
	for recipe_id in available_recipes:
		var option := QuestArcCatalog.recipe_by_id(recipe_id)
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(48, 32)
		tab.toggle_mode = true
		tab.button_pressed = recipe_id == state.synthesis_recipe_id
		tab.disabled = state.active_synthesis != null
		tab.text = (
			TranslationServer.translate(option.display_name_key)
			if state.discovered_recipe_ids.has(recipe_id) or not option.hidden_until_preview
			else "◇"
		)
		tab.tooltip_text = (
			TranslationServer.translate(&"quest.ui.synthesis.known_hint")
			if state.known_recipe_hint_ids.has(recipe_id)
			else TranslationServer.translate(&"quest.ui.synthesis.unknown_hint")
		)
		tab.pressed.connect(_on_recipe_selected.bind(recipe_id))
		recipe_tabs.add_child(tab)
	var recipe := QuestArcCatalog.recipe_by_id(state.synthesis_recipe_id)
	if recipe == null:
		return
	title_label.text = (
		TranslationServer.translate(recipe.display_name_key)
		if state.discovered_recipe_ids.has(recipe.id) or not recipe.hidden_until_preview
		else TranslationServer.translate(&"quest.ui.synthesis.unknown")
	)
	for child in slots_row.get_children():
		child.free()
	for raw_rule in recipe.slot_rules:
		var slot := QuestSynthesisSlot.new()
		slot.setup(state, raw_rule as CardSlotRule)
		slot.rule_focused.connect(rule_focused.emit)
		slot.item_inspected.connect(item_inspected.emit)
		slots_row.add_child(slot)
	var evaluation := state.synthesis_evaluation()
	if state.active_synthesis != null:
		preview_label.text = TranslationServer.translate(&"quest.ui.synthesis.working")
		progress_bar.visible = true
		progress_bar.value = state.active_synthesis.progress_ratio() * 100.0
		action_button.disabled = true
		set_process(true)
	else:
		progress_bar.visible = false
		action_button.disabled = not evaluation.is_complete
		if evaluation.is_complete:
			preview_label.text = "%s\n%s" % [
				QuestArcCatalog.item_by_id(StringName(evaluation.output_id)).localized_name(),
				TranslationServer.translate(StringName(evaluation.preview_key)),
			]
		else:
			preview_label.text = TranslationServer.translate(&"quest.ui.synthesis.hint")
	action_button.text = TranslationServer.translate(&"quest.ui.synthesis.action")


func close_panel() -> void:
	panel.visible = false
	rule_focused.emit(null)


func _build_head_button() -> void:
	head_button = TextureButton.new()
	head_button.name = "ProtagonistHeadButton"
	head_button.texture_normal = load("res://resources/character/bag.png") as Texture2D
	head_button.texture_hover = load("res://resources/character/bag-light.png") as Texture2D
	head_button.ignore_texture_size = true
	head_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	head_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	head_button.offset_left = -132
	head_button.offset_top = -142
	head_button.offset_right = -4
	head_button.offset_bottom = 0
	head_button.mouse_filter = Control.MOUSE_FILTER_STOP
	head_button.tooltip_text = TranslationServer.translate(&"quest.ui.synthesis.open")
	head_button.pressed.connect(_toggle_panel)
	add_child(head_button)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "SynthesisPanel"
	panel.position = Vector2(630, 88)
	panel.size = Vector2(610, 490)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("020507", 0.99), Color("8a7651", 0.94))
	)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = TranslationServer.translate(&"quest.ui.synthesis.title")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", Color("d8c48d"))
	header.add_child(heading)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	aspect_row = HBoxContainer.new()
	aspect_row.add_theme_constant_override("separation", 18)
	column.add_child(aspect_row)
	var divider := HSeparator.new()
	column.add_child(divider)
	recipe_tabs = HBoxContainer.new()
	recipe_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	recipe_tabs.add_theme_constant_override("separation", 8)
	column.add_child(recipe_tabs)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("a8bbb3"))
	column.add_child(title_label)
	slots_row = HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 10)
	column.add_child(slots_row)
	preview_label = Label.new()
	preview_label.custom_minimum_size = Vector2(0, 62)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_color_override("font_color", Color("c8b987"))
	column.add_child(preview_label)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 8)
	column.add_child(progress_bar)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(170, 40)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.pressed.connect(_on_action_pressed)
	column.add_child(action_button)


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if not panel.visible:
		rule_focused.emit(null)
	else:
		refresh()


func _on_action_pressed() -> void:
	var result := state.begin_synthesis()
	if result.ok:
		preview_label.text = TranslationServer.translate(StringName(result.preview_key))
		set_process(true)
		rule_focused.emit(null)
	refresh()


func _on_recipe_selected(recipe_id: StringName) -> void:
	if state.select_synthesis_recipe(recipe_id):
		rule_focused.emit(null)
	refresh()


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	refresh()


func _on_locale_changed(_locale: String) -> void:
	head_button.tooltip_text = TranslationServer.translate(&"quest.ui.synthesis.open")
	refresh()


func _aspect_symbol(aspect: StringName) -> String:
	return String({&"lamp": "✦", &"mirror": "◇", &"candle": "∿", &"pillow": "⌒"}.get(aspect, "·"))


func _aspect_color(aspect: StringName) -> Color:
	return {
		&"lamp": Color("e4c34f"),
		&"mirror": Color("70aeca"),
		&"candle": Color("a37ac5"),
		&"pillow": Color("ca88a5"),
	}.get(aspect, Color.WHITE)
