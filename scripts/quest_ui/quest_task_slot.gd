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
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	var slot_style := UiPalette.panel_style(Color("0b1519", 0.97), Color("657b76", 0.82))
	slot_style.content_margin_left = 0.0
	slot_style.content_margin_top = 0.0
	slot_style.content_margin_right = 0.0
	slot_style.content_margin_bottom = 0.0
	add_theme_stylebox_override("panel", slot_style)
	var stack := Control.new()
	stack.custom_minimum_size = CARD_SIZE
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	card_holder = CenterContainer.new()
	card_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(card_holder)
	caption_label = Label.new()
	caption_label.anchor_left = 0.0
	caption_label.anchor_top = 0.0
	caption_label.anchor_right = 1.0
	caption_label.anchor_bottom = 0.34
	caption_label.offset_left = 8.0
	caption_label.offset_top = 7.0
	caption_label.offset_right = -8.0
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_font_size_override("font_size", 12)
	caption_label.add_theme_color_override("font_color", Color("b9c8c2"))
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(caption_label)
	evaluation_label = Label.new()
	evaluation_label.anchor_left = 0.0
	evaluation_label.anchor_top = 0.74
	evaluation_label.anchor_right = 1.0
	evaluation_label.anchor_bottom = 1.0
	evaluation_label.offset_left = 6.0
	evaluation_label.offset_right = -6.0
	evaluation_label.offset_bottom = -5.0
	evaluation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evaluation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	evaluation_label.add_theme_font_size_override("font_size", 10)
	evaluation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(evaluation_label)
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
	if card != null and item != null:
		var view := CardHandCard.new()
		view.setup(card, item, not task.confirmed)
		view.inspect_requested.connect(item_inspected.emit)
		card_holder.add_child(view)
		caption_label.visible = false
		evaluation_label.visible = false
	else:
		var empty := Label.new()
		empty.text = "◇"
		empty.add_theme_font_size_override("font_size", 34)
		empty.add_theme_color_override("font_color", Color("657873"))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_holder.add_child(empty)
		caption_label.visible = not _is_owner_request()
		evaluation_label.visible = false
		evaluation_label.text = ""


func _is_owner_request() -> bool:
	if task == null:
		return false
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	return definition != null and definition.category == TaskDefinition.Category.OWNER_REQUEST


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
