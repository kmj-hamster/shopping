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
var store_transactions: Dictionary = {}

var toy_transaction: ShopTransaction:
	get:
		return transaction_for_store(DemoCatalog.STORE_TOY)


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
	_refresh_store_transactions()
	state_changed.emit()


func transaction_for_store(store_id: StringName) -> ShopTransaction:
	return store_transactions.get(store_id) as ShopTransaction


func is_store_open(store_id: StringName) -> bool:
	return ShopSchedule.is_store_open(store_id, day)


func checkout_store(store_id: StringName) -> Dictionary:
	if not is_store_open(store_id):
		return {"ok": false, "reason": &"store_closed"}
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return {"ok": false, "reason": &"wrong_store"}
	var pending_specials: Array[StringName] = []
	for piece in pieces:
		if (
			piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE
			and piece.definition.store_id == store_id
			and piece.definition.is_special
		):
			pending_specials.append(piece.definition.id)
	var result := transaction.checkout()
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


func checkout_toy_store() -> Dictionary:
	return checkout_store(DemoCatalog.STORE_TOY)


func cancel_store_cart(store_id: StringName) -> int:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return 0
	var removed := transaction.cancel_cart()
	if removed > 0:
		state_changed.emit()
	return removed


func cancel_toy_cart() -> int:
	return cancel_store_cart(DemoCatalog.STORE_TOY)


func cancel_all_carts() -> int:
	var removed := 0
	for store_id in DemoCatalog.STORE_IDS:
		var transaction := transaction_for_store(store_id)
		if transaction != null:
			removed += transaction.cancel_cart()
	if removed > 0:
		state_changed.emit()
	return removed


func advance_day() -> Dictionary:
	var cancelled_count := cancel_all_carts()
	day += 1
	wallet.money += 100
	_refresh_store_transactions()
	state_changed.emit()
	return {
		"day": day,
		"weekday_key": ShopSchedule.weekday_key(day),
		"income": 100,
		"cancelled_count": cancelled_count,
		"open_stores": ShopSchedule.open_store_ids(day),
	}


func is_task_unlocked(task_id: StringName) -> bool:
	return unlocked_tasks.has(task_id)


func is_task_completed(task_id: StringName) -> bool:
	return completed_tasks.has(task_id)


func active_task_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for task_definition in DemoCatalog.all_tasks():
		if (
			is_task_unlocked(task_definition.id)
			and not is_task_completed(task_definition.id)
		):
			result.append(task_definition.id)
	return result


func should_show_item(item: ItemDefinition) -> bool:
	if not item.is_special:
		return true
	# The next two special items become player-facing with their events in CP5.
	return item.id == &"special_teddy"


func submit_teddy_event() -> Dictionary:
	if not is_task_unlocked(TASK_TEDDY) or is_task_completed(TASK_TEDDY):
		return {"ok": false, "reason": &"unavailable"}
	var task := DemoCatalog.task_by_id(TASK_TEDDY)
	var evaluation := PuzzleRules.evaluate(task, pieces)
	if not evaluation.is_complete:
		return {"ok": false, "reason": &"incomplete", "evaluation": evaluation}

	var consumed: Array[PuzzlePieceState] = []
	for piece in pieces:
		if (
			piece.location == PuzzlePieceState.Location.BOARD
			and (piece.task_id.is_empty() or piece.task_id == task.id)
		):
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


func shopping_goal_store_id() -> StringName:
	if not is_task_completed(TASK_TEDDY):
		return DemoCatalog.STORE_TOY
	return &""


func _refresh_store_transactions() -> void:
	store_transactions = {}
	for store_id in DemoCatalog.STORE_IDS:
		var transaction := ShopTransaction.new(
			store_id,
			wallet.money,
			DemoCatalog.items_for_store(store_id),
			pieces,
			wallet
		)
		for item in DemoCatalog.items_for_store(store_id):
			if item.is_special and purchased_special_items.has(item.id):
				transaction.stock_remaining[item.id] = 0
		store_transactions[store_id] = transaction
