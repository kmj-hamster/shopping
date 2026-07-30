class_name CardPropertySet
extends Resource

const ASPECT_LAMP := &"lamp"
const ASPECT_MIRROR := &"mirror"
const ASPECT_CANDLE := &"candle"
const ASPECT_PILLOW := &"pillow"
const ASPECTS: Array[StringName] = [
	ASPECT_LAMP,
	ASPECT_MIRROR,
	ASPECT_CANDLE,
	ASPECT_PILLOW,
]

@export var values: Dictionary = {}


func value(tag: StringName) -> int:
	if values.has(tag):
		return int(values[tag])
	return int(values.get(String(tag), 0))


func has(tag: StringName) -> bool:
	return value(tag) > 0


func present_aspects() -> Array[StringName]:
	var result: Array[StringName] = []
	for aspect in ASPECTS:
		if has(aspect):
			result.append(aspect)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for raw_tag in values:
		var tag := String(raw_tag)
		var amount := int(values[raw_tag])
		if tag.is_empty():
			errors.append("Property tags cannot be empty.")
		elif amount < 1 or amount > 8:
			errors.append("Property %s must be between 1 and 8." % tag)
	return errors
