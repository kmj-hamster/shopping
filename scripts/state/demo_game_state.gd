class_name DemoGameState
extends Node

signal state_changed
signal task_unlocked(task_id: StringName)
signal event_completed(task_id: StringName)
signal daily_goal_submitted(result_key: StringName)

const TASK_TEDDY := &"teddy"
const TASK_GOLDFISH := &"goldfish"
const TASK_TAPE := &"tape"
const TASK_ORDER: Array[StringName] = [TASK_TEDDY, TASK_GOLDFISH, TASK_TAPE]
const TASK_SPECIALS := {
	TASK_TEDDY: &"special_teddy",
	TASK_GOLDFISH: &"special_fishbone",
	TASK_TAPE: &"special_tape",
}
const SPECIAL_TASKS := {
	&"special_teddy": TASK_TEDDY,
	&"special_fishbone": TASK_GOLDFISH,
	&"special_tape": TASK_TAPE,
}
const RESULT_DAILY_INCOMPLETE := &"daily_incomplete"
const RESULT_DAILY_ALREADY_SUBMITTED := &"daily_already_submitted"
const RESULT_PENDING_PURCHASE := &"pending_purchase"
const RESULT_WRONG_OWNER := &"wrong_owner"
const RESULT_ALREADY_UNLOCKED := &"already_unlocked"
const RESULT_INVALID_SPECIAL_TASK := &"invalid_special_task"
const RESULT_RECYCLE_PENDING := &"recycle_pending"
const RESULT_NOT_SYNTHESIZED := &"not_synthesized"

var day := 1
var world_stage := 0
var wallet := PlayerWallet.new(100)
var pieces: Array[PuzzlePieceState] = []
var unlocked_tasks: Dictionary = {}
var synthesized_tasks: Dictionary = {}
var completed_tasks: Dictionary = {}
var purchased_special_items: Dictionary = {}
var store_transactions: Dictionary = {}
var recycle_transaction: RecycleTransaction
var daily_goal := DailyGoalState.new()

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
	synthesized_tasks = {}
	completed_tasks = {}
	purchased_special_items = {}
	daily_goal = DailyGoalState.new(day, DemoCatalog.daily_template_id_for_day(day))
	recycle_transaction = RecycleTransaction.new(pieces, wallet)
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
			var expected_task_id: StringName = SPECIAL_TASKS.get(piece.definition.id, &"")
			if piece.task_id not in [expected_task_id, DemoCatalog.EMPTY_BAG_TASK_ID]:
				return {"ok": false, "reason": RESULT_INVALID_SPECIAL_TASK}
			pending_specials.append(piece.definition.id)
	var result := transaction.checkout()
	if not result.ok:
		return result
	for item_id in pending_specials:
		purchased_special_items[item_id] = true
	state_changed.emit()
	return result


func cancel_store_cart(store_id: StringName) -> int:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return 0
	var removed := transaction.cancel_cart()
	if removed > 0:
		state_changed.emit()
	return removed


func cancel_all_carts() -> int:
	var removed := 0
	for store_id in DemoCatalog.RETAIL_STORE_IDS:
		var transaction := transaction_for_store(store_id)
		if transaction != null:
			removed += transaction.cancel_cart()
	if removed > 0:
		state_changed.emit()
	return removed


func stage_recycle_piece(piece: PuzzlePieceState) -> Dictionary:
	var result := recycle_transaction.stage(piece)
	if result.ok:
		state_changed.emit()
	return result


func checkout_recycling() -> Dictionary:
	var result := recycle_transaction.checkout()
	if result.ok:
		state_changed.emit()
	return result


func cancel_recycling() -> int:
	var restored := recycle_transaction.cancel()
	if restored > 0:
		state_changed.emit()
	return restored


func advance_day() -> Dictionary:
	if not daily_goal.submitted:
		return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	if has_pending_purchases():
		return {"ok": false, "reason": RESULT_PENDING_PURCHASE}
	if recycle_transaction.cart_count() > 0:
		return {"ok": false, "reason": RESULT_RECYCLE_PENDING}
	var consumed_count := _consume_task_pieces(DemoCatalog.DAILY_TASK_ID)
	day += 1
	wallet.money += 100
	daily_goal = DailyGoalState.new(day, DemoCatalog.daily_template_id_for_day(day))
	_refresh_store_transactions()
	state_changed.emit()
	return {
		"ok": true,
		"day": day,
		"weekday_key": ShopSchedule.weekday_key(day),
		"income": 100,
		"cancelled_count": 0,
		"consumed_count": consumed_count,
		"open_stores": ShopSchedule.open_store_ids(day),
	}


func daily_task() -> TaskDefinition:
	return DemoCatalog.daily_task_for_day(day)


func submit_daily_goal() -> Dictionary:
	if daily_goal.submitted:
		return {"ok": false, "reason": RESULT_DAILY_ALREADY_SUBMITTED}
	var evaluation := PuzzleRules.evaluate(daily_task(), pieces)
	if not evaluation.is_complete:
		return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE, "evaluation": evaluation}
	if has_pending_purchases(DemoCatalog.DAILY_TASK_ID):
		return {"ok": false, "reason": RESULT_PENDING_PURCHASE, "evaluation": evaluation}
	var result_key := PuzzleRules.dominant_attribute_result_key(evaluation.attribute_totals)
	daily_goal.mark_submitted(result_key, evaluation.attribute_totals)
	state_changed.emit()
	daily_goal_submitted.emit(result_key)
	return {"ok": true, "reason": &"ok", "result_key": result_key}


func talk_to_owner(store_id: StringName) -> Dictionary:
	if world_stage < 0 or world_stage >= TASK_ORDER.size():
		return {"ok": false, "reason": RESULT_WRONG_OWNER}
	var task_id: StringName = TASK_ORDER[world_stage]
	var task := DemoCatalog.task_by_id(task_id)
	if task == null or task.submit_store_id != store_id:
		return {"ok": false, "reason": RESULT_WRONG_OWNER}
	if is_task_unlocked(task_id):
		return {"ok": false, "reason": RESULT_ALREADY_UNLOCKED, "task_id": task_id}
	unlocked_tasks[task_id] = true
	_sync_special_stock()
	state_changed.emit()
	task_unlocked.emit(task_id)
	return {"ok": true, "reason": &"ok", "task_id": task_id}


func task_definition(task_id: StringName) -> TaskDefinition:
	if task_id == DemoCatalog.DAILY_TASK_ID:
		return daily_task()
	if task_id == DemoCatalog.EMPTY_BAG_TASK_ID:
		return DemoCatalog.empty_bag_task()
	return DemoCatalog.task_by_id(task_id)


func protagonist_task_ids() -> Array[StringName]:
	var result: Array[StringName] = [DemoCatalog.DAILY_TASK_ID, DemoCatalog.EMPTY_BAG_TASK_ID]
	for task_id in TASK_ORDER:
		if is_task_unlocked(task_id) or is_task_completed(task_id):
			result.append(task_id)
	return result
func has_pending_purchases(task_id: StringName = &"") -> bool:
	return pieces.any(func(piece: PuzzlePieceState) -> bool:
		return (
			piece.ownership == PuzzlePieceState.Ownership.PENDING_PURCHASE
			and (task_id.is_empty() or piece.task_id == task_id)
		)
	)


func notify_piece_layout_changed() -> void:
	state_changed.emit()


func is_task_unlocked(task_id: StringName) -> bool:
	return unlocked_tasks.has(task_id)


func is_task_completed(task_id: StringName) -> bool:
	return completed_tasks.has(task_id)


func is_task_synthesized(task_id: StringName) -> bool:
	return synthesized_tasks.has(task_id)


func should_show_item(item: ItemDefinition) -> bool:
	if not item.is_special:
		return true
	var task_id: StringName = SPECIAL_TASKS.get(item.id, &"")
	return (
		not task_id.is_empty()
		and is_task_unlocked(task_id)
		and not is_task_completed(task_id)
		and not purchased_special_items.has(item.id)
	)


func submit_task(task_id: StringName) -> Dictionary:
	if not is_task_unlocked(task_id) or is_task_completed(task_id):
		return {"ok": false, "reason": &"unavailable"}
	if not is_task_synthesized(task_id):
		return {"ok": false, "reason": RESULT_NOT_SYNTHESIZED}
	var task := DemoCatalog.task_by_id(task_id)
	if task == null:
		return {"ok": false, "reason": &"unavailable"}
	var evaluation := PuzzleRules.evaluate(task, pieces)
	if not evaluation.is_complete:
		return {"ok": false, "reason": &"incomplete", "evaluation": evaluation}
	if has_pending_purchases(task_id):
		return {"ok": false, "reason": RESULT_PENDING_PURCHASE, "evaluation": evaluation}

	var consumed: Array[PuzzlePieceState] = []
	for piece in pieces:
		if (
			piece.location == PuzzlePieceState.Location.BOARD
			and piece.task_id == task.id
		):
			consumed.append(piece)
	for piece in consumed:
		pieces.erase(piece)
	synthesized_tasks.erase(task_id)
	completed_tasks[task_id] = true
	world_stage = maxi(world_stage, TASK_ORDER.find(task_id) + 1)
	_sync_special_stock()
	state_changed.emit()
	event_completed.emit(task_id)
	return {"ok": true, "reason": &"ok", "consumed_count": consumed.size()}


func synthesize_task(task_id: StringName) -> Dictionary:
	if (
		not is_task_unlocked(task_id)
		or is_task_completed(task_id)
		or is_task_synthesized(task_id)
	):
		return {"ok": false, "reason": &"unavailable"}
	var task := DemoCatalog.task_by_id(task_id)
	if task == null:
		return {"ok": false, "reason": &"unavailable"}
	var evaluation := PuzzleRules.evaluate(task, pieces)
	if not evaluation.is_complete:
		return {"ok": false, "reason": &"incomplete", "evaluation": evaluation}
	if has_pending_purchases(task_id):
		return {
			"ok": false,
			"reason": RESULT_PENDING_PURCHASE,
			"evaluation": evaluation,
		}
	synthesized_tasks[task_id] = true
	state_changed.emit()
	return {"ok": true, "reason": &"ok", "evaluation": evaluation}


func event_notice_key(task_id: StringName) -> StringName:
	return StringName("map.notice.%s_complete" % task_id)


func all_tasks_completed() -> bool:
	return TASK_ORDER.all(func(task_id: StringName) -> bool: return is_task_completed(task_id))


func _refresh_store_transactions() -> void:
	store_transactions = {}
	for store_id in DemoCatalog.RETAIL_STORE_IDS:
		var transaction := ShopTransaction.new(
			store_id,
			wallet.money,
			DemoCatalog.items_for_store(store_id),
			pieces,
			wallet
		)
		store_transactions[store_id] = transaction
	_sync_special_stock()


func _sync_special_stock() -> void:
	for store_id in DemoCatalog.RETAIL_STORE_IDS:
		var transaction := transaction_for_store(store_id)
		if transaction == null:
			continue
		for item in DemoCatalog.items_for_store(store_id):
			if not item.is_special:
				continue
			transaction.stock_remaining[item.id] = (
				0 if purchased_special_items.has(item.id) or not should_show_item(item)
				else item.daily_limit
			)


func _consume_task_pieces(task_id: StringName) -> int:
	var consumed: Array[PuzzlePieceState] = []
	for piece in pieces:
		if piece.task_id == task_id:
			consumed.append(piece)
	for piece in consumed:
		pieces.erase(piece)
	return consumed.size()
