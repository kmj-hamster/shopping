class_name QuestSynthesisSlot
extends PanelContainer

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var rule: CardSlotRule
var card_holder: CenterContainer
var caption_label: Label


func setup(game_state: QuestGameState, slot_rule: CardSlotRule) -> void:
	state = game_state
	rule = slot_rule
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(164, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("080d10", 0.98), Color("725f4c", 0.9))
	)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	caption_label = Label.new()
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_font_size_override("font_size", 12)
	caption_label.add_theme_color_override("font_color", Color("c7b98f"))
	column.add_child(caption_label)
	card_holder = CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(150, 100)
	column.add_child(card_holder)
	gui_input.connect(_on_gui_input)
	refresh()


func refresh() -> void:
	if state == null or rule == null or card_holder == null:
		return
	caption_label.text = TranslationServer.translate(rule.display_name_key)
	for child in card_holder.get_children():
		child.free()
	var card := state.card_by_instance_id(int(state.synthesis_assignments.get(rule.id, 0)))
	if card != null:
		var definition := QuestArcCatalog.item_by_id(card.definition_id)
		var view := CardHandCard.new()
		view.setup(card, definition, state.active_synthesis == null)
		view.inspect_requested.connect(item_inspected.emit)
		view.custom_minimum_size = Vector2(142, 88)
		card_holder.add_child(view)
	else:
		var empty := Label.new()
		empty.text = "◇"
		empty.add_theme_font_size_override("font_size", 34)
		empty.add_theme_color_override("font_color", Color("6c6258"))
		card_holder.add_child(empty)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or state.active_synthesis != null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	return (
		data.get("kind") == &"card_item"
		and card != null
		and card in state.inventory
		and CardRuleEvaluator.evaluate(rule, item).can_place
		and int(state.synthesis_assignments.get(rule.id, 0)) in [0, card.instance_id]
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null:
		state.assign_synthesis_card(rule.id, card)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		rule_focused.emit(rule if state.active_synthesis == null else null)
