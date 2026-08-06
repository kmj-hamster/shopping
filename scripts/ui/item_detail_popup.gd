class_name ItemDetailPopup
extends Control

var current_definition: CardItemDefinition
var detail_panel: PanelContainer
var item_image: TextureRect
var image_placeholder: Label
var title_label: Label
var description_label: Label
var property_row: HBoxContainer
var property_badges: Dictionary = {}
var property_popup: PanelContainer
var property_popup_icon: Label
var property_popup_name: Label
var property_popup_description: Label
var close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	visible = false


func show_item(definition: CardItemDefinition) -> void:
	if definition == null:
		return
	current_definition = definition
	visible = true
	property_popup.visible = false
	_refresh()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func close() -> void:
	visible = false
	property_popup.visible = false


func _build_interface() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.name = "ItemDetailPanel"
	detail_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	detail_panel.offset_left = -660
	detail_panel.offset_top = 16
	detail_panel.offset_right = -16
	detail_panel.offset_bottom = 246
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("070b0e", 0.98), Color("8d7a4e", 0.94), 2)
	)
	add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		detail_margin.add_theme_constant_override("margin_%s" % side, 12)
	detail_panel.add_child(detail_margin)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 14)
	detail_margin.add_child(detail_row)

	var image_panel := PanelContainer.new()
	image_panel.name = "ItemImagePanel"
	image_panel.custom_minimum_size = Vector2(176, 0)
	image_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("101b1e", 0.98), Color("687a72", 0.9))
	)
	detail_row.add_child(image_panel)
	var image_stack := Control.new()
	image_stack.custom_minimum_size = Vector2(152, 182)
	image_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_panel.add_child(image_stack)
	item_image = TextureRect.new()
	item_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_stack.add_child(item_image)
	image_placeholder = Label.new()
	image_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	image_placeholder.add_theme_font_size_override("font_size", 52)
	image_placeholder.add_theme_color_override("font_color", Color("d3bd7d"))
	image_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_stack.add_child(image_placeholder)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 7)
	detail_row.add_child(text_column)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 34)
	text_column.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color("d6bd77"))
	header.add_child(title_label)
	close_button = Button.new()
	close_button.name = "ItemDetailCloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color("9f8955", 0.88)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(divider)
	description_label = Label.new()
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_color_override("font_color", Color("c2c9c3"))
	text_column.add_child(description_label)
	var property_scroll := ScrollContainer.new()
	property_scroll.custom_minimum_size = Vector2(0, 56)
	property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	property_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_column.add_child(property_scroll)
	property_row = HBoxContainer.new()
	property_row.add_theme_constant_override("separation", 8)
	property_scroll.add_child(property_row)

	property_popup = PanelContainer.new()
	property_popup.name = "PropertyDetailPanel"
	property_popup.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	property_popup.offset_left = -660
	property_popup.offset_top = 256
	property_popup.offset_right = -16
	property_popup.offset_bottom = 380
	property_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	property_popup.add_theme_stylebox_override(
		"panel", _panel_style(Color("070b0e", 0.985), Color("8d7a4e", 0.9), 2)
	)
	add_child(property_popup)
	var popup_margin := MarginContainer.new()
	popup_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		popup_margin.add_theme_constant_override("margin_%s" % side, 12)
	property_popup.add_child(popup_margin)
	var popup_row := HBoxContainer.new()
	popup_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_row.add_theme_constant_override("separation", 14)
	popup_margin.add_child(popup_row)
	var popup_icon_panel := PanelContainer.new()
	popup_icon_panel.custom_minimum_size = Vector2(86, 86)
	popup_icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_icon_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("152225", 0.98), Color("9f8955", 0.9))
	)
	popup_row.add_child(popup_icon_panel)
	property_popup_icon = Label.new()
	property_popup_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	property_popup_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	property_popup_icon.add_theme_font_size_override("font_size", 34)
	property_popup_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_icon_panel.add_child(property_popup_icon)
	var popup_text := VBoxContainer.new()
	popup_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_row.add_child(popup_text)
	property_popup_name = Label.new()
	property_popup_name.add_theme_font_size_override("font_size", 19)
	property_popup_name.add_theme_color_override("font_color", Color("d6bd77"))
	property_popup_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_text.add_child(property_popup_name)
	property_popup_description = Label.new()
	property_popup_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	property_popup_description.add_theme_font_size_override("font_size", 13)
	property_popup_description.add_theme_color_override("font_color", Color("bac4be"))
	property_popup_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_text.add_child(property_popup_description)
	property_popup.visible = false


func _refresh() -> void:
	if current_definition == null or title_label == null:
		return
	title_label.text = current_definition.localized_name()
	description_label.text = current_definition.localized_description()
	close_button.tooltip_text = TranslationServer.translate(&"slot.item_detail.close")
	item_image.texture = current_definition.image
	item_image.visible = current_definition.image != null
	image_placeholder.visible = current_definition.image == null
	image_placeholder.text = current_definition.localized_name().left(1)
	_rebuild_properties()


func _rebuild_properties() -> void:
	for child in property_row.get_children():
		child.free()
	property_badges.clear()
	if current_definition.property_set == null:
		return
	for tag in _ordered_property_tags(current_definition.property_set):
		var holder := HBoxContainer.new()
		holder.add_theme_constant_override("separation", 4)
		property_row.add_child(holder)
		var icon := Button.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.focus_mode = Control.FOCUS_NONE
		icon.text = _property_symbol(tag)
		icon.add_theme_font_size_override("font_size", 20)
		icon.add_theme_stylebox_override(
			"normal", _panel_style(Color("11191d", 0.98), _property_color(tag), 2)
		)
		icon.add_theme_stylebox_override(
			"hover", _panel_style(Color("1d292c", 0.99), _property_color(tag), 3)
		)
		icon.mouse_entered.connect(_show_property_tooltip.bind(tag))
		icon.mouse_exited.connect(_hide_property_tooltip)
		holder.add_child(icon)
		var value := Label.new()
		value.text = str(current_definition.property_value(tag))
		value.visible = current_definition.property_value(tag) > 0
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 16)
		value.add_theme_color_override("font_color", Color("d9d0b4"))
		holder.add_child(value)
		property_badges[tag] = icon


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


func _show_property_tooltip(tag: StringName) -> void:
	property_popup_icon.text = _property_symbol(tag)
	property_popup_icon.add_theme_color_override("font_color", _property_color(tag))
	property_popup_name.text = TranslationServer.translate(_property_name_key(tag))
	property_popup_description.text = TranslationServer.translate(_property_description_key(tag))
	property_popup.visible = true


func _hide_property_tooltip() -> void:
	property_popup.visible = false


func _property_name_key(tag: StringName) -> StringName:
	var quest_property := (
		QuestArcCatalog.property_by_id(tag)
		if current_definition is QuestItemDefinition
		else null
	)
	if quest_property != null:
		return quest_property.display_name_key
	var prefix := "slot.aspect" if tag in CardPropertySet.ASPECTS else "slot.property"
	return StringName("%s.%s" % [prefix, tag])


func _property_description_key(tag: StringName) -> StringName:
	var quest_property := (
		QuestArcCatalog.property_by_id(tag)
		if current_definition is QuestItemDefinition
		else null
	)
	if quest_property != null:
		return quest_property.description_key
	return StringName("%s.description" % _property_name_key(tag))


func _property_symbol(tag: StringName) -> String:
	var symbols := {
		&"lamp": "✦", &"mirror": "◇", &"candle": "∿", &"pillow": "⌒",
		&"reading": "▤", &"memory": "◫", &"relaxing": "≈", &"dreamlike": "☾",
		&"music": "♪", &"sleep_aid": "z", &"stimulating": "!", &"electric": "⌁",
		&"plant": "♧", &"warm": "☼", &"soft": "≈", &"toy": "◇",
		&"fragile": "!", &"food": "●", &"drink": "∪", &"sweet": "◆",
		&"crispy": "≋", &"teddy": "⌁", &"alcohol": "△",
	}
	return String(symbols.get(tag, "·"))


func _property_color(tag: StringName) -> Color:
	match tag:
		CardPropertySet.ASPECT_LAMP:
			return Color("e4c34f")
		CardPropertySet.ASPECT_MIRROR:
			return Color("70aeca")
		CardPropertySet.ASPECT_CANDLE:
			return Color("a37ac5")
		CardPropertySet.ASPECT_PILLOW:
			return Color("ca88a5")
	var hue := float(absi(String(tag).hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.38, 0.82)


func _panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := UiPalette.panel_style(color, border_color)
	style.set_border_width_all(border_width)
	return style


func _on_locale_changed(_locale: String) -> void:
	if visible:
		property_popup.visible = false
		_refresh()
