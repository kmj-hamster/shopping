class_name ItemDetailPopup
extends Control

const DETAIL_LEFT := -680.0
const DETAIL_TOP := 4.0
const DETAIL_RIGHT := -4.0
const DETAIL_BOTTOM := 166.0
const PROPERTY_GAP := 10.0
const PROPERTY_HEIGHT := 104.0
const RIGHT_POPUP_SCALE := 0.61
const TITLE_FONT_SIZE := 26
const DESCRIPTION_FONT_SIZE := 22
const DESCRIPTION_MIN_FONT_SIZE := 17
const DESCRIPTION_MAX_LINES := 3
const ITEM_SUMMARY_HEIGHT := 82
const PROPERTY_ICON_SIDE := 53
const PROPERTY_VALUE_FONT_SIZE := 36
const PROPERTY_VALUE_MIN_WIDTH := 30
const PROPERTY_ICON_VALUE_GAP := 8
const PROPERTY_GROUP_GAP := 3
const POPUP_BACKGROUND := Color("020304", 0.5)
const DEFAULT_ICON_BACKGROUND := Color.BLACK
const DEFAULT_ICON_BORDER := Color("8c7a52", 0.86)
const SHAPE_ICON_INK := Color.BLACK
const LARGE_ICON_SIDE := 78.0
const SHRUNK_SHAPE_ICON_SIDE := 70.0
const LARGE_PROPERTY_ICON_INSET := 2.0
const SHRUNK_SHAPE_PROPERTY_ICON_INSET := 6.0
const SHAPE_POPUP_ICON_PATHS := {
	&"light": "res://resources/ui/synthesis/shape/light.png",
	&"tear": "res://resources/ui/synthesis/shape/tear.png",
	&"dream": "res://resources/ui/synthesis/shape/dream.png",
	&"sleep": "res://resources/ui/synthesis/shape/sleep.png",
}
const BLACK_BACKED_PROPERTY_IDS: Array[StringName] = [
	&"food",
	&"drink",
	&"flower",
	&"plant",
	&"toy",
	&"book",
	&"cd",
	&"cassette",
	&"persona",
	&"disease",
]

var current_definition: CardItemDefinition
var primary_property_id: StringName
var selected_property_id: StringName
var detail_panel: PanelContainer
var item_frame: PanelContainer
var item_image: TextureRect
var title_label: Label
var description_label: Label
var property_band: MarginContainer
var property_row: HBoxContainer
var property_panel: PanelContainer
var property_icon_frame: PanelContainer
var property_icon_image: TextureRect
var property_icon_fallback: Label
var property_name: Label
var property_description: Label
var close_button: Button
var property_buttons: Dictionary = {}
var property_views: Dictionary = {}
var property_description_fit_queued := false
var property_description_fit_width := -1.0


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
	primary_property_id = &""
	selected_property_id = &""
	visible = true
	detail_panel.visible = true
	property_panel.visible = false
	_refresh()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func show_primary_property(property_id: StringName) -> void:
	if property_id.is_empty():
		return
	current_definition = null
	primary_property_id = property_id
	selected_property_id = &""
	visible = true
	detail_panel.visible = true
	property_panel.visible = false
	_refresh()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func close() -> void:
	visible = false
	primary_property_id = &""
	selected_property_id = &""
	detail_panel.visible = false
	property_panel.visible = false
	_update_property_button_states()


func _input(event: InputEvent) -> void:
	if not visible or property_panel == null or not property_panel.visible:
		return
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if property_panel.get_global_rect().has_point(mouse_event.position):
		return
	for raw_button in property_buttons.values():
		var button := raw_button as Button
		if button != null and button.get_global_rect().has_point(mouse_event.position):
			return
	_return_to_item()


func _build_detail_panel() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.name = "ItemDetailPanel"
	_apply_detail_anchors(detail_panel)
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_panel.add_theme_stylebox_override(
		"panel", panel_style(POPUP_BACKGROUND, Color("a58d58", 0.94), 1)
	)
	add_child(detail_panel)
	detail_panel.resized.connect(_position_property_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 7)
	detail_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.name = "ItemSummaryRow"
	top_row.custom_minimum_size = Vector2(0, ITEM_SUMMARY_HEIGHT)
	top_row.add_theme_constant_override("separation", 9)
	column.add_child(top_row)
	item_frame = PanelContainer.new()
	item_frame.custom_minimum_size = Vector2(82, 82)
	item_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var item_frame_style := _icon_frame_style(&"")
	item_frame.add_theme_stylebox_override("panel", item_frame_style)
	top_row.add_child(item_frame)
	item_image = TextureRect.new()
	item_image.custom_minimum_size = Vector2.ONE * LARGE_ICON_SIDE
	item_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_image.modulate = Color.WHITE
	item_image.self_modulate = Color.WHITE
	item_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_frame.add_child(item_image)

	var text_column := VBoxContainer.new()
	text_column.custom_minimum_size = Vector2(0, ITEM_SUMMARY_HEIGHT)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	top_row.add_child(text_column)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 22)
	text_column.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.add_theme_color_override("font_color", Color("e3c679"))
	header.add_child(title_label)
	close_button = Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(24, 22)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("a58d58", 0.90)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(divider)
	description_label = Label.new()
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.max_lines_visible = DESCRIPTION_MAX_LINES
	description_label.add_theme_font_size_override("font_size", DESCRIPTION_FONT_SIZE)
	description_label.add_theme_color_override("font_color", Color("d8ddd9"))
	text_column.add_child(description_label)

	property_band = MarginContainer.new()
	property_band.name = "PropertyBand"
	property_band.custom_minimum_size = Vector2(0, PROPERTY_ICON_SIDE + 4)
	column.add_child(property_band)
	property_band.add_theme_constant_override("margin_left", 8)
	property_band.add_theme_constant_override("margin_right", 8)
	property_band.add_theme_constant_override("margin_top", 4)
	var property_scroll := ScrollContainer.new()
	property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	property_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	property_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_band.add_child(property_scroll)
	property_row = HBoxContainer.new()
	property_row.custom_minimum_size = Vector2(0, PROPERTY_ICON_SIDE)
	property_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	property_row.add_theme_constant_override("separation", PROPERTY_GROUP_GAP)
	property_scroll.add_child(property_row)


func _build_property_panel() -> void:
	property_panel = PanelContainer.new()
	property_panel.name = "PropertyDetailPanel"
	_apply_property_anchors(property_panel)
	property_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	property_panel.add_theme_stylebox_override(
		"panel", panel_style(POPUP_BACKGROUND, Color("a58d58", 0.94), 1)
	)
	add_child(property_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 7)
	property_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 104)
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	property_icon_frame = PanelContainer.new()
	property_icon_frame.custom_minimum_size = Vector2(82, 82)
	property_icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	property_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_frame_style := _icon_frame_style(&"")
	property_icon_frame.add_theme_stylebox_override("panel", icon_frame_style)
	row.add_child(property_icon_frame)
	var icon_stack := Control.new()
	icon_stack.custom_minimum_size = Vector2(82, 82)
	property_icon_frame.add_child(icon_stack)
	property_icon_image = TextureRect.new()
	property_icon_image.anchor_right = 1.0
	property_icon_image.anchor_bottom = 1.0
	property_icon_image.offset_left = 2.0
	property_icon_image.offset_top = 2.0
	property_icon_image.offset_right = -2.0
	property_icon_image.offset_bottom = -2.0
	property_icon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	property_icon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	property_icon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(property_icon_image)
	property_icon_fallback = Label.new()
	property_icon_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	property_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	property_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	property_icon_fallback.add_theme_font_size_override("font_size", 32)
	property_icon_fallback.add_theme_color_override("font_color", Color("d8ddd9"))
	property_icon_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(property_icon_fallback)
	var text_column := VBoxContainer.new()
	text_column.custom_minimum_size = Vector2(0, 104)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	row.add_child(text_column)
	property_name = Label.new()
	property_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	property_name.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	property_name.add_theme_color_override("font_color", Color("e3c679"))
	text_column.add_child(property_name)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("a58d58", 0.90)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(divider)
	property_description = Label.new()
	property_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	property_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	property_description.max_lines_visible = DESCRIPTION_MAX_LINES
	property_description.add_theme_font_size_override("font_size", DESCRIPTION_FONT_SIZE)
	property_description.add_theme_color_override("font_color", Color("d8ddd9"))
	property_description.resized.connect(_on_property_description_resized)
	text_column.add_child(property_description)
	property_panel.visible = false
	_position_property_panel()


func _apply_detail_anchors(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = DETAIL_LEFT
	control.offset_top = DETAIL_TOP
	control.offset_right = DETAIL_RIGHT
	control.offset_bottom = DETAIL_BOTTOM


func _apply_property_anchors(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = DETAIL_LEFT
	control.offset_top = DETAIL_BOTTOM + PROPERTY_GAP
	control.offset_right = DETAIL_RIGHT
	control.offset_bottom = DETAIL_BOTTOM + PROPERTY_GAP + PROPERTY_HEIGHT


func _position_property_panel() -> void:
	if detail_panel == null or property_panel == null:
		return
	apply_right_popup_scale(detail_panel)
	var detail_height := maxf(detail_panel.size.y, detail_panel.get_combined_minimum_size().y)
	var property_height := maxf(PROPERTY_HEIGHT, property_panel.get_combined_minimum_size().y)
	var property_top := (
		detail_panel.offset_top
		+ detail_height * RIGHT_POPUP_SCALE
		+ PROPERTY_GAP * RIGHT_POPUP_SCALE
	)
	property_panel.offset_top = property_top
	property_panel.offset_bottom = property_top + property_height
	apply_right_popup_scale(property_panel)


static func apply_right_popup_scale(control: Control) -> void:
	if control == null:
		return
	control.scale = Vector2.ONE * RIGHT_POPUP_SCALE
	# Keep the transformed rectangle attached to the screen's top-right corner.
	control.pivot_offset = Vector2(control.size.x, 0.0)


func _refresh() -> void:
	if title_label == null:
		return
	if not primary_property_id.is_empty():
		_refresh_primary_property()
		return
	if current_definition == null:
		return
	title_label.text = current_definition.localized_name()
	description_label.text = current_definition.localized_description()
	description_label.add_theme_font_size_override("font_size", DESCRIPTION_FONT_SIZE)
	close_button.tooltip_text = TranslationServer.translate(&"slot.item_detail.close")
	item_image.texture = popup_item_texture(current_definition)
	var shape_id := _definition_shape_id(current_definition)
	item_image.self_modulate = SHAPE_ICON_INK if not shape_id.is_empty() else Color.WHITE
	_apply_large_item_icon_layout(shape_id)
	item_frame.add_theme_stylebox_override("panel", _icon_frame_style(shape_id))
	item_frame.visible = item_image.texture != null
	property_band.visible = (
		current_definition.property_set != null
		and current_definition.property_set.property_count() > 0
	)
	_rebuild_properties()
	_position_property_panel()
	call_deferred("_fit_description_font")
	if not selected_property_id.is_empty():
		_update_property_panel(selected_property_id)


func _refresh_primary_property() -> void:
	title_label.text = TranslationServer.translate(property_name_key(primary_property_id))
	description_label.text = TranslationServer.translate(
		property_description_key(primary_property_id)
	)
	description_label.add_theme_font_size_override("font_size", DESCRIPTION_FONT_SIZE)
	close_button.tooltip_text = TranslationServer.translate(&"slot.item_detail.close")
	item_image.texture = popup_property_icon_texture(primary_property_id)
	item_image.self_modulate = (
		SHAPE_ICON_INK if _is_shape_id(primary_property_id) else Color.WHITE
	)
	_apply_large_item_icon_layout(primary_property_id)
	item_frame.add_theme_stylebox_override(
		"panel", _icon_frame_style(primary_property_id)
	)
	item_frame.visible = item_image.texture != null
	property_band.visible = false
	property_panel.visible = false
	_position_property_panel()
	call_deferred("_fit_description_font")


func _fit_description_font() -> void:
	if description_label == null or not is_instance_valid(description_label):
		return
	fit_label_font(
		description_label,
		DESCRIPTION_FONT_SIZE,
		DESCRIPTION_MIN_FONT_SIZE,
		DESCRIPTION_MAX_LINES,
	)
	_position_property_panel()
	call_deferred("_position_property_panel")


static func fit_label_font(
	label: Label,
	default_font_size: int,
	minimum_font_size: int,
	maximum_lines: int,
) -> void:
	if label == null or not is_instance_valid(label):
		return
	var font_size := default_font_size
	label.add_theme_font_size_override("font_size", font_size)
	if label.size.x <= 1.0:
		return
	while font_size > minimum_font_size and label.get_line_count() > maximum_lines:
		font_size -= 1
		label.add_theme_font_size_override("font_size", font_size)


func _rebuild_properties() -> void:
	for raw_view in property_views.values():
		var cached_view := raw_view as Dictionary
		(cached_view.root as Control).visible = false
	property_buttons.clear()
	if current_definition.property_set == null:
		return
	var tags := _ordered_property_tags(current_definition.property_set)
	for index in range(tags.size()):
		var tag := StringName(tags[index])
		var view := _ensure_property_view(tag)
		var root := view.root as HBoxContainer
		var icon := view.button as Button
		var value := view.value as Label
		root.visible = true
		icon.tooltip_text = TranslationServer.translate(property_name_key(tag))
		property_buttons[tag] = icon
		var amount := current_definition.property_value(tag)
		value.text = str(amount)
		value.visible = amount > 0
		if root.get_index() != index:
			property_row.move_child(root, index)
	_update_property_button_states()


func _ensure_property_view(tag: StringName) -> Dictionary:
	if property_views.has(tag):
		return property_views[tag] as Dictionary
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", PROPERTY_ICON_VALUE_GAP)
	property_row.add_child(root)
	var icon := make_property_icon_button(tag, PROPERTY_ICON_SIDE)
	icon.pressed.connect(_show_property.bind(tag))
	root.add_child(icon)
	var value := Label.new()
	value.custom_minimum_size = Vector2(PROPERTY_VALUE_MIN_WIDTH, PROPERTY_ICON_SIDE)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", PROPERTY_VALUE_FONT_SIZE)
	value.add_theme_color_override("font_color", Color("e7dcc0"))
	root.add_child(value)
	var view := {
		"root": root,
		"button": icon,
		"value": value,
	}
	property_views[tag] = view
	return view


func _ordered_property_tags(properties: CardPropertySet) -> Array[StringName]:
	var result: Array[StringName] = []
	for shape_id in CardPropertySet.SHAPES:
		if properties.has(shape_id) or properties.values.has(shape_id):
			result.append(shape_id)
	var remaining: Array[StringName] = []
	for raw_tag in properties.property_ids():
		var tag := StringName(raw_tag)
		if tag not in CardPropertySet.SHAPES and properties.has(tag):
			remaining.append(tag)
	remaining.sort()
	result.append_array(remaining)
	return result


func _show_property(tag: StringName) -> void:
	if property_panel.visible and selected_property_id == tag:
		_return_to_item()
		return
	selected_property_id = tag
	_update_property_panel(tag)
	detail_panel.visible = true
	property_panel.visible = true
	_queue_property_description_font_fit()
	_position_property_panel()
	call_deferred("_position_property_panel")
	_update_property_button_states()


func _update_property_panel(tag: StringName) -> void:
	var texture := popup_property_icon_texture(tag)
	property_icon_image.texture = texture
	property_icon_image.self_modulate = SHAPE_ICON_INK if _is_shape_id(tag) else Color.WHITE
	_apply_large_property_icon_layout(tag)
	property_icon_frame.add_theme_stylebox_override("panel", _icon_frame_style(tag))
	property_icon_image.visible = texture != null
	property_icon_fallback.text = property_symbol(tag)
	property_icon_fallback.visible = texture == null
	property_name.text = TranslationServer.translate(property_name_key(tag))
	property_description.text = TranslationServer.translate(property_description_key(tag))
	property_description.add_theme_font_size_override("font_size", DESCRIPTION_FONT_SIZE)
	property_description_fit_width = -1.0
	_queue_property_description_font_fit()


func _queue_property_description_font_fit() -> void:
	if property_description_fit_queued:
		return
	property_description_fit_queued = true
	_fit_property_description_after_layout()


func _apply_large_item_icon_layout(shape_id: StringName) -> void:
	var should_shrink := _should_shrink_large_shape_icon(shape_id)
	item_image.custom_minimum_size = Vector2.ONE * (
		SHRUNK_SHAPE_ICON_SIDE if should_shrink else LARGE_ICON_SIDE
	)
	item_image.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if should_shrink else Control.SIZE_FILL
	)
	item_image.size_flags_vertical = (
		Control.SIZE_SHRINK_CENTER if should_shrink else Control.SIZE_FILL
	)


func _apply_large_property_icon_layout(shape_id: StringName) -> void:
	var inset := (
		SHRUNK_SHAPE_PROPERTY_ICON_INSET
		if _should_shrink_large_shape_icon(shape_id)
		else LARGE_PROPERTY_ICON_INSET
	)
	property_icon_image.offset_left = inset
	property_icon_image.offset_top = inset
	property_icon_image.offset_right = -inset
	property_icon_image.offset_bottom = -inset


static func _should_shrink_large_shape_icon(shape_id: StringName) -> bool:
	return _is_shape_id(shape_id) and shape_id != CardPropertySet.SHAPE_DREAM


func _fit_property_description_after_layout() -> void:
	await get_tree().process_frame
	property_description_fit_queued = false
	_fit_property_description_font()


func _on_property_description_resized() -> void:
	if (
		property_panel == null
		or not property_panel.visible
		or is_equal_approx(property_description.size.x, property_description_fit_width)
	):
		return
	_queue_property_description_font_fit()


func _fit_property_description_font() -> void:
	if property_panel == null or not property_panel.visible or property_description.size.x <= 1.0:
		return
	property_description_fit_width = property_description.size.x
	fit_label_font(
		property_description,
		DESCRIPTION_FONT_SIZE,
		DESCRIPTION_MIN_FONT_SIZE,
		DESCRIPTION_MAX_LINES,
	)
	_position_property_panel()
	call_deferred("_position_property_panel")


func _return_to_item() -> void:
	selected_property_id = &""
	property_panel.visible = false
	detail_panel.visible = true
	_update_property_button_states()


func _update_property_button_states() -> void:
	for raw_tag in property_buttons:
		var tag := StringName(raw_tag)
		var button := property_buttons[raw_tag] as Button
		if button != null:
			button.button_pressed = property_panel.visible and selected_property_id == tag


static func make_property_icon_button(tag: StringName, side: int = 30) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	var texture := popup_property_icon_texture(tag)
	button.text = "" if texture != null else property_symbol(tag)
	button.tooltip_text = TranslationServer.translate(property_name_key(tag))
	button.add_theme_font_size_override("font_size", maxi(13, int(side / 2)))
	button.add_theme_color_override("font_color", UiPalette.INK_COLOR)
	var is_shape := _is_shape_id(tag)
	var uses_black_background := tag in BLACK_BACKED_PROPERTY_IDS
	var normal_color := (
		ShapeVisuals.color(tag)
		if is_shape
		else (Color.BLACK if uses_black_background else Color("f1eee5"))
	)
	var normal_border := Color("101315", 0.72) if is_shape else Color("8c7a52")
	button.add_theme_stylebox_override("normal", panel_style(normal_color, normal_border, 1))
	button.add_theme_stylebox_override(
		"hover",
		panel_style(normal_color.lightened(0.12), normal_border.lightened(0.20), 2),
	)
	button.add_theme_stylebox_override(
		"pressed",
		panel_style(normal_color.lightened(0.06), normal_border.lightened(0.12), 2),
	)
	if texture != null:
		var icon_inset := 2.0 if uses_black_background else 4.0
		var icon_image := TextureRect.new()
		icon_image.texture = texture
		icon_image.anchor_right = 1.0
		icon_image.anchor_bottom = 1.0
		icon_image.offset_left = icon_inset
		icon_image.offset_top = icon_inset
		icon_image.offset_right = -icon_inset
		icon_image.offset_bottom = -icon_inset
		icon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_image.self_modulate = SHAPE_ICON_INK if is_shape else Color.WHITE
		button.add_child(icon_image)
	return button


static func _is_shape_id(property_id: StringName) -> bool:
	return property_id in CardPropertySet.SHAPES


static func _definition_shape_id(definition: CardItemDefinition) -> StringName:
	if (
		definition == null
		or definition.property_set == null
		or not definition.property_set.has(CardPropertySet.PROPERTY_PERSONA)
	):
		return &""
	for shape_id in CardPropertySet.SHAPES:
		if (
			definition.property_set.has(shape_id)
			or definition.property_set.values.has(shape_id)
		):
			return shape_id
	return &""


static func _icon_frame_style(shape_id: StringName) -> StyleBoxFlat:
	var is_shape := _is_shape_id(shape_id)
	var style := panel_style(
		ShapeVisuals.color(shape_id) if is_shape else DEFAULT_ICON_BACKGROUND,
		Color("101315", 0.72) if is_shape else DEFAULT_ICON_BORDER,
		1,
	)
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


static func property_name_key(tag: StringName) -> StringName:
	var property := QuestArcCatalog.property_by_id(tag)
	return property.display_name_key if property != null else StringName("slot.property.%s" % tag)


static func property_description_key(tag: StringName) -> StringName:
	var property := QuestArcCatalog.property_by_id(tag)
	return property.description_key if property != null else StringName("slot.property.%s.description" % tag)


static func property_icon_texture(tag: StringName) -> Texture2D:
	var paths := {
		&"food": "res://resources/ui/type/food.png",
		&"salty": "res://resources/ui/property-salty.png",
		&"light": "res://resources/ui/shape/light.png",
		&"tear": "res://resources/ui/shape/tear.png",
		&"dream": "res://resources/ui/shape/dream.png",
		&"sleep": "res://resources/ui/shape/sleep.png",
		&"plant": "res://resources/ui/type/flower.png",
		&"flower": "res://resources/ui/type/flower.png",
		&"rose": "res://resources/item-midnight-rose.svg",
		&"toy": "res://resources/ui/type/toy.png",
		&"teddy_bear": "res://resources/item-worn-teddy.svg",
		&"drink": "res://resources/ui/type/drink.png",
		&"book": "res://resources/ui/type/book.png",
		&"cd": "res://resources/ui/type/cassette.png",
		&"cassette": "res://resources/ui/type/cassette.png",
		&"disease": "res://resources/ui/type/disease.png",
		&"tool": "res://resources/ui/property-tool.png",
		&"persona": "res://resources/ui/type/persona.png",
	}
	var path := String(paths.get(tag, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


static func popup_property_icon_texture(tag: StringName) -> Texture2D:
	var path := String(SHAPE_POPUP_ICON_PATHS.get(tag, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return property_icon_texture(tag)


static func popup_item_texture(definition: CardItemDefinition) -> Texture2D:
	if (
		definition != null
		and definition.property_set != null
		and definition.property_set.has(CardPropertySet.PROPERTY_PERSONA)
	):
		for shape_id in CardPropertySet.SHAPES:
			if (
				definition.property_set.has(shape_id)
				or definition.property_set.values.has(shape_id)
			):
				return popup_property_icon_texture(shape_id)
	return definition.image if definition != null else null


static func property_symbol(tag: StringName) -> String:
	var symbols := {
		&"light": "✦",
		&"tear": "◇",
		&"dream": "▽",
		&"sleep": "▱",
		&"food": "●",
		&"salty": "≋",
		&"plant": "♧",
		&"flower": "♧",
		&"rose": "✿",
		&"toy": "□",
		&"book": "▤",
		&"cd": "◎",
		&"cassette": "▰",
		&"candle": "♨",
		&"clothing": "⌑",
		&"disease": "✚",
		&"keepsake": "◈",
		&"teddy_bear": "⌁",
		&"drink": "∪",
		&"metal": "◆",
		&"tool": "×",
		&"persona": "◐",
	}
	return String(symbols.get(tag, "·"))


static func panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := UiPalette.panel_style(color, border_color)
	style.set_border_width_all(border_width)
	return style


func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh()
