class_name StoreDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var owner_id: StringName
@export var initially_unlocked := false
@export var unlock_definition_id: StringName
@export var visible_after_store_ids: Array[StringName] = []
@export var map_anchor := Vector2(0.5, 0.5)
@export_range(1, 30, 1) var restock_interval_days := 1
@export_range(1, 30, 1) var restock_phase_day := 1
@export_range(0, 6, 1) var initial_capacity := 6
@export var initial_shelf_item_ids: Array[StringName] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or display_name_key.is_empty():
		errors.append("Store needs id and display name.")
	if initially_unlocked and not unlock_definition_id.is_empty():
		errors.append("Initially open store %s cannot require a map unlock." % id)
	if not initially_unlocked and unlock_definition_id.is_empty():
		errors.append("Locked store %s needs a map unlock definition." % id)
	if initial_shelf_item_ids.size() > initial_capacity:
		errors.append("Store %s has more initial items than shelf positions." % id)
	if map_anchor.x < 0.0 or map_anchor.x > 1.0 or map_anchor.y < 0.0 or map_anchor.y > 1.0:
		errors.append("Store %s has an invalid map anchor." % id)
	if restock_phase_day > restock_interval_days:
		errors.append("Store %s restock phase exceeds its interval." % id)
	return errors


func is_restock_day(day: int) -> bool:
	return day >= restock_phase_day and (day - restock_phase_day) % restock_interval_days == 0


func nights_until_restock(day: int) -> int:
	var elapsed := posmod(day - restock_phase_day, restock_interval_days)
	return restock_interval_days if elapsed == 0 else restock_interval_days - elapsed
