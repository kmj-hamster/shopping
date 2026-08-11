class_name QuestSynthesisMaterialSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)
signal help_requested(role_id: StringName)

const SLOT_SIZE := QuestTaskSlot.CARD_SIZE
const DROP_MARGIN := QuestTaskSlot.DROP_MARGIN

var controller: QuestSynthesisInterface
var role_id: StringName
var card: CardItemState
var holder: CenterContainer
var empty_label: Label
var card_view: CardHandCard


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
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", QuestTaskSlot.make_card_slot_style())
	holder = CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	empty_label = Label.new()
	empty_label.text = "+"
	empty_label.add_theme_font_size_override("font_size", 42)
	empty_label.add_theme_color_override("font_color", Color("6f827d"))
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(empty_label)
	# Build the reusable card presentation once. Placing/removing materials only
	# rebinds and toggles this view; it never allocates nodes in the drop path.
	card_view = CardHandCard.new()
	card_view.inspect_requested.connect(item_inspected.emit)
	holder.add_child(card_view)
	card_view.visible = false
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)
	refresh()


func refresh() -> void:
	if holder == null:
		return
	if card == null:
		empty_label.visible = true
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	empty_label.visible = false
	var definition := controller.definition_for_card(card) if controller != null else null
	card_view.setup(card, definition, true)
	card_view.visible = true
	card_view.mouse_filter = Control.MOUSE_FILTER_PASS


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if controller == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var dropped_card := data.get("card") as CardItemState
	return (
		data.get("kind") == &"card_item"
		and dropped_card != card
		and controller.can_stage_card(role_id, dropped_card)
	)


func _has_point(point: Vector2) -> bool:
	return Rect2(-DROP_MARGIN, size + DROP_MARGIN * 2.0).has_point(point)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dropped_card := data.get("card") as CardItemState
	if dropped_card != null:
		controller.stage_card(role_id, dropped_card)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if (
		click != null
		and click.button_index == MOUSE_BUTTON_LEFT
		and click.pressed
	):
		controller.request_hand_tab_for_role(role_id)
		if card == null:
			help_requested.emit(role_id)
