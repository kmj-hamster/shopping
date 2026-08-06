class_name PropertyDefinition
extends Resource

enum ValueKind {
	TAG,
	SCALED,
}

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var value_kind := ValueKind.TAG
@export var is_night_aspect := false


func is_scaled() -> bool:
	return value_kind == ValueKind.SCALED


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Property definition id cannot be empty.")
	if display_name_key.is_empty() or description_key.is_empty():
		errors.append("Property %s needs name and description keys." % id)
	if is_night_aspect and not is_scaled():
		errors.append("Night aspect %s must be scaled." % id)
	if is_night_aspect and id not in CardPropertySet.ASPECTS:
		errors.append("Unknown night aspect id: %s." % id)
	return errors
