class_name QuestLocationUnlockSlot
extends PanelContainer

signal staging_changed(card: CardItemState, staged: bool)
signal rule_focused(rule: CardSlotRule)

var state: QuestGameState
var store_id: StringName
var rule: CardSlotRule
var pending_card: CardItemState
var content: CenterContainer
var remove_button: Button


func setup(
	game_state: QuestGameState,
	selected_store_id: StringName,
	selected_rule: CardSlotRule,
) -> void:
	state = game_state
	store_id = selected_store_id
	rule = selected_rule
	if is_node_ready():
		_rebuild()


func _ready() -> void:
	custom_minimum_size = Vector2(150, 166)
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("17140f", 0.96), Color("8b7754"))
	)
	content = CenterContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	gui_input.connect(_on_gui_input)
	_rebuild()


func release_card() -> void:
	if pending_card == null:
		return
	var released := pending_card
	pending_card = null
	staging_changed.emit(released, false)
	_rebuild()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or rule == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	if data.get("kind") != &"card_item" or card == null:
		return false
	if card not in state.inventory or card.location != CardItemState.Location.HAND:
		return false
	var definition := QuestArcCatalog.item_by_id(card.definition_id)
	return CardRuleEvaluator.evaluate(rule, definition).can_execute


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card == null or card == pending_card:
		return
	if pending_card != null:
		staging_changed.emit(pending_card, false)
	pending_card = card
	staging_changed.emit(pending_card, true)
	_rebuild()


func _rebuild() -> void:
	if content == null:
		return
	if remove_button != null and is_instance_valid(remove_button):
		remove_button.free()
	remove_button = null
	for child in content.get_children():
		child.free()
	if pending_card == null:
		var empty_label := Label.new()
		empty_label.custom_minimum_size = Vector2(126, 142)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color("cbbd9b"))
		empty_label.text = TranslationServer.translate(rule.display_name_key) if rule != null else ""
		content.add_child(empty_label)
		return
	var definition := QuestArcCatalog.item_by_id(pending_card.definition_id)
	var preview := CardHandCard.new()
	preview.name = "StagedCard"
	preview.setup(pending_card, definition, false)
	content.add_child(preview)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remove_button = Button.new()
	remove_button.name = "RemoveStagedCardButton"
	remove_button.text = "×"
	remove_button.tooltip_text = TranslationServer.translate(&"demo.ui.location.remove")
	remove_button.anchor_left = 1.0
	remove_button.anchor_right = 1.0
	remove_button.offset_left = -34
	remove_button.offset_right = -4
	remove_button.offset_top = 4
	remove_button.offset_bottom = 34
	remove_button.pressed.connect(release_card)
	add_child(remove_button)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		rule_focused.emit(rule)
