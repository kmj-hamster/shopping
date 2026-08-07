class_name QuestRuleDetailPopup
extends Control

var current_rule: CardSlotRule
var current_task_definition: TaskDefinition
var panel: PanelContainer
var title_label: Label
var required_row: HBoxContainer
var bonus_section: VBoxContainer
var bonus_row: HBoxContainer


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
		ItemDetailPopup.panel_style(Color("020304", 0.998), Color("a58d58", 0.94), 1),
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

	must_label.text = TranslationServer.translate(&"demo.ui.rule.must")
	bonus_label.text = TranslationServer.translate(&"demo.ui.rule.bonus")
	LocaleManager.locale_changed.connect(_on_locale_changed)
	visible = false


func show_rule(rule: CardSlotRule, task_definition: TaskDefinition = null) -> void:
	if rule == null:
		close()
		return
	current_rule = rule
	current_task_definition = task_definition
	visible = true
	_refresh()


func close() -> void:
	visible = false
	current_rule = null
	current_task_definition = null


func _refresh() -> void:
	if current_rule == null or title_label == null:
		return
	title_label.text = TranslationServer.translate(&"demo.ui.rule.title")
	var required_heading := find_child("RequiredHeading", true, false) as Label
	var bonus_heading := find_child("BonusHeading", true, false) as Label
	required_heading.text = TranslationServer.translate(&"demo.ui.rule.must")
	bonus_heading.text = TranslationServer.translate(&"demo.ui.rule.bonus")
	_clear_row(required_row)
	_clear_row(bonus_row)
	for item_id in current_rule.accepted_item_ids:
		_add_item_requirement(item_id)
	for property_id in current_rule.required_all:
		_add_property_requirement(required_row, property_id)
	for property_id in current_rule.allowed_any:
		_add_property_requirement(required_row, property_id)
	_add_bonus_requirements()
	bonus_section.visible = bonus_row.get_child_count() > 0


func _add_item_requirement(item_id: StringName) -> void:
	var definition := QuestArcCatalog.item_by_id(item_id)
	if definition == null:
		return
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
	image.texture = definition.image
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	var label := Label.new()
	label.text = definition.localized_name()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("d9d0b4"))
	chip.add_child(label)
	required_row.add_child(chip)


func _add_property_requirement(row: HBoxContainer, property_id: StringName) -> void:
	var property := QuestArcCatalog.property_by_id(property_id)
	var chip := HBoxContainer.new()
	chip.custom_minimum_size = Vector2(0, 30)
	chip.add_theme_constant_override("separation", 6)
	var icon := ItemDetailPopup.make_property_icon_button(property_id, 30)
	icon.toggle_mode = false
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var label := Label.new()
	label.text = TranslationServer.translate(
		property.display_name_key
		if property != null
		else ItemDetailPopup.property_name_key(property_id)
	)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("d9d0b4"))
	chip.add_child(label)
	row.add_child(chip)


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
			_add_property_requirement(bonus_row, condition.key)
			var reward := Label.new()
			reward.text = TranslationServer.translate(&"demo.ui.rule.extra_money") % extra_money
			reward.custom_minimum_size = Vector2(0, 30)
			reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			reward.add_theme_color_override("font_color", Color("e3c679"))
			bonus_row.add_child(reward)


func _outcome_money(outcome: TaskOutcomeDefinition) -> int:
	var amount := 0
	for raw_effect in outcome.effects:
		var effect := raw_effect as StoryEffect
		if effect != null and effect.kind == StoryEffect.Kind.ADD_MONEY:
			amount += effect.amount
	return amount


func _clear_row(row: HBoxContainer) -> void:
	for child in row.get_children():
		child.free()


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh()
