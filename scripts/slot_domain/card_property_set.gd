class_name CardPropertySet
extends Resource

const ASPECT_LAMP := &"lamp"
const ASPECT_MIRROR := &"mirror"
const ASPECT_GAUZE := &"gauze"
const ASPECT_PILLOW := &"pillow"
const ASPECTS: Array[StringName] = [
	ASPECT_LAMP,
	ASPECT_MIRROR,
	ASPECT_GAUZE,
	ASPECT_PILLOW,
]
const PERSONA_EASE := &"ease"
const PERSONA_REVERIE := &"reverie"
const PERSONA_REMINISCENCE := &"reminiscence"
const PERSONA_CLARITY := &"clarity"
const PROTAGONIST_STATS: Array[StringName] = [
	PERSONA_EASE,
	PERSONA_REVERIE,
	PERSONA_REMINISCENCE,
	PERSONA_CLARITY,
]
const PERSONA_ASPECTS := {
	PERSONA_EASE: ASPECT_PILLOW,
	PERSONA_REVERIE: ASPECT_GAUZE,
	PERSONA_REMINISCENCE: ASPECT_MIRROR,
	PERSONA_CLARITY: ASPECT_LAMP,
}

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


func present_aspects() -> Array[StringName]:
	var result: Array[StringName] = []
	for aspect in ASPECTS:
		if has(aspect):
			result.append(aspect)
	return result


static func aspect_for_persona(persona_id: StringName) -> StringName:
	return StringName(PERSONA_ASPECTS.get(persona_id, &""))


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
		elif tag in ASPECTS:
			errors.append("Night aspect %s must have a scaled value." % tag)
		seen_tags[tag] = true
	for raw_tag in values:
		var tag := String(raw_tag)
		var amount := int(values[raw_tag])
		if tag.is_empty():
			errors.append("Property tags cannot be empty.")
		elif amount < 1 or amount > 20:
			errors.append("Property %s must be between 1 and 20." % tag)
	return errors
