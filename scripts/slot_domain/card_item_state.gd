class_name CardItemState
extends RefCounted

enum Location {
	# These values are serialized in save files. Preserve them or migrate the save format.
	HAND = 0,
	ACTIVITY_SLOT = 1,
	OWNER_REQUEST = 2,
	RECYCLE = 3,
}

var instance_id: int
var definition_id: StringName
var acquired_day: int
var acquisition_source: StringName
var purchase_price: int
var location := Location.HAND
var activity_id: StringName
var slot_id: StringName
var use_count := 0


func _init(
	selected_instance_id: int = 0,
	selected_definition_id: StringName = &"",
	day_acquired: int = 1,
	source: StringName = &"shop",
	paid_price: int = 0,
) -> void:
	instance_id = selected_instance_id
	definition_id = selected_definition_id
	acquired_day = day_acquired
	acquisition_source = source
	purchase_price = maxi(0, paid_price)


func assign_to(
	selected_activity_id: StringName,
	selected_slot_id: StringName,
	target_location: Location = Location.ACTIVITY_SLOT,
) -> void:
	activity_id = selected_activity_id
	slot_id = selected_slot_id
	location = target_location


func return_to_hand() -> void:
	activity_id = &""
	slot_id = &""
	location = Location.HAND
