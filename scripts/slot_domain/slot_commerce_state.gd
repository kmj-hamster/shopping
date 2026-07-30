class_name SlotCommerceState
extends RefCounted

signal state_changed

const DEFAULT_SHELF_CAPACITY := 6
const DAILY_INCOME := 100
const DEMO_NIGHT_COUNT := 3
const BALLOON_OWNER := &"balloon"
const WINDUP_MOTH := &"toy_windup_moth"
const RESULT_OK := &"ok"
const RESULT_DAILY_INCOMPLETE := &"daily_incomplete"
const RESULT_DAILY_RISK := &"daily_risk"
const RESULT_TRANSITION_ACTIVE := &"transition_active"
const RESULT_NO_TRANSITION := &"no_transition"
const RESULT_CONSUMPTION_PENDING := &"consumption_pending"

const PREFERRED_DAILY_WISHES := {
	1: [&"wish_hungry", &"wish_bedside"],
	2: [&"wish_stay_awake", &"wish_remember"],
	3: [&"wish_settle_down", &"wish_rain_close"],
}

var day := 1
var wallet: PlayerWallet
var inventory: Array[CardItemState] = []
var store_transactions: Dictionary = {}
var store_shelf_capacities: Dictionary = {}
var owner_levels: Dictionary = {}
var recycle_transaction: CardRecycleTransaction
var activity_state: SlotActivityState
var protagonist_aspect_counts: Dictionary = {}
var pending_transition: SlotNightTransition
var random := RandomNumberGenerator.new()


func _init(shared_wallet: PlayerWallet = null, random_seed: int = 1999) -> void:
	reset(shared_wallet, random_seed)


func reset(shared_wallet: PlayerWallet = null, random_seed: int = 1999) -> void:
	day = 1
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new(120)
	inventory = []
	store_transactions = {}
	store_shelf_capacities = {}
	owner_levels = {}
	random.seed = random_seed
	for store_id in SlotDemoCatalog.INITIAL_SHELF_ITEMS:
		store_shelf_capacities[store_id] = DEFAULT_SHELF_CAPACITY
		var shelves := _make_initial_shelves(store_id)
		var transaction := CardShopTransaction.new(store_id, wallet, inventory, shelves)
		transaction.state_changed.connect(_on_child_state_changed)
		store_transactions[store_id] = transaction
	recycle_transaction = CardRecycleTransaction.new(inventory, wallet)
	recycle_transaction.state_changed.connect(_on_child_state_changed)
	activity_state = SlotActivityState.new(inventory)
	activity_state.state_changed.connect(_on_child_state_changed)
	protagonist_aspect_counts = {}
	for aspect in CardPropertySet.ASPECTS:
		protagonist_aspect_counts[aspect] = 0
	pending_transition = null
	select_daily_wishes_for_day(day)
	state_changed.emit()


func transaction_for_store(store_id: StringName) -> CardShopTransaction:
	return store_transactions.get(store_id) as CardShopTransaction


func checkout_store(store_id: StringName) -> Dictionary:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return {"ok": false, "reason": CardShopTransaction.RESULT_INVALID_ITEM}
	if (
		not activity_state.all_daily_wishes_confirmed()
		and transaction.cart_count() > 0
		and transaction.cart_total() <= wallet.money
	):
		var added_item_ids: Array[StringName] = []
		var excluded_shelf_keys: Dictionary = {}
		for slot_id in transaction.selected_shelf_slot_ids:
			var slot := transaction.shelf_slot(slot_id)
			if slot != null and not slot.is_empty():
				added_item_ids.append(slot.item_id)
				excluded_shelf_keys[DailyWishSolver.shelf_key(slot)] = true
		var viability := tonight_is_satisfiable(
			wallet.money - transaction.cart_total(),
			added_item_ids,
			excluded_shelf_keys,
		)
		if not viability.feasible:
			return {"ok": false, "reason": RESULT_DAILY_RISK}
	return transaction.checkout(day)


func stage_recycle_card(card: CardItemState) -> Dictionary:
	return recycle_transaction.stage(card)


func unstage_recycle_card(card: CardItemState) -> bool:
	return recycle_transaction.unstage(card)


func checkout_recycling() -> Dictionary:
	if not activity_state.all_daily_wishes_confirmed():
		var viability := tonight_is_satisfiable(
			wallet.money + recycle_transaction.cart_total()
		)
		if not viability.feasible:
			return {"ok": false, "reason": RESULT_DAILY_RISK}
	return recycle_transaction.checkout()


func card_by_instance_id(instance_id: int) -> CardItemState:
	for card in inventory:
		if card.instance_id == instance_id:
			return card
	return null


func begin_new_day(new_day: int) -> void:
	day = new_day
	for store_id in store_transactions:
		_refill_empty_slots(store_id)
	select_daily_wishes_for_day(day)
	state_changed.emit()


func tonight_is_satisfiable(
	wallet_amount: int = -1,
	added_item_ids: Array[StringName] = [],
	excluded_shelf_keys: Dictionary = {},
) -> Dictionary:
	return DailyWishSolver.evaluate(
		activity_state.active_daily_wish_ids,
		activity_state.confirmed_daily_wish_ids,
		inventory,
		store_transactions,
		ShopSchedule.open_store_ids(day),
		wallet.money if wallet_amount < 0 else wallet_amount,
		added_item_ids,
		excluded_shelf_keys,
	)


func select_daily_wishes_for_day(selected_day: int) -> Dictionary:
	var preferred: Array[StringName] = []
	for wish_id in PREFERRED_DAILY_WISHES.get(selected_day, []):
		preferred.append(StringName(wish_id))
	var open_stores := ShopSchedule.open_store_ids(selected_day)
	if preferred.size() == 2:
		var preferred_result := DailyWishSolver.evaluate(
			preferred,
			{},
			inventory,
			store_transactions,
			open_stores,
			wallet.money,
		)
		if preferred_result.feasible:
			activity_state.configure_daily_wishes(preferred)
			return {"ok": true, "wish_ids": preferred, "fallback": false}
	var all_wish_ids: Array[StringName] = []
	for wish in SlotDemoCatalog.wishes():
		all_wish_ids.append(wish.id)
	var feasible := DailyWishSolver.feasible_pairs(
		all_wish_ids,
		inventory,
		store_transactions,
		open_stores,
		wallet.money,
	)
	if feasible.is_empty():
		return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	var selected: Dictionary = feasible[random.randi_range(0, feasible.size() - 1)]
	var selected_ids: Array[StringName] = []
	for wish_id in selected.wish_ids:
		selected_ids.append(StringName(wish_id))
	activity_state.configure_daily_wishes(selected_ids)
	return {"ok": true, "wish_ids": selected_ids, "fallback": true}


func begin_night_transition() -> Dictionary:
	if pending_transition != null:
		return {"ok": false, "reason": RESULT_TRANSITION_ACTIVE}
	var snapshot := activity_state.build_daily_transition_entries()
	if not snapshot.ok:
		return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	pending_transition = SlotNightTransition.new(day, snapshot.entries)
	state_changed.emit()
	return {"ok": true, "reason": RESULT_OK, "transition": pending_transition}


func apply_night_transition_consumption() -> Dictionary:
	if pending_transition == null:
		return {"ok": false, "reason": RESULT_NO_TRANSITION}
	if pending_transition.consumption_applied:
		return {"ok": true, "reason": RESULT_OK, "already_applied": true}
	for entry in pending_transition.entries:
		var card := card_by_instance_id(int(entry.card_instance_id))
		if card == null or card.definition_id != StringName(entry.item_id):
			return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	for entry in pending_transition.entries:
		for aspect in entry.aspects:
			protagonist_aspect_counts[aspect] = int(
				protagonist_aspect_counts.get(aspect, 0)
			) + 1
	var consumed := activity_state.consume_confirmed_daily_cards()
	pending_transition.consumption_applied = true
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"consumed_count": consumed.size(),
		"already_applied": false,
	}


func finish_night_transition() -> Dictionary:
	if pending_transition == null:
		return {"ok": false, "reason": RESULT_NO_TRANSITION}
	if not pending_transition.consumption_applied:
		return {"ok": false, "reason": RESULT_CONSUMPTION_PENDING}
	day += 1
	wallet.money += DAILY_INCOME
	for store_id in store_transactions:
		_refill_empty_slots(store_id)
	var selection := select_daily_wishes_for_day(day)
	var finished_transition := pending_transition
	pending_transition = null
	state_changed.emit()
	return {
		"ok": selection.ok,
		"reason": RESULT_OK if selection.ok else selection.reason,
		"day": day,
		"income": DAILY_INCOME,
		"demo_complete": finished_transition.from_day >= DEMO_NIGHT_COUNT,
		"wish_ids": selection.get("wish_ids", []),
	}


func set_owner_level(owner_id: StringName, level: int) -> void:
	var previous := int(owner_levels.get(owner_id, 0))
	if level <= previous:
		return
	owner_levels[owner_id] = level
	if owner_id == BALLOON_OWNER and previous < 1 and level >= 1:
		store_shelf_capacities[SlotDemoCatalog.STORE_TOY] = 7
		var transaction := transaction_for_store(SlotDemoCatalog.STORE_TOY)
		_ensure_shelf_capacity(transaction, 7)
		transaction.shelf_slots[6].stock(WINDUP_MOTH)
	state_changed.emit()


func _make_initial_shelves(store_id: StringName) -> Array[ShelfSlotState]:
	var shelves: Array[ShelfSlotState] = []
	var item_ids := SlotDemoCatalog.initial_shelf_item_ids(store_id)
	for index in range(item_ids.size()):
		shelves.append(ShelfSlotState.new(
			store_id,
			StringName("%s_shelf_%d" % [store_id, index + 1]),
			item_ids[index],
		))
	return shelves


func _refill_empty_slots(store_id: StringName) -> void:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return
	var capacity := int(store_shelf_capacities.get(store_id, DEFAULT_SHELF_CAPACITY))
	_ensure_shelf_capacity(transaction, capacity)
	var available := _available_restock_items(store_id)
	for slot in transaction.shelf_slots:
		if slot.is_empty():
			var definition := _weighted_choice(available)
			if definition != null:
				slot.stock(definition.id)


func _ensure_shelf_capacity(transaction: CardShopTransaction, capacity: int) -> void:
	if transaction == null:
		return
	while transaction.shelf_slots.size() < capacity:
		var index := transaction.shelf_slots.size() + 1
		transaction.shelf_slots.append(ShelfSlotState.new(
			transaction.store_id,
			StringName("%s_shelf_%d" % [transaction.store_id, index]),
		))


func _available_restock_items(store_id: StringName) -> Array[CardItemDefinition]:
	var result: Array[CardItemDefinition] = []
	for definition in SlotDemoCatalog.retail_items_for_store(store_id):
		if definition.unlock_owner_id.is_empty():
			result.append(definition)
		elif int(owner_levels.get(definition.unlock_owner_id, 0)) >= definition.unlock_level:
			result.append(definition)
	return result


func _weighted_choice(items: Array[CardItemDefinition]) -> CardItemDefinition:
	var total_weight := 0
	for item in items:
		total_weight += item.restock_weight
	if total_weight <= 0:
		return null
	var roll := random.randi_range(1, total_weight)
	for item in items:
		roll -= item.restock_weight
		if roll <= 0:
			return item
	return items.back() if not items.is_empty() else null


func _on_child_state_changed() -> void:
	state_changed.emit()
