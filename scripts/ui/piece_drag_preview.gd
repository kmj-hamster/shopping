class_name PieceDragPreview
extends Control

var shape_preview: ShapePreview


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	shape_preview = ShapePreview.new()
	add_child(shape_preview)


func configure_for_drag(
	value: PuzzlePieceState,
	grab_offset: Vector2i,
	target_cell_size: float
) -> void:
	shape_preview.configure_for_drag(value, grab_offset, target_cell_size)


func refresh_drag_geometry(grab_offset: Vector2i) -> void:
	shape_preview.refresh_drag_geometry(grab_offset)
