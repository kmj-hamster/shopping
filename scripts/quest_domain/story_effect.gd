class_name StoryEffect
extends Resource

enum Kind {
	ADD_MONEY,
	SET_FLAG,
	ADD_PROTAGONIST_PERSONA,
	DISCOVER_RECIPE,
	ACTIVATE_TASK,
	SET_OWNER_STATE,
	UNLOCK_STORE,
	GIVE_ITEM,
	UNLOCK_STORE_ITEM,
}

@export var kind := Kind.SET_FLAG
@export var target_id: StringName
@export var text_value: StringName
@export var amount := 0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	match kind:
		Kind.ADD_MONEY:
			if amount < 0:
				errors.append("Money effects cannot remove money in this content layer.")
		Kind.ADD_PROTAGONIST_PERSONA:
			if target_id not in CardPropertySet.SHAPES or amount <= 0:
				errors.append("Persona effects need a known shape and positive amount.")
		Kind.SET_FLAG:
			if target_id.is_empty() or text_value.is_empty():
				errors.append("Flag effects need a key and value.")
		_:
			if target_id.is_empty():
				errors.append("Story effect kind %s needs a target id." % kind)
	return errors
