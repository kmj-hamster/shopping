class_name RecycleTransaction
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_EMPTY := &"empty"
const RESULT_NOT_OWNED := &"not_owned"
const RESULT_SPECIAL_ITEM := &"special_item"
const RESULT_INVALID_LOCATION := &"invalid_location"
const PAYOUT_RATIO := 0.8

var pieces: Array[PuzzlePieceState] = []
var wallet: PlayerWallet
var _origins_by_uid: Dictionary = {}


func _init(
	piece_states: Array[PuzzlePieceState] = [],
	shared_wallet: PlayerWallet = null
) -> void:
	pieces = piece_states
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new()


func can_stage(piece: PuzzlePieceState) -> bool:
	return stage_rejection_reason(piece).is_empty()


func stage_rejection_reason(piece: PuzzlePieceState) -> StringName:
	if piece == null or piece.definition == null or not pieces.has(piece):
		return RESULT_INVALID_LOCATION
	if piece.ownership != PuzzlePieceState.Ownership.OWNED:
		return RESULT_NOT_OWNED
	if piece.definition.is_special:
		return RESULT_SPECIAL_ITEM
	if piece.location != PuzzlePieceState.Location.BOARD or piece.task_id.is_empty():
		return RESULT_INVALID_LOCATION
	return &""


func stage(piece: PuzzlePieceState) -> Dictionary:
	var rejection := stage_rejection_reason(piece)
	if not rejection.is_empty():
		return _result(false, rejection)
	_origins_by_uid[piece.piece_uid] = {
		"task_id": piece.task_id,
		"grid_position": piece.grid_position,
		"rotation_steps": piece.rotation_steps,
		"location": piece.location,
	}
	piece.location = PuzzlePieceState.Location.RECYCLE_CART
	state_changed.emit()
	return _result(true, RESULT_OK, 1, payout_for(piece))


func cancel() -> int:
	var restored := 0
	for piece in staged_pieces():
		var origin: Dictionary = _origins_by_uid.get(piece.piece_uid, {})
		if origin.is_empty():
			continue
		piece.task_id = origin.task_id
		piece.grid_position = origin.grid_position
		piece.rotation_steps = origin.rotation_steps
		piece.location = origin.location
		restored += 1
	_origins_by_uid.clear()
	if restored > 0:
		state_changed.emit()
	return restored


func checkout() -> Dictionary:
	var staged := staged_pieces()
	if staged.is_empty():
		return _result(false, RESULT_EMPTY)
	var total := 0
	for piece in staged:
		if piece.ownership != PuzzlePieceState.Ownership.OWNED:
			return _result(false, RESULT_NOT_OWNED)
		if piece.definition == null or piece.definition.is_special:
			return _result(false, RESULT_SPECIAL_ITEM)
		total += payout_for(piece)

	# Validation completes before the first mutation so checkout is atomic.
	for piece in staged:
		pieces.erase(piece)
	wallet.money += total
	_origins_by_uid.clear()
	state_changed.emit()
	return _result(true, RESULT_OK, staged.size(), total)


func staged_pieces() -> Array[PuzzlePieceState]:
	var result: Array[PuzzlePieceState] = []
	for piece in pieces:
		if piece.location == PuzzlePieceState.Location.RECYCLE_CART:
			result.append(piece)
	return result


func cart_count() -> int:
	return staged_pieces().size()


func cart_total() -> int:
	var total := 0
	for piece in staged_pieces():
		total += payout_for(piece)
	return total


func payout_for(piece: PuzzlePieceState) -> int:
	if piece == null or piece.definition == null:
		return 0
	return floori(piece.definition.price * PAYOUT_RATIO)


func _result(
	ok: bool,
	reason: StringName,
	count: int = 0,
	total: int = 0
) -> Dictionary:
	return {"ok": ok, "reason": reason, "count": count, "total": total}
