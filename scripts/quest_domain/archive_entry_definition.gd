class_name ArchiveEntryDefinition
extends Resource

@export var id: StringName
@export var title_key: StringName
@export var body_key: StringName


func localized_title() -> String:
	return TranslationServer.translate(title_key)


func localized_body() -> String:
	return TranslationServer.translate(body_key)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("Archive entry needs an id.")
	if title_key.is_empty():
		errors.append("Archive entry %s needs a title key." % id)
	if body_key.is_empty():
		errors.append("Archive entry %s needs a body key." % id)
	return errors
