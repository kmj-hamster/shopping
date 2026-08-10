class_name QuestSynthesisMaterialSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

const SLOT_SIZE := Vector2(117, 176)

var controller: QuestSynthesisInterface
var role_id: StringName
var card: CardItemState
var holder: CenterContainer
var empty_label: Label
var card_view: CardHandCard
var remove_button: Button


func setup(
	screen: QuestSynthesisInterface,
	selected_role_id: StringName,
	assigned_card: CardItemState,
	force_refresh: bool = false,
) -> void:
	controller = screen
	role_id = selected_role_id
	if card == assigned_card and is_node_ready():
		if force_refresh:
			refresh()
		return
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
	empty_label = Label.new()
	empty_label.text = "+"
	empty_label.add_theme_font_size_override("font_size", 42)
	empty_label.add_theme_color_override("font_color", Color("6f827d"))
	holder.add_child(empty_label)
	# Build the reusable card presentation once. Placing/removing materials only
	# rebinds and toggles this view; it never allocates nodes in the drop path.
	card_view = CardHandCard.new()
	card_view.inspect_requested.connect(item_inspected.emit)
	holder.add_child(card_view)
	card_view.visible = false
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remove_button = Button.new()
	remove_button.text = "×"
	remove_button.anchor_left = 1.0
	remove_button.anchor_right = 1.0
	remove_button.offset_left = -38
	remove_button.offset_right = -7
	remove_button.offset_top = 7
	remove_button.offset_bottom = 38
	remove_button.z_index = 4
	remove_button.pressed.connect(_on_remove_pressed)
	add_child(remove_button)
	refresh()


func refresh() -> void:
	if holder == null:
		return
	remove_button.tooltip_text = TranslationServer.translate(&"demo.ui.synthesis.take_back")
	if card == null:
		empty_label.visible = true
		remove_button.visible = false
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	empty_label.visible = false
	remove_button.visible = true
	var definition := QuestArcCatalog.item_by_id(card.definition_id)
	card_view.setup(card, definition, true)
	card_view.visible = true
	card_view.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_remove_pressed() -> void:
	if controller != null and card != null:
		controller.remove_material(role_id, card)


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
