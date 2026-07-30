class_name ShelfSlotState
extends RefCounted

var store_id: StringName
var slot_id: StringName
var item_id: StringName


func _init(
	selected_store_id: StringName = &"",
	selected_slot_id: StringName = &"",
	selected_item_id: StringName = &"",
) -> void:
	store_id = selected_store_id
	slot_id = selected_slot_id
	item_id = selected_item_id


func is_empty() -> bool:
	return item_id.is_empty()


func stock(selected_item_id: StringName) -> void:
	item_id = selected_item_id


func clear() -> void:
	item_id = &""
