class_name CardTaskSlot
extends PanelContainer

signal focused(rule: CardSlotRule)
signal drop_resolved(result: Dictionary)
signal item_inspected(definition: CardItemDefinition)

var commerce: SlotCommerceState
var activity_state: SlotActivityState
var activity_id: StringName
var rule: CardSlotRule
var title_label: Label
var rule_label: Label
var card_holder: CenterContainer
var status_label: Label


func setup(
	commerce_state: SlotCommerceState,
	selected_activity_state: SlotActivityState,
	selected_activity_id: StringName,
	selected_rule: CardSlotRule,
) -> void:
	commerce = commerce_state
	activity_state = selected_activity_state
	activity_id = selected_activity_id
	rule = selected_rule
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(172, 210)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 9)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color("d7e4de"))
	column.add_child(title_label)
	rule_label = Label.new()
	rule_label.custom_minimum_size = Vector2(0, 52)
	rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_label.add_theme_font_size_override("font_size", 11)
	rule_label.add_theme_color_override("font_color", Color("8fa49f"))
	column.add_child(rule_label)
	card_holder = CenterContainer.new()
	card_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(card_holder)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	column.add_child(status_label)
	refresh()


func refresh() -> void:
	if title_label == null or rule == null or activity_state == null:
		return
	for child in card_holder.get_children():
		child.free()
	title_label.text = (
		TranslationServer.translate(rule.display_name_key)
		if not rule.display_name_key.is_empty()
		else TranslationServer.translate(&"slot.task.single_slot")
	)
	rule_label.text = _rule_summary()
	var card := activity_state.card_for_slot(activity_id, rule.id)
	var evaluation := CardRuleEvaluator.evaluate(
		rule,
		SlotDemoCatalog.item_by_id(card.definition_id) if card != null else null,
	)
	var border := Color("536d6c")
	if card == null:
		status_label.text = TranslationServer.translate(&"slot.task.slot.empty")
		status_label.add_theme_color_override("font_color", Color("718884"))
	else:
		var view := CardHandCard.new()
		view.setup(
			card,
			SlotDemoCatalog.item_by_id(card.definition_id),
			activity_state.can_edit_activity(activity_id),
		)
		view.inspect_requested.connect(item_inspected.emit)
		card_holder.add_child(view)
		if evaluation.can_execute:
			border = Color("d2b86f")
			status_label.text = TranslationServer.translate(&"slot.task.slot.ready")
			status_label.add_theme_color_override("font_color", Color("d7c17e"))
		else:
			border = Color("7d7470")
			status_label.text = _insufficient_text(evaluation)
			status_label.add_theme_color_override("font_color", Color("bd9b83"))
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("091418", 0.98), border)
	)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"card_item":
		return false
	var card := data.get("card") as CardItemState
	if card == null or activity_state == null:
		return false
	if not activity_state.can_edit_activity(activity_id):
		return false
	var occupied := activity_state.card_for_slot(activity_id, rule.id)
	if occupied != null and occupied != card:
		return false
	var definition := SlotDemoCatalog.item_by_id(card.definition_id)
	return CardRuleEvaluator.evaluate(rule, definition).can_place


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	var result := activity_state.assign_card(activity_id, rule.id, card)
	drop_resolved.emit(result)
	focused.emit(rule)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		focused.emit(rule)


func _rule_summary() -> String:
	var lines := PackedStringArray()
	if not rule.required_all.is_empty():
		lines.append(TranslationServer.translate(&"slot.rule.required") % _tag_list(rule.required_all))
	if not rule.allowed_any.is_empty():
		lines.append(TranslationServer.translate(&"slot.rule.allowed") % _tag_list(rule.allowed_any))
	if not rule.forbidden_any.is_empty():
		lines.append(TranslationServer.translate(&"slot.rule.forbidden") % _tag_list(rule.forbidden_any))
	for raw_requirement in rule.value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement != null:
			lines.append(TranslationServer.translate(&"slot.rule.minimum") % [
				_tag_list(requirement.tags), requirement.minimum,
			])
	return "\n".join(lines)


func _tag_list(tags: Array[StringName]) -> String:
	var names := PackedStringArray()
	for tag in tags:
		var prefix := "slot.aspect" if tag in CardPropertySet.ASPECTS else "slot.property"
		names.append(TranslationServer.translate(StringName("%s.%s" % [prefix, tag])))
	return " / ".join(names)


func _insufficient_text(evaluation: Dictionary) -> String:
	if evaluation.insufficient_values.is_empty():
		return TranslationServer.translate(&"slot.task.slot.blocked")
	var shortage: Dictionary = evaluation.insufficient_values[0]
	return TranslationServer.translate(&"slot.task.slot.insufficient") % [
		int(shortage.minimum) - int(shortage.actual),
	]
