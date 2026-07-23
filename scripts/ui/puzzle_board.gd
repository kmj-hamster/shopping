class_name PuzzleBoard
extends Control

signal will_change
signal state_changed
signal interaction_message(message: String)

const BOARD_OFFSET := Vector2(10, 10)

var task: TaskDefinition
var pieces: Array[PuzzlePieceState] = []
var cell_size := 56.0
var ghost_cells: Array[Vector2i] = []
var ghost_valid := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func set_context(task_definition: TaskDefinition, piece_states: Array[PuzzlePieceState]) -> void:
	task = task_definition
	pieces = piece_states
	var board_size := task.bounds_size()
	custom_minimum_size = Vector2(board_size) * cell_size + BOARD_OFFSET * 2.0
	queue_redraw()


func _draw() -> void:
	if task == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("101722"), true)
	for cell in task.mask_cells:
		var rect := _cell_rect(cell)
		draw_rect(rect.grow(-1.0), Color("263443"), true)
		draw_rect(rect.grow(-1.0), Color("3c5064"), false, 1.0)

	for piece in pieces:
		if piece.location != PuzzlePieceState.Location.BOARD:
			continue
		var color := UiPalette.attribute_color(piece.definition.attribute)
		for cell in piece.occupied_cells():
			var rect := _cell_rect(cell)
			draw_rect(rect.grow(-3.0), color, true)
			draw_rect(rect.grow(-3.0), color.lightened(0.28), false, 2.0)
			if piece.definition.is_special:
				draw_rect(rect.grow(-6.0), Color("f2eadf"), false, 2.0)

	if not ghost_cells.is_empty():
		var ghost_color := Color("78d6a8", 0.55) if ghost_valid else Color("e15f67", 0.62)
		for cell in ghost_cells:
			draw_rect(_cell_rect(cell).grow(-5.0), ghost_color, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var piece := _piece_at_local(event.position)
		if piece == null:
			return
		var next_rotation := posmod(piece.rotation_steps + 1, 4)
		if PuzzleRules.can_place(task, piece, pieces, piece.grid_position, next_rotation):
			will_change.emit()
			piece.rotation_steps = next_rotation
			state_changed.emit()
		else:
			interaction_message.emit(TranslationServer.translate(&"feedback.no_rotation_space"))
		queue_redraw()
		accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	var piece := _piece_at_local(at_position)
	if piece == null:
		return null
	var clicked_cell := _grid_cell(at_position)
	var preview := ShapePreview.new()
	preview.piece = piece
	preview.cell_size = 18.0
	preview.draw_background = true
	preview.custom_minimum_size = Vector2(110, 90)
	set_drag_preview(preview)
	return {
		"kind": &"puzzle_piece",
		"piece": piece,
		"grab_offset": clicked_cell - piece.grid_position,
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var piece := _piece_from_drag(data)
	if piece == null:
		_clear_ghost()
		return false
	var grab_offset: Vector2i = data.get("grab_offset", Vector2i.ZERO)
	var target := _grid_cell(at_position) - grab_offset
	ghost_cells = piece.occupied_cells(target, piece.rotation_steps)
	ghost_valid = PuzzleRules.can_place(task, piece, pieces, target, piece.rotation_steps)
	queue_redraw()
	return ghost_valid


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var piece := _piece_from_drag(data)
	if piece == null:
		return
	var grab_offset: Vector2i = data.get("grab_offset", Vector2i.ZERO)
	var target := _grid_cell(at_position) - grab_offset
	if not PuzzleRules.can_place(task, piece, pieces, target, piece.rotation_steps):
		interaction_message.emit(TranslationServer.translate(&"feedback.invalid_drop"))
		_clear_ghost()
		return
	will_change.emit()
	piece.location = PuzzlePieceState.Location.BOARD
	piece.grid_position = target
	_clear_ghost()
	state_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_ghost()


func _piece_at_local(local_position: Vector2) -> PuzzlePieceState:
	var cell := _grid_cell(local_position)
	for index in range(pieces.size() - 1, -1, -1):
		var piece := pieces[index]
		if piece.location == PuzzlePieceState.Location.BOARD and cell in piece.occupied_cells():
			return piece
	return null


func _piece_from_drag(data: Variant) -> PuzzlePieceState:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return null
	return data.get("piece") as PuzzlePieceState


func _grid_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(floor((local_position.x - BOARD_OFFSET.x) / cell_size), floor((local_position.y - BOARD_OFFSET.y) / cell_size))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD_OFFSET + Vector2(cell) * cell_size, Vector2.ONE * cell_size)


func _clear_ghost() -> void:
	if ghost_cells.is_empty():
		return
	ghost_cells.clear()
	ghost_valid = false
	queue_redraw()
