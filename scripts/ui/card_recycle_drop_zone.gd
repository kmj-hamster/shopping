class_name CardRecycleDropZone
extends PanelContainer

signal card_dropped(card: CardItemState)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"card_item":
		return false
	var card := data.get("card") as CardItemState
	return card != null and card.location == CardItemState.Location.HAND


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null:
		card_dropped.emit(card)
