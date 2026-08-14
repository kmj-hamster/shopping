class_name PersonaVisuals
extends RefCounted

const COLORS := {
	CardPropertySet.PERSONA_NIGHTWALKER: Color("f2d14f"),
	CardPropertySet.PERSONA_MOURNER: Color("6faed9"),
	CardPropertySet.PERSONA_DREAMWALKER: Color("f3c6d6"),
	CardPropertySet.PERSONA_HOMECOMER: Color("9a78c5"),
}
const SYMBOL_TEXTURES := {
	CardPropertySet.PERSONA_NIGHTWALKER: preload(
		"res://resources/ui/persona/nightwalker.png"
	),
	CardPropertySet.PERSONA_MOURNER: preload("res://resources/ui/persona/mourner.png"),
	CardPropertySet.PERSONA_DREAMWALKER: preload(
		"res://resources/ui/persona/dreamwalker.png"
	),
	CardPropertySet.PERSONA_HOMECOMER: preload("res://resources/ui/persona/homecomer.png"),
}


static func color(persona_id: StringName) -> Color:
	return COLORS.get(persona_id, Color("dce7ef")) as Color


static func symbol_texture(persona_id: StringName) -> Texture2D:
	return SYMBOL_TEXTURES.get(persona_id) as Texture2D
