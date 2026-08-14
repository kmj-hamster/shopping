class_name UiPalette
extends RefCounted

const INK_COLOR := Color("152421")


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


static func round_button_style(
	color: Color,
	border_color: Color,
	radius: int,
) -> StyleBoxFlat:
	var style := panel_style(color, border_color)
	style.set_border_width_all(2)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


static func paper_style() -> StyleBoxFlat:
	var style := panel_style(Color("d7cfb6", 0.98), Color("887757", 0.92))
	style.set_border_width_all(2)
	style.shadow_color = Color("000000", 0.32)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style
