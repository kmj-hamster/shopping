class_name PieceInstanceCard
extends PanelContainer

signal remove_requested(piece: PuzzlePieceState)

var piece: PuzzlePieceState
var drag_cell_size := PuzzleBoard.DEFAULT_CELL_SIZE
var shape_preview: ShapePreview
var title_label: Label
var state_label: Label
var remove_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(284, 76)
	_build_card()
	_refresh()


func setup(piece_state: PuzzlePieceState, target_cell_size: float) -> void:
	piece = piece_state
	drag_cell_size = target_cell_size
	if is_node_ready():
		_refresh()


func _build_card() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.custom_minimum_size = Vector2(76, 52)
	row.add_child(center)
	shape_preview = ShapePreview.new()
	shape_preview.custom_minimum_size = Vector2(72, 50)
	shape_preview.cell_size = 11.0
	center.add_child(shape_preview)

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", 15)
	copy.add_child(title_label)
	state_label = Label.new()
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.add_theme_font_size_override("font_size", 12)
	copy.add_child(state_label)

	remove_button = Button.new()
	remove_button.custom_minimum_size = Vector2(34, 34)
	remove_button.text = "×"
	remove_button.pressed.connect(func() -> void: remove_requested.emit(piece))
	row.add_child(remove_button)


func _refresh() -> void:
	if piece == null or piece.definition == null or shape_preview == null:
		return
	shape_preview.set_piece(piece)
	title_label.text = piece.definition.localized_name()
	var is_pending := piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE
	state_label.text = TranslationServer.translate(&"shop.item.pending" if is_pending else &"shop.item.owned")
	state_label.add_theme_color_override(
		"font_color",
		Color("edb56f") if is_pending else Color("81b9b2")
	)
	remove_button.visible = is_pending
	tooltip_text = TranslationServer.translate(&"shop.bag.tooltip")
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	add_theme_stylebox_override(
		"panel",
		UiPalette.panel_style(
			Color("10272b", 0.88),
			Color("edb56f") if is_pending else Color("416d70")
		)
	)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if piece == null or piece.location != PuzzlePieceState.Location.INVENTORY:
		return null
	var candidate := piece.copy_for_drag()
	var preview_local := shape_preview.get_local_mouse_position()
	var grab_offset := shape_preview.closest_occupied_cell(preview_local)
	var drag_preview := PieceDragPreview.new()
	drag_preview.configure_for_drag(candidate, grab_offset, drag_cell_size)
	set_drag_preview(drag_preview)
	return {
		"kind": &"puzzle_piece",
		"source": &"inventory",
		"candidate": candidate,
		"original": piece,
		"grab_offset": grab_offset,
		"preview": drag_preview,
	}
