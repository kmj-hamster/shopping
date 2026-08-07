class_name ItemDetailPopup
extends Control

const DETAIL_LEFT := -280.0
const DETAIL_TOP := 4.0
const DETAIL_RIGHT := -4.0
const DETAIL_BOTTOM := 99.0
const PROPERTY_TOP := 103.0
const PROPERTY_BOTTOM := 195.0

var current_definition: CardItemDefinition
var selected_property_id: StringName
var detail_panel: PanelContainer
var item_image: TextureRect
var title_label: Label
var description_label: Label
var property_row: HBoxContainer
var property_panel: PanelContainer
var property_icon_image: TextureRect
var property_icon_fallback: Label
var property_name: Label
var property_description: Label
var close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_detail_panel()
	_build_property_panel()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	visible = false


func show_item(definition: CardItemDefinition) -> void:
	if definition == null:
		return
	current_definition = definition
	selected_property_id = &""
	visible = true
	detail_panel.visible = true
	property_panel.visible = false
	_refresh()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func close() -> void:
	visible = false
	selected_property_id = &""
	detail_panel.visible = false
	property_panel.visible = false


func _build_detail_panel() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.name = "ItemDetailPanel"
	_apply_detail_anchors(detail_panel)
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("040607", 0.985), Color("a58d58", 0.92), 1)
	)
	add_child(detail_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 6)
	detail_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	item_image = TextureRect.new()
	item_image.custom_minimum_size = Vector2(76, 76)
	item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(item_image)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 18)
	text_column.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color("e3c679"))
	header.add_child(title_label)
	close_button = Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(20, 18)
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("a58d58", 0.84)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(divider)
	description_label = Label.new()
	description_label.custom_minimum_size = Vector2(0, 25)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.max_lines_visible = 2
	description_label.add_theme_font_size_override("font_size", 10)
	description_label.add_theme_color_override("font_color", Color("d6dbd7"))
	text_column.add_child(description_label)

	var property_band := PanelContainer.new()
	property_band.custom_minimum_size = Vector2(0, 24)
	property_band.add_theme_stylebox_override(
		"panel", _panel_style(Color("111416", 0.97), Color("81734f", 0.74), 1)
	)
	text_column.add_child(property_band)
	var property_scroll := ScrollContainer.new()
	property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	property_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	property_band.add_child(property_scroll)
	property_row = HBoxContainer.new()
	property_row.add_theme_constant_override("separation", 3)
	property_scroll.add_child(property_row)


func _build_property_panel() -> void:
	property_panel = PanelContainer.new()
	property_panel.name = "PropertyDetailPanel"
	_apply_property_anchors(property_panel)
	property_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	property_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("040607", 0.985), Color("a58d58", 0.92), 1)
	)
	add_child(property_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 7)
	property_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(66, 66)
	icon_frame.add_theme_stylebox_override(
		"panel", _panel_style(Color("f1eee5"), Color("a58d58"), 1)
	)
	row.add_child(icon_frame)
	var icon_stack := Control.new()
	icon_stack.custom_minimum_size = Vector2(64, 64)
	icon_frame.add_child(icon_stack)
	property_icon_image = TextureRect.new()
	property_icon_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	property_icon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	property_icon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	property_icon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(property_icon_image)
	property_icon_fallback = Label.new()
	property_icon_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	property_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	property_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	property_icon_fallback.add_theme_font_size_override("font_size", 28)
	property_icon_fallback.add_theme_color_override("font_color", Color("141718"))
	property_icon_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(property_icon_fallback)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 3)
	row.add_child(text_column)
	property_name = Label.new()
	property_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	property_name.add_theme_font_size_override("font_size", 14)
	property_name.add_theme_color_override("font_color", Color("e3c679"))
	text_column.add_child(property_name)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("a58d58", 0.84)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(divider)
	property_description = Label.new()
	property_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	property_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	property_description.max_lines_visible = 3
	property_description.add_theme_font_size_override("font_size", 10)
	property_description.add_theme_color_override("font_color", Color("d6dbd7"))
	text_column.add_child(property_description)
	property_panel.visible = false


func _apply_detail_anchors(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = DETAIL_LEFT
	control.offset_top = DETAIL_TOP
	control.offset_right = DETAIL_RIGHT
	control.offset_bottom = DETAIL_BOTTOM


func _apply_property_anchors(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = DETAIL_LEFT
	control.offset_top = PROPERTY_TOP
	control.offset_right = DETAIL_RIGHT
	control.offset_bottom = PROPERTY_BOTTOM


func _refresh() -> void:
	if current_definition == null or title_label == null:
		return
	title_label.text = current_definition.localized_name()
	description_label.text = current_definition.localized_description()
	close_button.tooltip_text = TranslationServer.translate(&"slot.item_detail.close")
	item_image.texture = current_definition.image
	_rebuild_properties()
	if not selected_property_id.is_empty():
		_update_property_panel(selected_property_id)


func _rebuild_properties() -> void:
	for child in property_row.get_children():
		child.free()
	if current_definition.property_set == null:
		return
	var tags := _ordered_property_tags(current_definition.property_set)
	for index in range(tags.size()):
		var tag := tags[index]
		if index > 0:
			var separator := Label.new()
			separator.text = "◆"
			separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			separator.add_theme_font_size_override("font_size", 6)
			separator.add_theme_color_override("font_color", Color("b69b5d"))
			property_row.add_child(separator)
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.focus_mode = Control.FOCUS_NONE
		icon.icon = _property_icon_texture(tag)
		icon.expand_icon = true
		icon.text = "" if icon.icon != null else _property_symbol(tag)
		icon.tooltip_text = TranslationServer.translate(_property_name_key(tag))
		icon.add_theme_font_size_override("font_size", 13)
		icon.add_theme_color_override("font_color", Color("151819"))
		icon.add_theme_stylebox_override(
			"normal", _panel_style(Color("f1eee5"), Color("8c7a52"), 1)
		)
		icon.add_theme_stylebox_override(
			"hover", _panel_style(Color("fff9e8"), Color("d4b76e"), 2)
		)
		icon.pressed.connect(_show_property.bind(tag))
		property_row.add_child(icon)
		var amount := current_definition.property_value(tag)
		if amount > 0:
			var value := Label.new()
			value.text = str(amount)
			value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			value.add_theme_font_size_override("font_size", 11)
			value.add_theme_color_override("font_color", Color("e7dcc0"))
			property_row.add_child(value)


func _ordered_property_tags(properties: CardPropertySet) -> Array[StringName]:
	var result: Array[StringName] = []
	for aspect in CardPropertySet.ASPECTS:
		if properties.has(aspect):
			result.append(aspect)
	var remaining: Array[StringName] = []
	for raw_tag in properties.property_ids():
		var tag := StringName(raw_tag)
		if tag not in CardPropertySet.ASPECTS and properties.has(tag):
			remaining.append(tag)
	remaining.sort()
	result.append_array(remaining)
	return result


func _show_property(tag: StringName) -> void:
	selected_property_id = tag
	_update_property_panel(tag)
	detail_panel.visible = true
	property_panel.visible = true


func _update_property_panel(tag: StringName) -> void:
	var texture := _property_icon_texture(tag)
	property_icon_image.texture = texture
	property_icon_image.visible = texture != null
	property_icon_fallback.text = _property_symbol(tag)
	property_icon_fallback.visible = texture == null
	property_name.text = TranslationServer.translate(_property_name_key(tag))
	property_description.text = TranslationServer.translate(_property_description_key(tag))


func _return_to_item() -> void:
	selected_property_id = &""
	property_panel.visible = false
	detail_panel.visible = true


func _property_name_key(tag: StringName) -> StringName:
	var property := QuestArcCatalog.property_by_id(tag)
	return property.display_name_key if property != null else StringName("slot.property.%s" % tag)


func _property_description_key(tag: StringName) -> StringName:
	var property := QuestArcCatalog.property_by_id(tag)
	return property.description_key if property != null else StringName("slot.property.%s.description" % tag)


func _property_icon_texture(tag: StringName) -> Texture2D:
	var paths := {
		&"lamp": "res://resources/ui/property-lamp.png",
		&"plant": "res://resources/ui/property-plant.png",
		&"drink": "res://resources/ui/property-drink.png",
		&"tool": "res://resources/ui/property-tool.png",
	}
	var path := String(paths.get(tag, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _property_symbol(tag: StringName) -> String:
	var symbols := {
		&"lamp": "✦",
		&"mirror": "◇",
		&"food": "●",
		&"salty": "≋",
		&"plant": "♧",
		&"drink": "∪",
		&"metal": "◆",
		&"tool": "×",
	}
	return String(symbols.get(tag, "·"))


func _panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := UiPalette.panel_style(color, border_color)
	style.set_border_width_all(border_width)
	return style


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh()
