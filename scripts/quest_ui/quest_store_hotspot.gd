class_name QuestStoreHotspot
extends Button

var state: QuestGameState
var store_id: StringName


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return false
