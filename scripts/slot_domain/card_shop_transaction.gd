class_name CardShopTransaction
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_EMPTY := &"empty"
const RESULT_UNKNOWN_SLOT := &"unknown_slot"
const RESULT_SLOT_EMPTY := &"slot_empty"
const RESULT_ALREADY_SELECTED := &"already_selected"
const RESULT_INSUFFICIENT_FUNDS := &"insufficient_funds"
const RESULT_INVALID_ITEM := &"invalid_item"
const PAGE_SIZE := 6
const MAX_PAGE_COUNT := 3

var store_id: StringName
var wallet: PlayerWallet
var inventory: Array[CardItemState] = []
var shelf_slots: Array[ShelfSlotState] = []
var selected_shelf_slot_ids: Array[StringName] = []
var discount_rate := 0.0
var unlocked_page_count := 1


func _init(
	selected_store_id: StringName = &"",
	shared_wallet: PlayerWallet = null,
	shared_inventory: Array[CardItemState] = [],
	initial_shelf_slots: Array[ShelfSlotState] = [],
) -> void:
	store_id = selected_store_id
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new()
	inventory = shared_inventory
	shelf_slots = initial_shelf_slots


func shelf_slot(slot_id: StringName) -> ShelfSlotState:
	for slot in shelf_slots:
		if slot.slot_id == slot_id:
			return slot
	return null


func shelf_slots_for_page(page_index: int) -> Array[ShelfSlotState]:
	var result: Array[ShelfSlotState] = []
	for slot in shelf_slots:
		if slot.page_index == page_index:
			result.append(slot)
	return result


func is_page_unlocked(page_index: int) -> bool:
	return page_index >= 1 and page_index <= unlocked_page_count


func unlock_page(page_index: int) -> bool:
	var next_count := clampi(page_index, 1, MAX_PAGE_COUNT)
	if next_count <= unlocked_page_count:
		return false
	unlocked_page_count = next_count
	state_changed.emit()
	return true


func add_shelf_slot(item_id: StringName, page_index: int) -> ShelfSlotState:
	var normalized_page := clampi(page_index, 1, MAX_PAGE_COUNT)
	if shelf_slots_for_page(normalized_page).size() >= PAGE_SIZE:
		return null
	var slot := ShelfSlotState.new(
		store_id,
		StringName("%s_shelf_%d" % [store_id, shelf_slots.size() + 1]),
		item_id,
		normalized_page,
	)
	shelf_slots.append(slot)
	return slot


func select_shelf_slot(slot_id: StringName) -> Dictionary:
	var slot := shelf_slot(slot_id)
	if slot == null:
		return _result(false, RESULT_UNKNOWN_SLOT)
	if slot.is_empty():
		return _result(false, RESULT_SLOT_EMPTY)
	if selected_shelf_slot_ids.has(slot_id):
		return _result(false, RESULT_ALREADY_SELECTED)
	selected_shelf_slot_ids.append(slot_id)
	state_changed.emit()
	return _result(true, RESULT_OK)


func deselect_shelf_slot(slot_id: StringName) -> bool:
	if not selected_shelf_slot_ids.has(slot_id):
		return false
	selected_shelf_slot_ids.erase(slot_id)
	state_changed.emit()
	return true


func toggle_shelf_slot(slot_id: StringName) -> Dictionary:
	if selected_shelf_slot_ids.has(slot_id):
		deselect_shelf_slot(slot_id)
		return _result(true, RESULT_OK)
	return select_shelf_slot(slot_id)


func is_selected(slot_id: StringName) -> bool:
	return selected_shelf_slot_ids.has(slot_id)


func cart_count() -> int:
	return selected_shelf_slot_ids.size()


func cart_total() -> int:
	var total := 0
	for slot_id in selected_shelf_slot_ids:
		var slot := shelf_slot(slot_id)
		var definition := SlotDemoCatalog.item_by_id(slot.item_id) if slot != null else null
		if definition != null:
			total += price_for(definition)
	return total


func price_for(definition: CardItemDefinition) -> int:
	if definition == null:
		return 0
	return maxi(1, ceili(definition.base_price * (1.0 - discount_rate)))


func set_discount_rate(value: float) -> void:
	var next_rate := clampf(value, 0.0, 0.9)
	if is_equal_approx(discount_rate, next_rate):
		return
	discount_rate = next_rate
	state_changed.emit()


func checkout(day: int) -> Dictionary:
	if selected_shelf_slot_ids.is_empty():
		return _result(false, RESULT_EMPTY)
	var selected_slots: Array[ShelfSlotState] = []
	var definitions: Array[CardItemDefinition] = []
	for slot_id in selected_shelf_slot_ids:
		var slot := shelf_slot(slot_id)
		if slot == null:
			return _result(false, RESULT_UNKNOWN_SLOT)
		if slot.is_empty():
			return _result(false, RESULT_SLOT_EMPTY)
		var definition := SlotDemoCatalog.item_by_id(slot.item_id)
		if definition == null or definition.store_id != store_id:
			return _result(false, RESULT_INVALID_ITEM)
		selected_slots.append(slot)
		definitions.append(definition)
	var total := cart_total()
	if wallet.money < total:
		return _result(false, RESULT_INSUFFICIENT_FUNDS)

	var next_instance_id := _next_instance_id()
	var purchased: Array[CardItemState] = []
	for definition in definitions:
		purchased.append(CardItemState.new(next_instance_id, definition.id, day, store_id))
		next_instance_id += 1

	# Validation is complete before the first mutation, so checkout is atomic.
	wallet.money -= total
	for slot in selected_slots:
		slot.clear()
	inventory.append_array(purchased)
	selected_shelf_slot_ids.clear()
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"total": total,
		"purchased": purchased,
	}


func cancel_cart() -> int:
	var removed := selected_shelf_slot_ids.size()
	selected_shelf_slot_ids.clear()
	if removed > 0:
		state_changed.emit()
	return removed


func _next_instance_id() -> int:
	var result := 1
	for card in inventory:
		result = maxi(result, card.instance_id + 1)
	return result


func _result(ok: bool, reason: StringName) -> Dictionary:
	return {"ok": ok, "reason": reason}
