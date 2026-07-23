class_name ShopTransaction
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_EMPTY := &"empty"
const RESULT_OUT_OF_STOCK := &"out_of_stock"
const RESULT_INSUFFICIENT_FUNDS := &"insufficient_funds"
const RESULT_WRONG_STORE := &"wrong_store"

var store_id: StringName
var wallet: PlayerWallet
var money: int:
	get:
		return wallet.money if wallet != null else 0
	set(value):
		if wallet == null:
			wallet = PlayerWallet.new(value)
		else:
			wallet.money = value
var pieces: Array[PuzzlePieceState] = []
var stock_remaining: Dictionary = {}
var item_definitions: Dictionary = {}


func _init(
	selected_store_id: StringName = &"",
	starting_money: int = 100,
	store_items: Array[ItemDefinition] = [],
	piece_states: Array[PuzzlePieceState] = [],
	shared_wallet: PlayerWallet = null
) -> void:
	store_id = selected_store_id
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new(starting_money)
	pieces = piece_states
	for item in store_items:
		item_definitions[item.id] = item
		stock_remaining[item.id] = item.daily_limit


func add_to_cart(item_id: StringName) -> Dictionary:
	var definition := item_definitions.get(item_id) as ItemDefinition
	if definition == null or definition.store_id != store_id:
		return _result(false, RESULT_WRONG_STORE)
	if available_stock(item_id) <= 0:
		return _result(false, RESULT_OUT_OF_STOCK)
	var piece := PuzzlePieceState.new(_allocate_piece_uid(), definition)
	piece.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE
	pieces.append(piece)
	state_changed.emit()
	return _result(true, RESULT_OK, piece)


func make_drag_candidate(item_id: StringName) -> PuzzlePieceState:
	var definition := item_definitions.get(item_id) as ItemDefinition
	if definition == null or definition.store_id != store_id or available_stock(item_id) <= 0:
		return null
	var piece := PuzzlePieceState.new(-1, definition)
	piece.ownership = PuzzlePieceState.Ownership.PENDING_PURCHASE
	return piece


func available_stock(item_id: StringName) -> int:
	return maxi(0, int(stock_remaining.get(item_id, 0)) - cart_quantity(item_id))


func cart_quantity(item_id: StringName) -> int:
	var count := 0
	for piece in pieces:
		if (
			piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE
			and piece.definition.id == item_id
		):
			count += 1
	return count


func cart_count() -> int:
	var count := 0
	for piece in pieces:
		if piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE:
			count += 1
	return count


func cart_total() -> int:
	var total := 0
	for piece in pieces:
		if piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE:
			total += piece.definition.price
	return total


func checkout() -> Dictionary:
	var counts: Dictionary = {}
	var pending: Array[PuzzlePieceState] = []
	for piece in pieces:
		if piece.ownership != PuzzlePieceState.Ownership.PENDING_PURCHASE:
			continue
		pending.append(piece)
		counts[piece.definition.id] = int(counts.get(piece.definition.id, 0)) + 1
	if pending.is_empty():
		return _result(false, RESULT_EMPTY)
	var total := cart_total()
	if money < total:
		return _result(false, RESULT_INSUFFICIENT_FUNDS)
	for item_id in counts:
		if int(counts[item_id]) > int(stock_remaining.get(item_id, 0)):
			return _result(false, RESULT_OUT_OF_STOCK)

	# All checks happen before the first mutation so checkout stays atomic.
	money -= total
	for item_id in counts:
		stock_remaining[item_id] = int(stock_remaining[item_id]) - int(counts[item_id])
	for piece in pending:
		piece.ownership = PuzzlePieceState.Ownership.OWNED
	state_changed.emit()
	return _result(true, RESULT_OK)


func cancel_cart() -> int:
	var pending: Array[PuzzlePieceState] = []
	for piece in pieces:
		if piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE:
			pending.append(piece)
	for piece in pending:
		pieces.erase(piece)
	if not pending.is_empty():
		state_changed.emit()
	return pending.size()


func remove_from_cart(piece: PuzzlePieceState) -> bool:
	if piece == null or piece.ownership != PuzzlePieceState.Ownership.PENDING_PURCHASE:
		return false
	if not pieces.has(piece):
		return false
	pieces.erase(piece)
	state_changed.emit()
	return true


func _allocate_piece_uid() -> int:
	var result := 1
	for piece in pieces:
		result = maxi(result, piece.piece_uid + 1)
	return result


func _result(ok: bool, reason: StringName, piece: PuzzlePieceState = null) -> Dictionary:
	return {"ok": ok, "reason": reason, "piece": piece}
