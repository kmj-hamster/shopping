class_name TaskDefinition
extends Resource

enum AttributeRule {
	NONE,
	MIRROR_STRICT,
	LAMP_OR_FLOWER,
}

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var mask_cells: Array[Vector2i]
@export var required_special_item_id: StringName
@export var submit_store_id: StringName
@export var attribute_rule: AttributeRule = AttributeRule.NONE
@export var accepts_any_item := false


func bounds_size() -> Vector2i:
	return PolyominoGeometry.bounds_size(mask_cells)


func has_cell(cell: Vector2i) -> bool:
	return cell in mask_cells


func localized_name() -> String:
	return TranslationServer.translate(display_name_key)


func localized_description() -> String:
	return TranslationServer.translate(description_key)
