class_name UiPalette
extends RefCounted


static func attribute_color(attribute: StringName) -> Color:
	match attribute:
		ItemDefinition.ATTRIBUTE_LAMP:
			return Color("e7bb52")
		ItemDefinition.ATTRIBUTE_MIRROR:
			return Color("579dc8")
		ItemDefinition.ATTRIBUTE_FLOWER:
			return Color("d982a5")
		ItemDefinition.ATTRIBUTE_FOG:
			return Color("8b73bd")
		_:
			return Color("c7ced8")


static func attribute_name(attribute: StringName) -> String:
	match attribute:
		ItemDefinition.ATTRIBUTE_LAMP:
			return TranslationServer.translate(&"attribute.lamp")
		ItemDefinition.ATTRIBUTE_MIRROR:
			return TranslationServer.translate(&"attribute.mirror")
		ItemDefinition.ATTRIBUTE_FLOWER:
			return TranslationServer.translate(&"attribute.flower")
		ItemDefinition.ATTRIBUTE_FOG:
			return TranslationServer.translate(&"attribute.fog")
		_:
			return TranslationServer.translate(&"attribute.unknown")


static func panel_style(color: Color = Color("18212d"), border_color: Color = Color("304052")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style
