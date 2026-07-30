class_name SlotCommerceState
extends RefCounted

signal state_changed

const DEFAULT_SHELF_CAPACITY := 6
const BALLOON_OWNER := &"balloon"
const WINDUP_MOTH := &"toy_windup_moth"

var day := 1
var wallet: PlayerWallet
var inventory: Array[CardItemState] = []
var store_transactions: Dictionary = {}
var store_shelf_capacities: Dictionary = {}
var owner_levels: Dictionary = {}
var recycle_transaction: CardRecycleTransaction
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
	state_changed.emit()


func transaction_for_store(store_id: StringName) -> CardShopTransaction:
	return store_transactions.get(store_id) as CardShopTransaction


func checkout_store(store_id: StringName) -> Dictionary:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return {"ok": false, "reason": CardShopTransaction.RESULT_INVALID_ITEM}
	return transaction.checkout(day)


func stage_recycle_card(card: CardItemState) -> Dictionary:
	return recycle_transaction.stage(card)


func unstage_recycle_card(card: CardItemState) -> bool:
	return recycle_transaction.unstage(card)


func checkout_recycling() -> Dictionary:
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
	state_changed.emit()


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
