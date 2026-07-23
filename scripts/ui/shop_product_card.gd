class_name ShopProductCard
extends PanelContainer

signal add_requested(item_id: StringName)

var definition: ItemDefinition
var available_count := 0
var drag_cell_size := PuzzleBoard.DEFAULT_CELL_SIZE
var shape_preview: ShapePreview
var title_label: Label
var meta_label: Label
var add_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(284, 82)
	_build_card()
	_refresh()


func setup(item: ItemDefinition, stock: int, target_cell_size: float) -> void:
	definition = item
	available_count = stock
	drag_cell_size = target_cell_size
	if is_node_ready():
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

	add_button = Button.new()
	add_button.custom_minimum_size = Vector2(36, 36)
	add_button.text = "+"
	add_button.add_theme_font_size_override("font_size", 20)
	add_button.pressed.connect(func() -> void: add_requested.emit(definition.id))
	row.add_child(add_button)


func _refresh() -> void:
	if definition == null or shape_preview == null:
		return
	shape_preview.set_piece(PuzzlePieceState.new(-1, definition))
	title_label.text = definition.localized_name()
	meta_label.text = TranslationServer.translate(&"shop.product.meta") % [
		UiPalette.attribute_name(definition.attribute),
		definition.price,
		available_count,
	]
	add_button.disabled = available_count <= 0
	mouse_default_cursor_shape = Control.CURSOR_DRAG if available_count > 0 else Control.CURSOR_FORBIDDEN
	tooltip_text = TranslationServer.translate(&"shop.product.tooltip")
	var border := Color("d5a96c") if definition.is_special else Color("4d7778")
	if available_count <= 0:
		border = Color("3b4b50")
	add_theme_stylebox_override("panel", UiPalette.panel_style(Color("10272b", 0.88), border))
	modulate = Color.WHITE if available_count > 0 else Color(0.58, 0.64, 0.65, 0.7)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null or available_count <= 0:
		return null
	var candidate := PuzzlePieceState.new(-1, definition)
	candidate.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE
	var preview_local := shape_preview.get_local_mouse_position()
	var grab_offset := shape_preview.closest_occupied_cell(preview_local)
	var drag_preview := PieceDragPreview.new()
	drag_preview.configure_for_drag(candidate, grab_offset, drag_cell_size)
	set_drag_preview(drag_preview)
	return {
		"kind": &"puzzle_piece",
		"source": &"shop_template",
		"candidate": candidate,
		"original": null,
		"grab_offset": grab_offset,
		"preview": drag_preview,
	}
