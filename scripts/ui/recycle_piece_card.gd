class_name RecyclePieceCard
extends PanelContainer

var piece: PuzzlePieceState
var payout := 0
var drag_cell_size := PuzzleBoard.DEFAULT_CELL_SIZE
var shape_preview: ShapePreview
var title_label: Label
var meta_label: Label


func setup(value: PuzzlePieceState, value_payout: int, target_cell_size: float) -> void:
	piece = value
	payout = value_payout
	drag_cell_size = target_cell_size
	if is_node_ready():
		_refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(388, 82)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_build_card()
	_refresh()


func _build_card() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var shape_center := CenterContainer.new()
	shape_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape_center.custom_minimum_size = Vector2(76, 58)
	row.add_child(shape_center)
	shape_preview = ShapePreview.new()
	shape_preview.custom_minimum_size = Vector2(72, 54)
	shape_preview.cell_size = 11.0
	shape_center.add_child(shape_preview)

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 15)
	copy.add_child(title_label)
	meta_label = Label.new()
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.add_theme_font_size_override("font_size", 12)
	meta_label.add_theme_color_override("font_color", Color("9fb8bd"))
	copy.add_child(meta_label)


func _refresh() -> void:
	if piece == null or piece.definition == null or shape_preview == null:
		return
	shape_preview.set_piece(piece)
	title_label.text = piece.definition.localized_name()
	meta_label.text = TranslationServer.translate(&"recycle.item.meta") % [
		UiPalette.attribute_name(piece.definition.attribute), payout
	]
	tooltip_text = TranslationServer.translate(&"recycle.item.tooltip")
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("10272b", 0.88), Color("66867b"))
	)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if piece == null or piece.definition == null:
		return null
	var candidate := piece.copy_for_drag()
	var preview_local := shape_preview.get_local_mouse_position()
	var grab_offset := shape_preview.closest_occupied_cell(preview_local)
	var drag_preview := PieceDragPreview.new()
	drag_preview.configure_for_drag(candidate, grab_offset, drag_cell_size)
	set_drag_preview(drag_preview)
	return {
		"kind": &"puzzle_piece",
		"source": &"recycle_cart",
		"candidate": candidate,
		"original": piece,
		"grab_offset": grab_offset,
		"preview": drag_preview,
	}
