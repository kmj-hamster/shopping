class_name PieceCard
extends PanelContainer

signal will_change
signal state_changed

var piece: PuzzlePieceState
var shape_preview: ShapePreview
var title_label: Label
var detail_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(270, 78)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", UiPalette.panel_style(Color("1d2835"), Color("344a60")))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	shape_preview = ShapePreview.new()
	shape_preview.custom_minimum_size = Vector2(68, 58)
	shape_preview.cell_size = 12.0
	row.add_child(shape_preview)

	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_column)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 17)
	text_column.add_child(title_label)

	detail_label = Label.new()
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", Color("aebccc"))
	text_column.add_child(detail_label)
	_refresh()


func setup(value: PuzzlePieceState) -> void:
	piece = value
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if piece == null or piece.definition == null or shape_preview == null:
		return
	shape_preview.set_piece(piece)
	var prefix := "★ " if piece.definition.is_special else ""
	title_label.text = prefix + piece.definition.localized_name()
	detail_label.text = TranslationServer.translate(&"ui.item.detail") % [
		piece.definition.shape_code,
		UiPalette.attribute_name(piece.definition.attribute),
		piece.definition.cell_count(),
		piece.definition.price,
	]
	tooltip_text = TranslationServer.translate(&"ui.item.tooltip")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		will_change.emit()
		piece.rotation_steps = posmod(piece.rotation_steps + 1, 4)
		_refresh()
		state_changed.emit()
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if piece == null:
		return null
	var preview := ShapePreview.new()
	preview.piece = piece
	preview.cell_size = 18.0
	preview.draw_background = true
	preview.custom_minimum_size = Vector2(110, 90)
	set_drag_preview(preview)
	return {
		"kind": &"puzzle_piece",
		"piece": piece,
		"grab_offset": Vector2i.ZERO,
	}
