class_name ItemDefinition
extends Resource

const ATTRIBUTE_LAMP := &"lamp"
const ATTRIBUTE_MIRROR := &"mirror"
const ATTRIBUTE_FLOWER := &"flower"
const ATTRIBUTE_FOG := &"fog"

@export var id: StringName
@export var display_name_key: StringName
@export var store_id: StringName
@export var shape_code: StringName
@export var shape_cells: Array[Vector2i] = [Vector2i.ZERO]
@export var attribute: StringName = ATTRIBUTE_FOG
@export var price: int = 10
@export var daily_limit: int = 1
@export var is_special: bool = false


func cells_at_rotation(rotation_steps: int) -> Array[Vector2i]:
	return PolyominoGeometry.rotated(shape_cells, rotation_steps)


func cell_count() -> int:
	return shape_cells.size()


func localized_name() -> String:
	return TranslationServer.translate(display_name_key)
