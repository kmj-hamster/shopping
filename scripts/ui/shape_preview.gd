class_name ShapePreview
extends Control

var piece: PuzzlePieceState
var cell_size := 14.0
var draw_background := false
var center_shape := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(value: PuzzlePieceState) -> void:
	piece = value
	queue_redraw()


func configure_for_drag(value: PuzzlePieceState, grab_offset: Vector2i, target_cell_size: float) -> void:
	piece = value
	cell_size = target_cell_size
	draw_background = false
	center_shape = false
	refresh_drag_geometry(grab_offset)


func refresh_drag_geometry(grab_offset: Vector2i) -> void:
	if piece == null:
		return
	var shape_size := Vector2(PolyominoGeometry.bounds_size(piece.local_cells())) * cell_size
	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	custom_minimum_size = shape_size
	size = shape_size
	position = -(Vector2(grab_offset) + Vector2(0.5, 0.5)) * cell_size
	queue_redraw()


func closest_occupied_cell(local_position: Vector2) -> Vector2i:
	if piece == null or piece.local_cells().is_empty():
		return Vector2i.ZERO
	var origin := _shape_origin()
	var result := piece.local_cells()[0]
	var best_distance := INF
	for cell in piece.local_cells():
		var center := origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
		var distance := center.distance_squared_to(local_position)
		if distance < best_distance:
			best_distance = distance
			result = cell
	return result


func _draw() -> void:
	if draw_background:
		draw_rect(Rect2(Vector2.ZERO, size), Color("18212d"), true)
	if piece == null or piece.definition == null:
		return
	var cells := piece.local_cells()
	var origin := _shape_origin()
	var color := UiPalette.attribute_color(piece.definition.attribute)
	for cell in cells:
		var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect.grow(-1.0), color, true)
		draw_rect(rect.grow(-1.0), color.lightened(0.28), false, 1.0)
		if piece.definition.is_special:
			draw_rect(rect.grow(-3.0), Color("f2eadf"), false, 1.5)


func _shape_origin() -> Vector2:
	if piece == null or not center_shape:
		return Vector2.ZERO
	var bounds := PolyominoGeometry.bounds_size(piece.local_cells())
	return (size - Vector2(bounds) * cell_size) * 0.5
