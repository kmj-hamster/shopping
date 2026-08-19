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
	var definition := state.definition_for_card(pending_card) if pending_card != null else null
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
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return (
		data.get("kind") == &"card_item"
		and can_accept_card(data.get("card") as CardItemState)
	)


func can_accept_card(card: CardItemState) -> bool:
	if state == null or rule == null or card == null or card == pending_card:
		return false
	if card.location != CardItemState.Location.HAND:
		return false
	var definition := state.definition_for_card(card)
	if state.is_disease_definition(definition):
		return false
	var is_owned_item := card in state.inventory
	var persona_id := PersonaMaskCatalog.persona_for_card(card)
	if not is_owned_item and (
		persona_id.is_empty()
		or int(state.protagonist_persona_counts.get(persona_id, 0)) <= 0
	):
		return false
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
