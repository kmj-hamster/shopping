class_name QuestSynthesisMaterialSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

const SLOT_SIZE := Vector2(117, 176)

var controller: QuestSynthesisInterface
var role_id: StringName
var card: CardItemState
var holder: CenterContainer


func setup(
	screen: QuestSynthesisInterface,
	selected_role_id: StringName,
	assigned_card: CardItemState,
) -> void:
	controller = screen
	role_id = selected_role_id
	card = assigned_card
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiPalette.panel_style(Color("050708", 0.90), Color("8a7752", 0.88))
	for corner in [
		"corner_radius_top_left",
		"corner_radius_top_right",
		"corner_radius_bottom_left",
		"corner_radius_bottom_right",
	]:
		style.set(corner, 58)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	holder = CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_left = 12
	holder.offset_top = 12
	holder.offset_right = -12
	holder.offset_bottom = -12
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
		empty.add_theme_font_size_override("font_size", 42)
		empty.add_theme_color_override("font_color", Color("6f827d"))
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
	remove_button.offset_left = -38
	remove_button.offset_right = -7
	remove_button.offset_top = 7
	remove_button.offset_bottom = 38
	remove_button.z_index = 4
	remove_button.pressed.connect(controller.remove_material.bind(role_id, card))
	add_child(remove_button)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if card != null or controller == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var dropped_card := data.get("card") as CardItemState
	return (
		data.get("kind") == &"card_item"
		and controller.can_stage_card(role_id, dropped_card)
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dropped_card := data.get("card") as CardItemState
	if dropped_card != null:
		controller.stage_card(role_id, dropped_card)
