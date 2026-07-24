class_name RecycleDropZone
extends PanelContainer

signal recycle_requested(piece: PuzzlePieceState)


func piece_from_drag(data: Variant) -> PuzzlePieceState:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return null
	if data.get("source") != &"board":
		return null
	return data.get("original") as PuzzlePieceState


func request_recycle(data: Variant) -> bool:
	var piece := piece_from_drag(data)
	if piece == null:
		return false
	recycle_requested.emit(piece)
	return true


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return piece_from_drag(data) != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	request_recycle(data)
