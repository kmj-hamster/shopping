class_name PuzzlePieceState
extends RefCounted

enum Location {
	BOARD,
	RECYCLE_CART,
}

enum Ownership {
	OWNED,
	PENDING_PURCHASE,
}

var piece_uid: int
var definition: ItemDefinition
var location: Location = Location.BOARD
var ownership: Ownership = Ownership.OWNED
var grid_position := Vector2i(-1, -1)
var rotation_steps: int = 0
var task_id: StringName = &""


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


func copy_for_drag() -> PuzzlePieceState:
	var copy := PuzzlePieceState.new(piece_uid, definition)
	copy.location = location
	copy.ownership = ownership
	copy.grid_position = grid_position
	copy.rotation_steps = rotation_steps
	copy.task_id = task_id
	return copy
