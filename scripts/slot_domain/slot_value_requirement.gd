class_name SlotValueRequirement
extends Resource

enum Mode {
	SINGLE,
	ANY,
	SUM,
}

@export var mode := Mode.SINGLE
@export var tags: Array[StringName] = []
@export_range(1, 64, 1) var minimum := 1


func actual_value(item: CardItemDefinition) -> int:
	if item == null or tags.is_empty():
		return 0
	match mode:
		Mode.SINGLE:
			return item.property_value(tags[0])
		Mode.ANY:
			var highest := 0
			for tag in tags:
				highest = maxi(highest, item.property_value(tag))
			return highest
		Mode.SUM:
			var total := 0
			for tag in tags:
				total += item.property_value(tag)
			return total
	return 0


func is_met(item: CardItemDefinition) -> bool:
	return actual_value(item) >= minimum


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if tags.is_empty():
		errors.append("A value requirement needs at least one tag.")
	if mode == Mode.SINGLE and tags.size() != 1:
		errors.append("A SINGLE value requirement needs exactly one tag.")
	if minimum < 1:
		errors.append("A value requirement minimum must be positive.")
	return errors
