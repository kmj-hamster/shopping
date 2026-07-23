class_name PuzzlePieceState
extends RefCounted

enum Location {
	INVENTORY,
	BOARD,
}

var piece_uid: int
var definition: ItemDefinition
var location: Location = Location.INVENTORY
var grid_position := Vector2i(-1, -1)
var rotation_steps: int = 0


func _init(uid: int = 0, item_definition: ItemDefinition = null) -> void:
	piece_uid = uid
	definition = item_definition


func local_cells(candidate_rotation: int = rotation_steps) -> Array[Vector2i]:
	return definition.cells_at_rotation(candidate_rotation)


func occupied_cells(
	candidate_position: Vector2i = grid_position,
	candidate_rotation: int = rotation_steps
) -> Array[Vector2i]:
	return PolyominoGeometry.translated(local_cells(candidate_rotation), candidate_position)
