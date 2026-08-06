class_name StoryCondition
extends Resource

enum Kind {
	ALWAYS,
	DAY_AT_LEAST,
	FLAG_EQUALS,
	TASK_COMPLETED,
	ITEM_ID_IN,
	ITEM_HAS_PROPERTY,
	DOMINANT_ASPECT,
}

@export var kind := Kind.ALWAYS
@export var key: StringName
@export var text_value: StringName
@export var minimum := 0
@export var item_ids: Array[StringName] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	match kind:
		Kind.ALWAYS:
			pass
		Kind.DAY_AT_LEAST:
			if minimum < 1:
				errors.append("DAY_AT_LEAST requires a positive day.")
		Kind.FLAG_EQUALS:
			if key.is_empty() or text_value.is_empty():
				errors.append("FLAG_EQUALS requires a key and value.")
		Kind.TASK_COMPLETED, Kind.ITEM_HAS_PROPERTY, Kind.DOMINANT_ASPECT:
			if key.is_empty():
				errors.append("Story condition kind %s requires a key." % kind)
		Kind.ITEM_ID_IN:
			if item_ids.is_empty():
				errors.append("ITEM_ID_IN requires at least one item id.")
	return errors
