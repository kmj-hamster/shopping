class_name QuestRuleDetailPopup
extends Control

var current_rule: CardSlotRule
var current_task_definition: TaskDefinition
var title_label: Label
var required_row: HBoxContainer
var bonus_section: VBoxContainer
var bonus_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 110

	var panel := PanelContainer.new()
	panel.name = "RuleDetailPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -388
	panel.offset_top = 62
	panel.offset_right = -28
	panel.offset_bottom = 246
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("050708", 0.985), Color("9b8757", 0.94))
	)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 11)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color("e3c679"))
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(30, 28)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var must_label := Label.new()
	must_label.name = "RequiredHeading"
	must_label.add_theme_font_size_override("font_size", 12)
	must_label.add_theme_color_override("font_color", Color("81958f"))
	column.add_child(must_label)
	required_row = HBoxContainer.new()
	required_row.name = "RequiredItems"
	required_row.add_theme_constant_override("separation", 7)
	column.add_child(required_row)

	bonus_section = VBoxContainer.new()
	bonus_section.add_theme_constant_override("separation", 4)
	column.add_child(bonus_section)
	var bonus_label := Label.new()
	bonus_label.name = "BonusHeading"
	bonus_label.add_theme_font_size_override("font_size", 12)
	bonus_label.add_theme_color_override("font_color", Color("81958f"))
	bonus_section.add_child(bonus_label)
	bonus_row = HBoxContainer.new()
	bonus_row.name = "BonusItems"
	bonus_row.add_theme_constant_override("separation", 7)
	bonus_section.add_child(bonus_row)

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
	chip.add_theme_constant_override("separation", 5)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(36, 36)
	image.texture = definition.image
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(image)
	var label := Label.new()
	label.text = definition.localized_name()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("d9d0b4"))
	chip.add_child(label)
	required_row.add_child(chip)


func _add_property_requirement(row: HBoxContainer, property_id: StringName) -> void:
	var property := QuestArcCatalog.property_by_id(property_id)
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.text = "%s  %s" % [
		_property_symbol(property_id),
		TranslationServer.translate(
			property.display_name_key
			if property != null
			else StringName("slot.property.%s" % property_id)
		),
	]
	chip.add_theme_color_override("font_color", _property_color(property_id))
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


func _property_symbol(property_id: StringName) -> String:
	var symbols := {
		&"food": "●",
		&"salty": "≋",
		&"plant": "♧",
		&"drink": "∪",
		&"metal": "◆",
		&"tool": "×",
		&"lamp": "✦",
		&"mirror": "◇",
	}
	return String(symbols.get(property_id, "·"))


func _property_color(property_id: StringName) -> Color:
	var hue := float(absi(String(property_id).hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.38, 0.88)


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh()
