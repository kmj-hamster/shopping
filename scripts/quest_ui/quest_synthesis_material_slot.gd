class_name QuestSynthesisMaterialSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

const SLOT_SIZE := QuestTaskSlot.CARD_SIZE
const DROP_MARGIN := QuestTaskSlot.DROP_MARGIN
const EMPTY_COLOR := Color("6f827d")
const DROP_HIGHLIGHT_COLOR := Color("efd68e")

var controller: QuestSynthesisInterface
var role_id: StringName
var card: CardItemState
var drop_highlighted := false
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
	empty_label.add_theme_color_override("font_color", EMPTY_COLOR)
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(empty_label)
	# Build the reusable card presentation once. Placing/removing materials only
	# rebinds and toggles this view; it never allocates nodes in the drop path.
	card_view = CardHandCard.new()
	card_view.inspect_requested.connect(item_inspected.emit)
	card_view.drag_started.connect(_on_card_drag_started)
	card_view.drag_finished.connect(_on_card_drag_finished)
	holder.add_child(card_view)
	card_view.visible = false
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)
	refresh()
	_apply_drop_highlight_style()


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


func set_drop_highlight(highlighted: bool) -> void:
	if drop_highlighted == highlighted:
		return
	drop_highlighted = highlighted
	_apply_drop_highlight_style()


func _apply_drop_highlight_style() -> void:
	var style := QuestTaskSlot.make_card_slot_style()
	if drop_highlighted:
		style.border_color = DROP_HIGHLIGHT_COLOR
		style.set_border_width_all(3)
		var shadow_color := DROP_HIGHLIGHT_COLOR
		shadow_color.a = 0.38
		style.shadow_color = shadow_color
		style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	if empty_label != null:
		empty_label.add_theme_color_override(
			"font_color", DROP_HIGHLIGHT_COLOR if drop_highlighted else EMPTY_COLOR
		)


func _on_card_drag_started(dragged_card: CardItemState) -> void:
	if controller != null:
		controller.show_drop_targets_for_card(dragged_card)


func _on_card_drag_finished(_dragged_card: CardItemState, _succeeded: bool) -> void:
	if controller != null:
		controller.clear_drop_target_highlights()


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if (
		click != null
		and click.button_index == MOUSE_BUTTON_LEFT
		and click.pressed
	):
		controller.request_hand_tab_for_role(role_id)
