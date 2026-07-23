class_name PieceCard
extends PanelContainer

var definition: ItemDefinition
var available := true
var drag_cell_size := 56.0
var shape_preview: ShapePreview
var title_label: Label
var detail_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(138, 116)
	_update_card_style()

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	add_child(column)

	var preview_center := CenterContainer.new()
	preview_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_center.custom_minimum_size = Vector2(126, 62)
	column.add_child(preview_center)

	shape_preview = ShapePreview.new()
	shape_preview.custom_minimum_size = Vector2(118, 60)
	shape_preview.cell_size = 12.0
	preview_center.add_child(shape_preview)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 14)
	column.add_child(title_label)

	detail_label = Label.new()
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 11)
	detail_label.add_theme_color_override("font_color", Color("aebccc"))
	column.add_child(detail_label)
	_refresh()


func setup(value: ItemDefinition, is_available: bool = true, target_cell_size: float = 56.0) -> void:
	definition = value
	available = is_available
	drag_cell_size = target_cell_size
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if definition == null or shape_preview == null:
		return
	var display_piece := PuzzlePieceState.new(-1, definition)
	shape_preview.set_piece(display_piece)
	var prefix := "★ " if definition.is_special else ""
	title_label.text = prefix + definition.localized_name()
	var detail_key := &"ui.item.special_detail" if definition.is_special else &"ui.item.palette_detail"
	detail_label.text = TranslationServer.translate(detail_key) % [
		definition.shape_code,
		UiPalette.attribute_name(definition.attribute),
		definition.cell_count(),
	]
	tooltip_text = TranslationServer.translate(
		&"ui.item.tooltip" if available else &"ui.item.special_placed"
	)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN
	modulate = Color.WHITE if available else Color(0.58, 0.62, 0.68, 0.72)
	_update_card_style()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null or not available:
		return null
	var candidate := PuzzlePieceState.new(-1, definition)
	var preview_local := shape_preview.get_local_mouse_position()
	var grab_offset := shape_preview.closest_occupied_cell(preview_local)
	var drag_preview := ShapePreview.new()
	drag_preview.configure_for_drag(candidate, grab_offset, drag_cell_size)
	set_drag_preview(drag_preview)
	return {
		"kind": &"puzzle_piece",
		"source": &"template",
		"candidate": candidate,
		"original": null,
		"grab_offset": grab_offset,
		"preview": drag_preview,
	}


func _update_card_style() -> void:
	var border := Color("8b765a") if definition != null and definition.is_special else Color("344a60")
	add_theme_stylebox_override("panel", UiPalette.panel_style(Color("1d2835"), border))
