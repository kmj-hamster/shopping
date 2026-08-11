class_name QuestTaskSlot
extends PanelContainer

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

const CARD_SIZE := CardHandCard.CARD_SIZE
const DROP_MARGIN := Vector2(18, 26)

var state: QuestGameState
var task: TaskInstanceState
var rule: CardSlotRule
var card_holder: CenterContainer
var card_view: CardHandCard


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
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", make_card_slot_style())
	var stack := Control.new()
	stack.custom_minimum_size = CARD_SIZE
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	card_holder = CenterContainer.new()
	card_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(card_holder)
	card_view = CardHandCard.new()
	card_view.inspect_requested.connect(item_inspected.emit)
	card_holder.add_child(card_view)
	card_view.visible = false
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)
	refresh()


func refresh() -> void:
	if rule == null or card_holder == null:
		return
	var card := state.card_by_instance_id(task.assigned_instance_id(rule.id))
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	if card != null and item != null:
		card_view.setup(card, item, not task.confirmed)
		card_view.visible = true
		card_view.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or task == null or task.confirmed or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	return (
		data.get("kind") == &"card_item"
		and card != null
		and card in state.inventory
		and CardRuleEvaluator.can_place(rule, item)
	)


func _has_point(point: Vector2) -> bool:
	return Rect2(-DROP_MARGIN, size + DROP_MARGIN * 2.0).has_point(point)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null:
		state.assign_card(task.instance_id, rule.id, card)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		rule_focused.emit(rule)


static func make_card_slot_style() -> StyleBoxFlat:
	var style := UiPalette.panel_style(Color("0b1519", 0.97), Color("657b76", 0.82))
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style
