class_name InventoryPanel
extends VBoxContainer

signal will_change
signal state_changed

var pieces: Array[PuzzlePieceState] = []


func _ready() -> void:
	custom_minimum_size = Vector2(290, 420)
	add_theme_constant_override("separation", 8)


func set_pieces(value: Array[PuzzlePieceState]) -> void:
	pieces = value
	refresh()


func refresh() -> void:
	for child in get_children():
		child.free()
	var inventory_count := 0
	for piece in pieces:
		if piece.location != PuzzlePieceState.Location.INVENTORY:
			continue
		inventory_count += 1
		var card := PieceCard.new()
		card.setup(piece)
		card.will_change.connect(func() -> void: will_change.emit())
		card.state_changed.connect(func() -> void: state_changed.emit())
		add_child(card)
	if inventory_count == 0:
		var empty_label := Label.new()
		empty_label.text = TranslationServer.translate(&"ui.inventory.empty")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("8190a1"))
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(empty_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _piece_from_drag(data) != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var piece := _piece_from_drag(data)
	if piece == null or piece.location == PuzzlePieceState.Location.INVENTORY:
		return
	will_change.emit()
	piece.location = PuzzlePieceState.Location.INVENTORY
	piece.grid_position = Vector2i(-1, -1)
	state_changed.emit()


func _piece_from_drag(data: Variant) -> PuzzlePieceState:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return null
	return data.get("piece") as PuzzlePieceState
