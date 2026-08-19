class_name CardPropertySet
extends Resource

const PROPERTY_PERSONA := &"persona"
const PROPERTY_DISEASE := &"disease"
const PERSONA_NIGHTWALKER := &"nightwalker"
const PERSONA_MOURNER := &"mourner"
const PERSONA_DREAMWALKER := &"dreamwalker"
const PERSONA_HOMECOMER := &"homecomer"
const PERSONAS: Array[StringName] = [
	PERSONA_NIGHTWALKER,
	PERSONA_MOURNER,
	PERSONA_DREAMWALKER,
	PERSONA_HOMECOMER,
]

@export var values: Dictionary = {}
@export var tags: Array[StringName] = []


func value(tag: StringName) -> int:
	if values.has(tag):
		return int(values[tag])
	return int(values.get(String(tag), 0))


func has(tag: StringName) -> bool:
	return tags.has(tag) or value(tag) > 0


func property_ids() -> Array[StringName]:
	var result: Array[StringName] = tags.duplicate()
	for raw_tag in values:
		var tag := StringName(raw_tag)
		if tag not in result:
			result.append(tag)
	return result


func property_count() -> int:
	return property_ids().size()


func present_personas() -> Array[StringName]:
	var result: Array[StringName] = []
	for persona_id in PERSONAS:
		if has(persona_id):
			result.append(persona_id)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_tags: Dictionary = {}
	for tag in tags:
		if tag.is_empty():
			errors.append("Property tags cannot be empty.")
		elif seen_tags.has(tag):
			errors.append("Property tag %s cannot be repeated." % tag)
		elif values.has(tag) or values.has(String(tag)):
			errors.append("Property %s cannot be both a tag and a scaled value." % tag)
		elif tag in PERSONAS:
			errors.append("Persona %s must have a scaled value." % tag)
		seen_tags[tag] = true
	for raw_tag in values:
		var tag := String(raw_tag)
		var amount := int(values[raw_tag])
		if tag.is_empty():
			errors.append("Property tags cannot be empty.")
		elif amount < 1 or amount > 20:
			errors.append("Property %s must be between 1 and 20." % tag)
	return errors
