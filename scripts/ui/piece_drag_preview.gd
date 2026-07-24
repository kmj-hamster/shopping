class_name PieceDragPreview
extends Control

const DRAG_CANVAS_LAYER := 100

var drag_layer: CanvasLayer
var shape_preview: ShapePreview
var grab_visual_offset := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	set_as_top_level(true)
	z_index = 4096
	drag_layer = CanvasLayer.new()
	drag_layer.layer = DRAG_CANVAS_LAYER
	add_child(drag_layer)
	shape_preview = ShapePreview.new()
	drag_layer.add_child(shape_preview)


func _process(_delta: float) -> void:
	_sync_to_mouse()


func configure_for_drag(
	value: PuzzlePieceState,
	grab_offset: Vector2i,
	target_cell_size: float
) -> void:
	shape_preview.configure_for_drag(value, grab_offset, target_cell_size)
	grab_visual_offset = shape_preview.position
	_sync_to_mouse()


func refresh_drag_geometry(grab_offset: Vector2i) -> void:
	shape_preview.refresh_drag_geometry(grab_offset)
	grab_visual_offset = shape_preview.position
	_sync_to_mouse()


func _sync_to_mouse() -> void:
	if not is_inside_tree():
		shape_preview.position = grab_visual_offset
		return
	shape_preview.position = get_viewport().get_mouse_position() + grab_visual_offset
