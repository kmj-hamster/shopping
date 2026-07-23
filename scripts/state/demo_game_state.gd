class_name DemoGameState
extends Node

signal state_changed
signal task_unlocked(task_id: StringName)
signal event_completed(task_id: StringName)

const TASK_TEDDY := &"teddy"

var day := 1
var world_stage := 0
var wallet := PlayerWallet.new(100)
var pieces: Array[PuzzlePieceState] = []
var unlocked_tasks: Dictionary = {}
var completed_tasks: Dictionary = {}
var purchased_special_items: Dictionary = {}
var toy_transaction: ShopTransaction


func _ready() -> void:
	reset_demo()


func reset_demo() -> void:
	day = 1
	world_stage = 0
	wallet = PlayerWallet.new(100)
	pieces = []
	unlocked_tasks = {}
	completed_tasks = {}
	purchased_special_items = {}
	toy_transaction = ShopTransaction.new(
		DemoCatalog.STORE_TOY,
		wallet.money,
		DemoCatalog.items_for_store(DemoCatalog.STORE_TOY),
		pieces,
		wallet
	)
	state_changed.emit()


func checkout_toy_store() -> Dictionary:
	var pending_specials: Array[StringName] = []
	for piece in pieces:
		if (
			piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE
			and piece.definition.is_special
		):
			pending_specials.append(piece.definition.id)
	var result := toy_transaction.checkout()
	if not result.ok:
		return result
	for item_id in pending_specials:
		purchased_special_items[item_id] = true
	if (
		purchased_special_items.has(&"special_teddy")
		and not unlocked_tasks.has(TASK_TEDDY)
	):
		unlocked_tasks[TASK_TEDDY] = true
		task_unlocked.emit(TASK_TEDDY)
	state_changed.emit()
	return result


func cancel_toy_cart() -> int:
	var removed := toy_transaction.cancel_cart()
	if removed > 0:
		state_changed.emit()
	return removed


func is_task_unlocked(task_id: StringName) -> bool:
	return unlocked_tasks.has(task_id)


func is_task_completed(task_id: StringName) -> bool:
	return completed_tasks.has(task_id)


func submit_teddy_event() -> Dictionary:
	if not is_task_unlocked(TASK_TEDDY) or is_task_completed(TASK_TEDDY):
		return {"ok": false, "reason": &"unavailable"}
	var task := DemoCatalog.task_by_id(TASK_TEDDY)
	var evaluation := PuzzleRules.evaluate(task, pieces)
	if not evaluation.is_complete:
		return {"ok": false, "reason": &"incomplete", "evaluation": evaluation}

	var consumed: Array[PuzzlePieceState] = []
	for piece in pieces:
		if piece.location == PuzzlePieceState.Location.BOARD:
			consumed.append(piece)
	for piece in consumed:
		pieces.erase(piece)
	completed_tasks[TASK_TEDDY] = true
	world_stage = 1
	state_changed.emit()
	event_completed.emit(TASK_TEDDY)
	return {"ok": true, "reason": &"ok", "consumed_count": consumed.size()}


func shopping_goal_key() -> StringName:
	if is_task_completed(TASK_TEDDY):
		return &"map.goal.after_teddy"
	if is_task_unlocked(TASK_TEDDY):
		return &"map.goal.finish_teddy"
	return &"map.goal.buy_teddy"
