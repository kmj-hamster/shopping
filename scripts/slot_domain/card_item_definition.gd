class_name CardItemDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var store_id: StringName
@export_range(0, 999, 1) var base_price := 0
@export_range(0, 100, 1) var restock_weight := 0
@export var unlock_owner_id: StringName
@export_range(0, 20, 1) var unlock_level := 0
@export var is_crafted := false
@export_range(0, 999, 1) var fixed_resale_value := 0
@export var property_set: CardPropertySet


func property_value(tag: StringName) -> int:
	return property_set.value(tag) if property_set != null else 0


func has_property(tag: StringName) -> bool:
	return property_value(tag) > 0


func localized_name() -> String:
	return TranslationServer.translate(display_name_key)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Item id cannot be empty.")
	if display_name_key.is_empty():
		errors.append("Item %s needs a display name key." % id)
	if not is_crafted and store_id.is_empty():
		errors.append("Retail item %s needs a store id." % id)
	if is_crafted and restock_weight != 0:
		errors.append("Crafted item %s cannot have restock weight." % id)
	if property_set == null:
		errors.append("Item %s needs properties." % id)
	else:
		errors.append_array(property_set.validation_errors())
	return errors
