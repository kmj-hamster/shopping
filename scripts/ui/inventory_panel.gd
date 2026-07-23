class_name InventoryPanel
extends VBoxContainer

signal will_change
signal state_changed

var palette_items: Array[ItemDefinition] = []
var pieces: Array[PuzzlePieceState] = []
var drag_cell_size := 56.0


func _ready() -> void:
	custom_minimum_size = Vector2(302, 420)
	add_theme_constant_override("separation", 8)


func set_context(
	item_definitions: Array[ItemDefinition],
	piece_states: Array[PuzzlePieceState],
	target_cell_size: float
) -> void:
	palette_items = item_definitions
	pieces = piece_states
	drag_cell_size = target_cell_size
	refresh()


func refresh() -> void:
	for child in get_children():
		child.free()

	var special_items: Array[ItemDefinition] = []
	var standard_items: Array[ItemDefinition] = []
	for item in palette_items:
		if item.is_special:
			special_items.append(item)
		else:
			standard_items.append(item)

	_add_section_title(TranslationServer.translate(&"ui.inventory.special_section"))
	var special_grid := _add_grid()
	for item in special_items:
		special_grid.add_child(_make_card(item, not _special_is_placed(item.id)))

	_add_section_title(TranslationServer.translate(&"ui.inventory.standard_section"))
	var standard_grid := _add_grid()
	for item in standard_items:
		standard_grid.add_child(_make_card(item, true))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _board_piece_from_drag(data) != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var piece := _board_piece_from_drag(data)
	if piece == null:
		return
	will_change.emit()
	pieces.erase(piece)
	state_changed.emit()


func _board_piece_from_drag(data: Variant) -> PuzzlePieceState:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return null
	if data.get("source") != &"board":
		return null
	return data.get("original") as PuzzlePieceState


func _special_is_placed(item_id: StringName) -> bool:
	return pieces.any(func(piece: PuzzlePieceState) -> bool:
		return piece.location == PuzzlePieceState.Location.BOARD and piece.definition.id == item_id
	)


func _add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("8fa1b4"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	return grid


func _make_card(item: ItemDefinition, available: bool) -> PieceCard:
	var card := PieceCard.new()
	card.setup(item, available, drag_cell_size)
	return card
