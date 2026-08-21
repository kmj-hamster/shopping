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


static func rebuild_persona_growth_rows(
	container: VBoxContainer,
	growth: Dictionary,
	font_size := 20,
) -> int:
	if container == null:
		return 0
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var row_count := 0
	for shape_id in CardPropertySet.SHAPES:
		var amount := int(growth.get(shape_id, 0))
		if amount <= 0:
			continue
		var name_key := StringName(PersonaCardCatalog.PERSONA_NAME_KEYS.get(shape_id, &""))
		var persona_name := TranslationServer.translate(name_key)
		var label := Label.new()
		label.name = "PersonaGrowth%s" % String(shape_id).capitalize()
		label.text = TranslationServer.translate(&"demo.ui.arc.stat_reward") % [
			persona_name,
			amount,
		]
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color(shape_id))
		container.add_child(label)
		row_count += 1
	container.visible = row_count > 0
	return row_count
