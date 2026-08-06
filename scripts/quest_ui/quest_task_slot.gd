class_name QuestTaskSlot
extends PanelContainer

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var task: TaskInstanceState
var rule: CardSlotRule
var card_holder: CenterContainer
var caption_label: Label
var evaluation_label: Label


func setup(
	game_state: QuestGameState,
	task_instance: TaskInstanceState,
	slot_rule: CardSlotRule,
) -> void:
	state = game_state
	task = task_instance
	rule = slot_rule
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(190, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("0b1519", 0.97), Color("657b76", 0.82))
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	caption_label = Label.new()
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_font_size_override("font_size", 13)
	caption_label.add_theme_color_override("font_color", Color("b9c8c2"))
	column.add_child(caption_label)
	card_holder = CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(172, 94)
	card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(card_holder)
	evaluation_label = Label.new()
	evaluation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evaluation_label.add_theme_font_size_override("font_size", 11)
	column.add_child(evaluation_label)
	gui_input.connect(_on_gui_input)
	refresh()


func refresh() -> void:
	if rule == null or card_holder == null:
		return
	caption_label.text = TranslationServer.translate(rule.display_name_key)
	for child in card_holder.get_children():
		child.free()
	var card := state.card_by_instance_id(task.assigned_instance_id(rule.id))
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	var evaluation := CardRuleEvaluator.evaluate(rule, item)
	if card != null and item != null:
		var view := CardHandCard.new()
		view.setup(card, item, not task.confirmed)
		view.inspect_requested.connect(item_inspected.emit)
		card_holder.add_child(view)
		evaluation_label.text = TranslationServer.translate(
			&"quest.ui.task.slot.ready" if evaluation.can_execute else &"quest.ui.task.slot.weak"
		)
		evaluation_label.add_theme_color_override(
			"font_color", Color("91c5a9") if evaluation.can_execute else Color("d5aa6d")
		)
	else:
		var empty := Label.new()
		empty.text = "◇"
		empty.add_theme_font_size_override("font_size", 34)
		empty.add_theme_color_override("font_color", Color("657873"))
		card_holder.add_child(empty)
		evaluation_label.text = ""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or task == null or task.confirmed or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	return (
		data.get("kind") == &"card_item"
		and card != null
		and card in state.inventory
		and CardRuleEvaluator.evaluate(rule, item).can_place
		and task.assigned_instance_id(rule.id) in [0, card.instance_id]
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null:
		state.assign_card(task.instance_id, rule.id, card)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		rule_focused.emit(null if task.confirmed else rule)
