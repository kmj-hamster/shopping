class_name PuzzleRules
extends RefCounted


static func can_place(
	task: TaskDefinition,
	piece: PuzzlePieceState,
	pieces: Array[PuzzlePieceState],
	position: Vector2i,
	rotation_steps: int,
	ignored_piece: PuzzlePieceState = null
) -> bool:
	var occupied_by_others: Dictionary = {}
	for other in pieces:
		if other == piece or other == ignored_piece or other.location != PuzzlePieceState.Location.BOARD:
			continue
		for cell in other.occupied_cells():
			occupied_by_others[cell] = true

	for cell in piece.occupied_cells(position, rotation_steps):
		if not task.has_cell(cell) or occupied_by_others.has(cell):
			return false
	return true


static func evaluate(task: TaskDefinition, pieces: Array[PuzzlePieceState]) -> Dictionary:
	var occupied: Dictionary = {}
	var overlap_cells: Array[Vector2i] = []
	var outside_cells: Array[Vector2i] = []
	var attribute_totals := {
		ItemDefinition.ATTRIBUTE_LAMP: 0,
		ItemDefinition.ATTRIBUTE_MIRROR: 0,
		ItemDefinition.ATTRIBUTE_FLOWER: 0,
		ItemDefinition.ATTRIBUTE_FOG: 0,
	}
	var required_special_count := 0

	for piece in pieces:
		if piece.location != PuzzlePieceState.Location.BOARD:
			continue
		if piece.definition.id == task.required_special_item_id:
			required_special_count += 1
		attribute_totals[piece.definition.attribute] += piece.definition.cell_count()
		for cell in piece.occupied_cells():
			if not task.has_cell(cell):
				outside_cells.append(cell)
			elif occupied.has(cell):
				overlap_cells.append(cell)
			else:
				occupied[cell] = piece

	var missing_cells: Array[Vector2i] = []
	for cell in task.mask_cells:
		if not occupied.has(cell):
			missing_cells.append(cell)

	var attribute_ok := _attribute_rule_is_satisfied(task.attribute_rule, attribute_totals)
	var reasons := PackedStringArray()
	if not outside_cells.is_empty():
		reasons.append(TranslationServer.translate(&"puzzle.reason.outside"))
	if not overlap_cells.is_empty():
		reasons.append(TranslationServer.translate(&"puzzle.reason.overlap"))
	if not missing_cells.is_empty():
		reasons.append(TranslationServer.translate(&"puzzle.reason.missing_cells") % missing_cells.size())
	if required_special_count == 0:
		reasons.append(TranslationServer.translate(&"puzzle.reason.missing_special"))
	elif required_special_count > 1:
		reasons.append(TranslationServer.translate(&"puzzle.reason.duplicate_special"))
	if not attribute_ok:
		reasons.append(_attribute_failure_text(task.attribute_rule))

	return {
		"is_complete": reasons.is_empty(),
		"covered_count": occupied.size(),
		"total_count": task.mask_cells.size(),
		"missing_cells": missing_cells,
		"overlap_cells": overlap_cells,
		"outside_cells": outside_cells,
		"has_required_special": required_special_count == 1,
		"required_special_count": required_special_count,
		"attribute_totals": attribute_totals,
		"attribute_ok": attribute_ok,
		"reasons": reasons,
	}


static func _attribute_rule_is_satisfied(rule: TaskDefinition.AttributeRule, totals: Dictionary) -> bool:
	var lamp: int = totals[ItemDefinition.ATTRIBUTE_LAMP]
	var mirror: int = totals[ItemDefinition.ATTRIBUTE_MIRROR]
	var flower: int = totals[ItemDefinition.ATTRIBUTE_FLOWER]
	var fog: int = totals[ItemDefinition.ATTRIBUTE_FOG]
	match rule:
		TaskDefinition.AttributeRule.MIRROR_STRICT:
			return mirror > lamp and mirror > flower and mirror > fog
		TaskDefinition.AttributeRule.LAMP_OR_FLOWER:
			return maxi(lamp, flower) > mirror and maxi(lamp, flower) > fog
		_:
			return true


static func _attribute_failure_text(rule: TaskDefinition.AttributeRule) -> String:
	match rule:
		TaskDefinition.AttributeRule.MIRROR_STRICT:
			return TranslationServer.translate(&"puzzle.reason.mirror")
		TaskDefinition.AttributeRule.LAMP_OR_FLOWER:
			return TranslationServer.translate(&"puzzle.reason.warm")
		_:
			return TranslationServer.translate(&"puzzle.reason.attribute")
