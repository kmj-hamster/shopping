class_name QuestTaskSlot
extends PanelContainer

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

const CARD_SIZE := CardHandCard.CARD_SIZE
const DROP_MARGIN := Vector2(18, 26)
const PAPER_SLOT_COLOR := Color("d5d1c5", 0.92)
const PAPER_SLOT_BORDER_COLOR := Color("eeeade", 0.78)
const DROP_HIGHLIGHT_COLOR := Color("fffdf5")

var state: QuestGameState
var task: TaskInstanceState
var rule: CardSlotRule
var rules: Array[CardSlotRule] = []
var card_holder: CenterContainer
var card_view: CardHandCard
var drop_highlighted := false


func setup(
	game_state: QuestGameState,
	task_instance: TaskInstanceState,
	slot_rule: CardSlotRule,
) -> void:
	var selected_rules: Array[CardSlotRule] = []
	if slot_rule != null:
		selected_rules.append(slot_rule)
	setup_choices(game_state, task_instance, selected_rules)


func setup_choices(
	game_state: QuestGameState,
	task_instance: TaskInstanceState,
	slot_rules: Array[CardSlotRule],
) -> void:
	state = game_state
	task = task_instance
	rules = slot_rules.duplicate()
	rule = rules[0] if not rules.is_empty() else null
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_paper_slot_style()
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
	if rules.is_empty() or card_holder == null:
		return
	var card: CardItemState
	for candidate_rule in rules:
		var candidate := state.card_by_instance_id(task.assigned_instance_id(candidate_rule.id))
		if candidate != null:
			rule = candidate_rule
			card = candidate
			break
	if card == null:
		rule = rules[0]
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	if card != null and item != null:
		card_view.setup(card, item, not task.confirmed)
		card_view.visible = true
		card_view.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return (
		data.get("kind") == &"card_item"
		and can_accept_card(data.get("card") as CardItemState)
	)


func can_accept_card(card: CardItemState) -> bool:
	return (
		state != null
		and task != null
		and not task.confirmed
		and card != null
		and card != _assigned_card()
		and _matching_rule(card) != null
	)


func set_drop_highlight(highlighted: bool) -> void:
	if drop_highlighted == highlighted:
		return
	drop_highlighted = highlighted
	_apply_paper_slot_style()


func _apply_paper_slot_style() -> void:
	var style := UiPalette.panel_style(PAPER_SLOT_COLOR, PAPER_SLOT_BORDER_COLOR)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	if drop_highlighted:
		style.bg_color = Color("e7e3d8", 0.98)
		style.border_color = DROP_HIGHLIGHT_COLOR
		style.set_border_width_all(3)
		style.shadow_color = Color(DROP_HIGHLIGHT_COLOR, 0.72)
		style.shadow_size = 10
	add_theme_stylebox_override("panel", style)


func _has_point(point: Vector2) -> bool:
	return Rect2(-DROP_MARGIN, size + DROP_MARGIN * 2.0).has_point(point)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	var matching_rule := _matching_rule(card)
	if card == null or matching_rule == null:
		return
	# The presentation has one physical slot even when content declares several
	# alternative rules. Return any previous alternative before assigning the
	# replacement so the task can never hold more than one submitted card.
	for assigned_id in task.assigned_instance_ids().duplicate():
		var assigned_card := state.card_by_instance_id(assigned_id)
		if assigned_card != null and assigned_card != card:
			state.return_card_to_hand(assigned_card)
	state.assign_card(task.instance_id, matching_rule.id, card)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		rule_focused.emit(rule)


func _assigned_card() -> CardItemState:
	if state == null or task == null:
		return null
	for candidate_rule in rules:
		var card := state.card_by_instance_id(task.assigned_instance_id(candidate_rule.id))
		if card != null:
			return card
	return null


func _matching_rule(card: CardItemState) -> CardSlotRule:
	if state == null or task == null or card == null:
		return null
	for candidate_rule in rules:
		if state.can_assign_card_to_task(task.instance_id, candidate_rule.id, card):
			return candidate_rule
	return null


static func make_card_slot_style() -> StyleBoxFlat:
	var style := UiPalette.panel_style(Color("0b1519", 0.97), Color("657b76", 0.82))
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style
