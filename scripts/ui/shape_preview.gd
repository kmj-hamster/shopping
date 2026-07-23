class_name ShapePreview
extends Control

var piece: PuzzlePieceState
var cell_size := 14.0
var draw_background := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(value: PuzzlePieceState) -> void:
	piece = value
	queue_redraw()


func _draw() -> void:
	if draw_background:
		draw_rect(Rect2(Vector2.ZERO, size), Color("18212d"), true)
	if piece == null or piece.definition == null:
		return
	var cells := piece.local_cells()
	var bounds := PolyominoGeometry.bounds_size(cells)
	var shape_size := Vector2(bounds) * cell_size
	var origin := (size - shape_size) * 0.5
	var color := UiPalette.attribute_color(piece.definition.attribute)
	for cell in cells:
		var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect.grow(-1.0), color, true)
		draw_rect(rect.grow(-1.0), color.lightened(0.28), false, 1.0)
