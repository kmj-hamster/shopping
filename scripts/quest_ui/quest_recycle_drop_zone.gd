class_name QuestRecycleDropZone
extends PanelContainer

signal card_staged(card: CardItemState)

var state: QuestGameState


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	var definition := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	return (
		data.get("kind") == &"card_item"
		and card != null
		and card.location == CardItemState.Location.HAND
		and definition != null
		and definition.can_recycle
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null and state.stage_recycle_card(card).ok:
		card_staged.emit(card)
