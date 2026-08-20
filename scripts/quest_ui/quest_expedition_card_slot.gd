class_name QuestExpeditionCardSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

const SLOT_SIZE := Vector2(90, 110)

var controller: QuestExpeditionScreen
var slot_index := 0
var card: CardItemState
var shape_id: StringName
var holder: CenterContainer
var empty_label: Label
var card_view: CardHandCard
var drop_highlighted := false


func setup(
	screen: QuestExpeditionScreen,
	index: int,
	selected_card: CardItemState = null,
	selected_shape_id: StringName = &"",
) -> void:
	controller = screen
	slot_index = index
	card = selected_card
	shape_id = selected_shape_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	holder = CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	empty_label = Label.new()
	empty_label.text = "+"
	empty_label.add_theme_font_size_override("font_size", 38)
	empty_label.add_theme_color_override("font_color", Color("77908f"))
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(empty_label)
	card_view = CardHandCard.new()
	card_view.inspect_requested.connect(item_inspected.emit)
	card_view.drag_started.connect(_on_card_drag_started)
	holder.add_child(card_view)
	card_view.visible = false
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	refresh()


func refresh() -> void:
	if card_view == null:
		return
	if card == null:
		empty_label.visible = true
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var definition := controller.definition_for_card(card) if controller != null else null
	empty_label.visible = false
	card_view.setup(card, definition, true)
	card_view.visible = true
	card_view.mouse_filter = Control.MOUSE_FILTER_PASS


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if controller == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var dropped_card := data.get("card") as CardItemState
	return data.get("kind") == &"card_item" and controller.can_stage_card(slot_index, dropped_card)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dropped_card := data.get("card") as CardItemState
	if dropped_card != null:
		controller.stage_card(slot_index, dropped_card)


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2(-24, -24), size + Vector2(48, 48)).has_point(point)


func set_drop_highlight(highlighted: bool) -> void:
	drop_highlighted = highlighted
	_apply_style()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d24", 0.74)
	style.border_color = Color("edf4e8", 0.95) if drop_highlighted else Color("76908e", 0.82)
	style.set_border_width_all(3 if drop_highlighted else 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	if drop_highlighted:
		style.shadow_color = Color(0.86, 1.0, 0.96, 0.42)
		style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	if empty_label != null:
		empty_label.add_theme_color_override(
			"font_color", Color("edf4e8") if drop_highlighted else Color("77908f")
		)


func _on_card_drag_started(_dragged_card: CardItemState) -> void:
	if controller != null:
		controller.unstage_slot(slot_index)
