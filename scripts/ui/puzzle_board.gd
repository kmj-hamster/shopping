class_name PuzzleBoard
extends Control

signal will_change
signal state_changed
signal interaction_message(message: String)

const BOARD_OFFSET := Vector2(10, 10)
const DEFAULT_CELL_SIZE := 56.0

var task: TaskDefinition
var pieces: Array[PuzzlePieceState] = []
var cell_size := DEFAULT_CELL_SIZE
var ghost_cells: Array[Vector2i] = []
var ghost_valid := false
var dragged_piece: PuzzlePieceState
var next_piece_uid := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func set_context(task_definition: TaskDefinition, piece_states: Array[PuzzlePieceState]) -> void:
	task = task_definition
	pieces = piece_states
	next_piece_uid = 1
	for piece in pieces:
		next_piece_uid = maxi(next_piece_uid, piece.piece_uid + 1)
	var board_size := task.bounds_size()
	custom_minimum_size = Vector2(board_size) * cell_size + BOARD_OFFSET * 2.0
	queue_redraw()


func refresh_drag_state(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return
	var local_position := get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		_clear_ghost()
		return
	_update_ghost(local_position, data)


func _draw() -> void:
	if task == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("101722"), true)
	for cell in task.mask_cells:
		var rect := _cell_rect(cell)
		draw_rect(rect.grow(-1.0), Color("263443"), true)
		draw_rect(rect.grow(-1.0), Color("3c5064"), false, 1.0)

	for piece in pieces:
		if piece == dragged_piece or piece.location != PuzzlePieceState.Location.BOARD:
			continue
		var color := UiPalette.attribute_color(piece.definition.attribute)
		for cell in piece.occupied_cells():
			var rect := _cell_rect(cell)
			draw_rect(rect.grow(-3.0), color, true)
			draw_rect(rect.grow(-3.0), color.lightened(0.28), false, 2.0)
			if piece.definition.is_special:
				draw_rect(rect.grow(-6.0), Color("f2eadf"), false, 2.0)

func _get_drag_data(at_position: Vector2) -> Variant:
	var original := _piece_at_local(at_position)
	if original == null:
		return null
	var candidate := original.copy_for_drag()
	var clicked_cell := _grid_cell(at_position)
	var grab_offset := clicked_cell - original.grid_position
	var preview := PieceDragPreview.new()
	preview.configure_for_drag(candidate, grab_offset, cell_size)
	set_drag_preview(preview)
	dragged_piece = original
	queue_redraw()
	return {
		"kind": &"puzzle_piece",
		"source": &"board",
		"candidate": candidate,
		"original": original,
		"grab_offset": grab_offset,
		"preview": preview,
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _update_ghost(at_position, data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var candidate := _candidate_from_drag(data)
	if candidate == null:
		return
	var grab_offset: Vector2i = data.get("grab_offset", Vector2i.ZERO)
	var target := _grid_cell(at_position) - grab_offset
	var original := data.get("original") as PuzzlePieceState
	if not PuzzleRules.can_place(task, candidate, pieces, target, candidate.rotation_steps, original):
		interaction_message.emit(TranslationServer.translate(&"feedback.invalid_drop"))
		_clear_ghost()
		return

	will_change.emit()
	if data.get("source") == &"template":
		candidate.piece_uid = next_piece_uid
		next_piece_uid += 1
		candidate.location = PuzzlePieceState.Location.BOARD
		candidate.grid_position = target
		pieces.append(candidate)
	else:
		original.rotation_steps = candidate.rotation_steps
		original.grid_position = target
		original.location = PuzzlePieceState.Location.BOARD
	_clear_ghost()
	state_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_finish_piece_drag(is_drag_successful(), get_local_mouse_position())


func _finish_piece_drag(was_successful: bool, local_position: Vector2) -> void:
	var original := dragged_piece
	dragged_piece = null
	if (
		original != null
		and not was_successful
		and not Rect2(Vector2.ZERO, size).has_point(local_position)
	):
		will_change.emit()
		pieces.erase(original)
		state_changed.emit()
	_clear_ghost()
	queue_redraw()


func _update_ghost(at_position: Vector2, data: Variant) -> bool:
	var candidate := _candidate_from_drag(data)
	if candidate == null:
		_clear_ghost()
		return false
	var grab_offset: Vector2i = data.get("grab_offset", Vector2i.ZERO)
	var target := _grid_cell(at_position) - grab_offset
	ghost_cells = candidate.occupied_cells(target, candidate.rotation_steps)
	var original := data.get("original") as PuzzlePieceState
	ghost_valid = PuzzleRules.can_place(task, candidate, pieces, target, candidate.rotation_steps, original)
	queue_redraw()
	return ghost_valid


func _piece_at_local(local_position: Vector2) -> PuzzlePieceState:
	var cell := _grid_cell(local_position)
	for index in range(pieces.size() - 1, -1, -1):
		var piece := pieces[index]
		if piece.location == PuzzlePieceState.Location.BOARD and cell in piece.occupied_cells():
			return piece
	return null


func _candidate_from_drag(data: Variant) -> PuzzlePieceState:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return null
	return data.get("candidate") as PuzzlePieceState


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
