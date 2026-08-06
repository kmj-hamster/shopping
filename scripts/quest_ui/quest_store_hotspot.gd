class_name QuestStoreHotspot
extends Button

signal unlock_requested(store_id: StringName, card: CardItemState)

var state: QuestGameState
var store_id: StringName


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or state.is_store_unlocked(store_id) or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	var unlock := QuestArcCatalog.store_unlock_for_store(store_id)
	var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
	return (
		data.get("kind") == &"card_item"
		and card != null
		and card.location == CardItemState.Location.HAND
		and unlock != null
		and QuestArcRules.store_unlock_accepts(unlock, item)
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card != null:
		unlock_requested.emit(store_id, card)
