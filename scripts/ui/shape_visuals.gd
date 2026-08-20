class_name ShapeVisuals
extends RefCounted

const COLORS := {
	CardPropertySet.SHAPE_LIGHT: Color("f2d14f"),
	CardPropertySet.SHAPE_TEAR: Color("6faed9"),
	CardPropertySet.SHAPE_DREAM: Color("9a78c5"),
	CardPropertySet.SHAPE_SLEEP: Color("f3c6d6"),
}
const SYMBOL_TEXTURES := {
	CardPropertySet.SHAPE_LIGHT: preload(
		"res://resources/ui/synthesis/shape/light.png"
	),
	CardPropertySet.SHAPE_TEAR: preload(
		"res://resources/ui/synthesis/shape/tear.png"
	),
	CardPropertySet.SHAPE_DREAM: preload(
		"res://resources/ui/synthesis/shape/dream.png"
	),
	CardPropertySet.SHAPE_SLEEP: preload(
		"res://resources/ui/synthesis/shape/sleep.png"
	),
}


static func color(shape_id: StringName) -> Color:
	return COLORS.get(shape_id, Color("dce7ef")) as Color


static func symbol_texture(shape_id: StringName) -> Texture2D:
	return SYMBOL_TEXTURES.get(shape_id) as Texture2D
