class_name QuestSynthesisMaterialSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

var controller: QuestSynthesisInterface
var card: CardItemState
var holder: CenterContainer


func setup(screen: QuestSynthesisInterface, assigned_card: CardItemState) -> void:
	controller = screen
	card = assigned_card
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(154, 174)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("050708", 0.98), Color("746448", 0.9))
	)
	holder = CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	refresh()


func refresh() -> void:
	if holder == null:
		return
	for child in get_children():
		if child != holder:
			child.free()
	for child in holder.get_children():
		child.free()
	if card == null:
		var empty := Label.new()
		empty.text = "+"
		empty.add_theme_font_size_override("font_size", 38)
		empty.add_theme_color_override("font_color", Color("687a75"))
		holder.add_child(empty)
		return
	var definition := QuestArcCatalog.item_by_id(card.definition_id)
	var view := CardHandCard.new()
	view.setup(card, definition, true)
	view.inspect_requested.connect(item_inspected.emit)
	holder.add_child(view)
	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.take_back")
	remove_button.anchor_left = 1.0
	remove_button.anchor_right = 1.0
	remove_button.offset_left = -34
	remove_button.offset_right = -4
	remove_button.offset_top = 4
	remove_button.offset_bottom = 34
	remove_button.pressed.connect(controller.remove_material.bind(card))
	add_child(remove_button)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if card != null or controller == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var dropped_card := data.get("card") as CardItemState
	return data.get("kind") == &"card_item" and controller.can_stage_card(dropped_card)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dropped_card := data.get("card") as CardItemState
	if dropped_card != null:
		controller.stage_card(dropped_card)
