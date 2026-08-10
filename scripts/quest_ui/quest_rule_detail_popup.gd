class_name QuestRuleDetailPopup
extends Control

var current_rule: CardSlotRule
var current_task_definition: TaskDefinition
var panel: PanelContainer
var title_label: Label
var required_row: HBoxContainer
var bonus_section: VBoxContainer
var bonus_row: HBoxContainer
var property_panel: PanelContainer
var property_icon_image: TextureRect
var property_icon_fallback: Label
var property_name: Label
var property_description: Label
var selected_property_id: StringName
var property_buttons: Dictionary = {}
var requirement_views: Dictionary = {}
var requirement_occurrences: Dictionary = {}
var requirement_row_positions: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 110
	panel = PanelContainer.new()
	panel.name = "RuleDetailPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = ItemDetailPopup.DETAIL_LEFT
	panel.offset_top = ItemDetailPopup.DETAIL_TOP
	panel.offset_right = ItemDetailPopup.DETAIL_RIGHT
	panel.offset_bottom = ItemDetailPopup.DETAIL_BOTTOM
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		ItemDetailPopup.panel_style(
			ItemDetailPopup.POPUP_BACKGROUND, Color("a58d58", 0.94), 1
		),
	)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 7)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 22)
	column.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.max_lines_visible = 1
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color("e3c679"))
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(24, 22)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("a58d58", 0.90)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)

	var must_label := Label.new()
	must_label.name = "RequiredHeading"
	must_label.custom_minimum_size = Vector2(0, 13)
	must_label.add_theme_font_size_override("font_size", 11)
	must_label.add_theme_color_override("font_color", Color("9eb0aa"))
	column.add_child(must_label)
	var required_scroll := ScrollContainer.new()
	required_scroll.custom_minimum_size = Vector2(0, 30)
	required_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	required_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(required_scroll)
	required_row = HBoxContainer.new()
	required_row.name = "RequiredItems"
	required_row.custom_minimum_size = Vector2(0, 30)
	required_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	required_row.add_theme_constant_override("separation", 9)
	required_scroll.add_child(required_row)

	bonus_section = VBoxContainer.new()
	bonus_section.add_theme_constant_override("separation", 3)
	column.add_child(bonus_section)
	var bonus_label := Label.new()
	bonus_label.name = "BonusHeading"
	bonus_label.custom_minimum_size = Vector2(0, 13)
	bonus_label.add_theme_font_size_override("font_size", 11)
	bonus_label.add_theme_color_override("font_color", Color("9eb0aa"))
	bonus_section.add_child(bonus_label)
	var bonus_scroll := ScrollContainer.new()
	bonus_scroll.custom_minimum_size = Vector2(0, 30)
	bonus_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	bonus_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bonus_section.add_child(bonus_scroll)
	bonus_row = HBoxContainer.new()
	bonus_row.name = "BonusItems"
	bonus_row.custom_minimum_size = Vector2(0, 30)
	bonus_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bonus_row.add_theme_constant_override("separation", 9)
	bonus_scroll.add_child(bonus_row)

	_build_property_panel()
	must_label.text = TranslationServer.translate(&"demo.ui.rule.must")
	bonus_label.text = TranslationServer.translate(&"demo.ui.rule.bonus")
	LocaleManager.locale_changed.connect(_on_locale_changed)
	visible = false


func _input(event: InputEvent) -> void:
	if not visible or event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if panel.get_global_rect().has_point(mouse_event.position):
		return
	if property_panel.visible and property_panel.get_global_rect().has_point(mouse_event.position):
		return
	close()


func show_rule(rule: CardSlotRule, task_definition: TaskDefinition = null) -> void:
	if rule == null:
		close()
		return
	current_rule = rule
	current_task_definition = task_definition
	selected_property_id = &""
	property_panel.visible = false
	visible = true
	_refresh()


func close() -> void:
	visible = false
	current_rule = null
	current_task_definition = null
	selected_property_id = &""
	if property_panel != null:
		property_panel.visible = false
	_update_property_button_states()


func _refresh() -> void:
	if current_rule == null or title_label == null:
		return
	var owner_request := (
		current_task_definition != null
		and current_task_definition.category == TaskDefinition.Category.OWNER_REQUEST
	)
	title_label.text = TranslationServer.translate(
		current_rule.display_name_key if owner_request else &"demo.ui.rule.title"
	)
	title_label.add_theme_font_size_override("font_size", 12 if owner_request else 17)
	title_label.tooltip_text = title_label.text if owner_request else ""
	var required_heading := find_child("RequiredHeading", true, false) as Label
	var bonus_heading := find_child("BonusHeading", true, false) as Label
	required_heading.text = TranslationServer.translate(&"demo.ui.rule.must")
	bonus_heading.text = TranslationServer.translate(&"demo.ui.rule.bonus")
	_hide_requirement_views()
	property_buttons.clear()
	requirement_occurrences.clear()
	requirement_row_positions = {&"required": 0, &"bonus": 0}
	for item_id in current_rule.accepted_item_ids:
		_add_item_requirement(item_id)
	for property_id in current_rule.required_all:
		_add_property_requirement(required_row, property_id)
	for property_id in current_rule.allowed_any:
		_add_property_requirement(required_row, property_id)
	_add_bonus_requirements()
	bonus_section.visible = int(requirement_row_positions.get(&"bonus", 0)) > 0
	if property_panel.visible and not selected_property_id.is_empty():
		_update_property_panel_content(selected_property_id)
	_update_property_button_states()


func _add_item_requirement(item_id: StringName) -> void:
	var definition := QuestArcCatalog.item_by_id(item_id)
	if definition == null:
		return
	var key := _next_requirement_key(&"required", &"item", item_id)
	var view: Dictionary = requirement_views.get(key, {})
	if view.is_empty():
		var chip := HBoxContainer.new()
		chip.custom_minimum_size = Vector2(0, 30)
		chip.add_theme_constant_override("separation", 6)
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(30, 30)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.add_theme_stylebox_override(
			"panel", ItemDetailPopup.panel_style(Color("f1eee5"), Color("8c7a52"), 1)
		)
		chip.add_child(frame)
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(26, 26)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(image)
		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("d9d0b4"))
		chip.add_child(label)
		required_row.add_child(chip)
		view = {"root": chip, "image": image, "label": label}
		requirement_views[key] = view
	(view.image as TextureRect).texture = definition.image
	(view.label as Label).text = definition.localized_name()
	_show_requirement_view(key, required_row)


func _add_property_requirement(row: HBoxContainer, property_id: StringName) -> StringName:
	var property := QuestArcCatalog.property_by_id(property_id)
	var section := &"bonus" if row == bonus_row else &"required"
	var key := _next_requirement_key(section, &"property", property_id)
	var view: Dictionary = requirement_views.get(key, {})
	if view.is_empty():
		var chip := HBoxContainer.new()
		chip.custom_minimum_size = Vector2(0, 30)
		chip.add_theme_constant_override("separation", 6)
		var icon := ItemDetailPopup.make_property_icon_button(property_id, 30)
		icon.pressed.connect(_show_property.bind(property_id))
		chip.add_child(icon)
		var label := Label.new()
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("d9d0b4"))
		chip.add_child(label)
		row.add_child(chip)
		view = {"root": chip, "button": icon, "label": label}
		requirement_views[key] = view
	var icon := view.button as Button
	icon.tooltip_text = TranslationServer.translate(ItemDetailPopup.property_name_key(property_id))
	_register_property_button(property_id, icon)
	(view.label as Label).text = TranslationServer.translate(
		property.display_name_key
		if property != null
		else ItemDetailPopup.property_name_key(property_id)
	)
	_show_requirement_view(key, row)
	return key


func _next_requirement_key(
	section: StringName,
	kind: StringName,
	definition_id: StringName,
) -> StringName:
	var base := StringName("%s:%s:%s" % [section, kind, definition_id])
	var occurrence := int(requirement_occurrences.get(base, 0))
	requirement_occurrences[base] = occurrence + 1
	return StringName("%s:%d" % [base, occurrence])


func _show_requirement_view(key: StringName, row: HBoxContainer) -> void:
	var view := requirement_views[key] as Dictionary
	var root := view.root as Control
	root.visible = true
	var section := &"bonus" if row == bonus_row else &"required"
	var position := int(requirement_row_positions.get(section, 0))
	if root.get_index() != position:
		row.move_child(root, position)
	requirement_row_positions[section] = position + 1


func _hide_requirement_views() -> void:
	for raw_view in requirement_views.values():
		var view := raw_view as Dictionary
		(view.root as Control).visible = false


func _register_property_button(property_id: StringName, button: Button) -> void:
	var buttons := property_buttons.get(property_id, []) as Array
	buttons.append(button)
	property_buttons[property_id] = buttons


func _show_property(property_id: StringName) -> void:
	if property_panel.visible and selected_property_id == property_id:
		_hide_property_panel()
		return
	selected_property_id = property_id
	_update_property_panel_content(property_id)
	property_panel.visible = true
	_position_property_panel()
	_update_property_button_states()


func _update_property_panel_content(property_id: StringName) -> void:
	var texture := ItemDetailPopup.property_icon_texture(property_id)
	property_icon_image.texture = texture
	property_icon_image.visible = texture != null
	property_icon_fallback.text = ItemDetailPopup.property_symbol(property_id)
	property_icon_fallback.visible = texture == null
	property_name.text = TranslationServer.translate(ItemDetailPopup.property_name_key(property_id))
	property_description.text = TranslationServer.translate(
		ItemDetailPopup.property_description_key(property_id)
	)


func _hide_property_panel() -> void:
	selected_property_id = &""
	property_panel.visible = false
	_update_property_button_states()


func _update_property_button_states() -> void:
	for raw_property_id in property_buttons:
		var property_id := StringName(raw_property_id)
		var buttons := property_buttons[raw_property_id] as Array
		for raw_button in buttons:
			var button := raw_button as Button
			if button != null:
				button.button_pressed = property_panel != null and property_panel.visible and selected_property_id == property_id


func _build_property_panel() -> void:
	property_panel = PanelContainer.new()
	property_panel.name = "RulePropertyDetailPanel"
	property_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	property_panel.offset_left = ItemDetailPopup.DETAIL_LEFT
	property_panel.offset_top = ItemDetailPopup.DETAIL_BOTTOM + ItemDetailPopup.PROPERTY_GAP
	property_panel.offset_right = ItemDetailPopup.DETAIL_RIGHT
	property_panel.offset_bottom = (
		ItemDetailPopup.DETAIL_BOTTOM
		+ ItemDetailPopup.PROPERTY_GAP
		+ ItemDetailPopup.PROPERTY_HEIGHT
	)
	property_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	property_panel.add_theme_stylebox_override(
		"panel",
		ItemDetailPopup.panel_style(
			ItemDetailPopup.POPUP_BACKGROUND, Color("a58d58", 0.94), 1
		),
	)
	add_child(property_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 9)
	property_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	margin.add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(78, 78)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_frame.add_theme_stylebox_override(
		"panel", ItemDetailPopup.panel_style(Color("f1eee5"), Color("a58d58"), 1)
	)
	row.add_child(icon_frame)
	var icon_stack := Control.new()
	icon_stack.custom_minimum_size = Vector2(76, 76)
	icon_frame.add_child(icon_stack)
	property_icon_image = TextureRect.new()
	property_icon_image.anchor_right = 1.0
	property_icon_image.anchor_bottom = 1.0
	property_icon_image.offset_left = 9.0
	property_icon_image.offset_top = 9.0
	property_icon_image.offset_right = -9.0
	property_icon_image.offset_bottom = -9.0
	property_icon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	property_icon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	property_icon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(property_icon_image)
	property_icon_fallback = Label.new()
	property_icon_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	property_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	property_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	property_icon_fallback.add_theme_font_size_override("font_size", 32)
	property_icon_fallback.add_theme_color_override("font_color", Color("141718"))
	property_icon_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(property_icon_fallback)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	row.add_child(text_column)
	property_name = Label.new()
	property_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	property_name.add_theme_font_size_override("font_size", 16)
	property_name.add_theme_color_override("font_color", Color("e3c679"))
	text_column.add_child(property_name)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("a58d58", 0.90)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(divider)
	property_description = Label.new()
	property_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	property_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	property_description.max_lines_visible = 3
	property_description.add_theme_font_size_override("font_size", 11)
	property_description.add_theme_color_override("font_color", Color("d8ddd9"))
	text_column.add_child(property_description)
	property_panel.visible = false
	_position_property_panel()


func _position_property_panel() -> void:
	if panel == null or property_panel == null:
		return
	var panel_height := maxf(panel.size.y, panel.get_combined_minimum_size().y)
	var property_height := maxf(
		ItemDetailPopup.PROPERTY_HEIGHT,
		property_panel.get_combined_minimum_size().y,
	)
	var property_top := panel.offset_top + panel_height + ItemDetailPopup.PROPERTY_GAP
	property_panel.offset_top = property_top
	property_panel.offset_bottom = property_top + property_height


func _add_bonus_requirements() -> void:
	if current_task_definition == null:
		return
	var fallback_money := 0
	for raw_outcome in current_task_definition.outcomes:
		var outcome := raw_outcome as TaskOutcomeDefinition
		if outcome != null and outcome.is_fallback:
			fallback_money = _outcome_money(outcome)
	for raw_outcome in current_task_definition.outcomes:
		var outcome := raw_outcome as TaskOutcomeDefinition
		if outcome == null or outcome.is_fallback:
			continue
		var extra_money := _outcome_money(outcome) - fallback_money
		if extra_money <= 0:
			continue
		for raw_condition in outcome.conditions:
			var condition := raw_condition as StoryCondition
			if condition == null or condition.kind != StoryCondition.Kind.ITEM_HAS_PROPERTY:
				continue
			var property_key := _add_property_requirement(bonus_row, condition.key)
			var reward_key := StringName("%s:reward" % property_key)
			var reward_view: Dictionary = requirement_views.get(reward_key, {})
			if reward_view.is_empty():
				var reward := Label.new()
				reward.custom_minimum_size = Vector2(0, 30)
				reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				reward.add_theme_color_override("font_color", Color("e3c679"))
				bonus_row.add_child(reward)
				reward_view = {"root": reward, "label": reward}
				requirement_views[reward_key] = reward_view
			(reward_view.label as Label).text = (
				TranslationServer.translate(&"demo.ui.rule.extra_money") % extra_money
			)
			_show_requirement_view(reward_key, bonus_row)


func _outcome_money(outcome: TaskOutcomeDefinition) -> int:
	var amount := 0
	for raw_effect in outcome.effects:
		var effect := raw_effect as StoryEffect
		if effect != null and effect.kind == StoryEffect.Kind.ADD_MONEY:
			amount += effect.amount
	return amount


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh()
