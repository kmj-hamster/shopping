class_name QuestLocationUnlockSlot
extends QuestTaskSlot

signal staging_changed(card: CardItemState, staged: bool)

var store_id: StringName
var pending_card: CardItemState


func setup_unlock(
	game_state: QuestGameState,
	selected_store_id: StringName,
	selected_rule: CardSlotRule,
) -> void:
	state = game_state
	store_id = selected_store_id
	rule = selected_rule
	if is_node_ready():
		refresh()


func _ready() -> void:
	super._ready()
	card_view.drag_finished.connect(_on_pending_card_drag_finished)
	refresh()


func refresh() -> void:
	if rule == null or card_holder == null:
		return
	var definition := (
		QuestArcCatalog.item_by_id(pending_card.definition_id)
		if pending_card != null
		else null
	)
	if pending_card != null and definition != null:
		card_view.setup(pending_card, definition, true)
		card_view.visible = true
		card_view.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


func release_card() -> void:
	if pending_card == null:
		return
	var released := pending_card
	pending_card = null
	staging_changed.emit(released, false)
	refresh()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or rule == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	if data.get("kind") != &"card_item" or card == null or card == pending_card:
		return false
	if card not in state.inventory or card.location != CardItemState.Location.HAND:
		return false
	var definition := QuestArcCatalog.item_by_id(card.definition_id)
	return CardRuleEvaluator.can_execute(rule, definition)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card == null or card == pending_card:
		return
	var replaced := pending_card
	pending_card = card
	if replaced != null:
		staging_changed.emit(replaced, false)
	staging_changed.emit(card, true)
	refresh()


func _on_pending_card_drag_finished(card: CardItemState, succeeded: bool) -> void:
	if not succeeded or card == null or card != pending_card:
		return
	# Unlock staging deliberately leaves the model card in HAND. Prevent the
	# generic drag lifecycle from restoring this slot view after the hand accepts
	# the drop, then release the temporary staging ownership.
	card_view.drag_origin_visible = false
	card_view.drag_origin_mouse_filter = Control.MOUSE_FILTER_IGNORE
	release_card()
