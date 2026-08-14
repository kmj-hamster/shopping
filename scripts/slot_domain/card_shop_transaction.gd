class_name CardShopTransaction
extends RefCounted

signal state_changed
signal selection_changed(previous_slot_id: StringName, selected_slot_id: StringName)

const RESULT_OK := &"ok"
const RESULT_EMPTY := &"empty"
const RESULT_UNKNOWN_SLOT := &"unknown_slot"
const RESULT_SLOT_EMPTY := &"slot_empty"
const RESULT_ALREADY_SELECTED := &"already_selected"
const RESULT_INSUFFICIENT_FUNDS := &"insufficient_funds"
const RESULT_INVALID_ITEM := &"invalid_item"
const PAGE_SIZE := 6
const MAX_PAGE_COUNT := ShelfSlotState.MAX_PAGE_COUNT

var store_id: StringName
var wallet: PlayerWallet
var inventory: Array[CardItemState] = []
var shelf_slots: Array[ShelfSlotState] = []
var selected_shelf_slot_id: StringName = &""
var discount_rate := 0.0
var unlocked_page_count := 1
var definition_resolver: Callable


func _init(
	selected_store_id: StringName = &"",
	shared_wallet: PlayerWallet = null,
	shared_inventory: Array[CardItemState] = [],
	initial_shelf_slots: Array[ShelfSlotState] = [],
	item_definition_resolver: Callable = Callable(),
) -> void:
	store_id = selected_store_id
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new()
	inventory = shared_inventory
	shelf_slots = initial_shelf_slots
	definition_resolver = item_definition_resolver


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
	if selected_shelf_slot_id == slot_id:
		return _result(false, RESULT_ALREADY_SELECTED)
	var previous_slot_id := selected_shelf_slot_id
	selected_shelf_slot_id = slot_id
	selection_changed.emit(previous_slot_id, slot_id)
	return _result(true, RESULT_OK)


func deselect_shelf_slot(slot_id: StringName) -> bool:
	if selected_shelf_slot_id != slot_id:
		return false
	selected_shelf_slot_id = &""
	selection_changed.emit(slot_id, &"")
	return true


func toggle_shelf_slot(slot_id: StringName) -> Dictionary:
	if selected_shelf_slot_id == slot_id:
		deselect_shelf_slot(slot_id)
		return _result(true, RESULT_OK)
	return select_shelf_slot(slot_id)


func is_selected(slot_id: StringName) -> bool:
	return selected_shelf_slot_id == slot_id


func has_selection() -> bool:
	return not selected_shelf_slot_id.is_empty()


func selected_price() -> int:
	var slot := shelf_slot(selected_shelf_slot_id)
	var definition := _definition_by_id(slot.item_id) if slot != null else null
	return price_for(definition)


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
	if not has_selection():
		return _result(false, RESULT_EMPTY)
	var slot := shelf_slot(selected_shelf_slot_id)
	if slot == null:
		return _result(false, RESULT_UNKNOWN_SLOT)
	if slot.is_empty():
		return _result(false, RESULT_SLOT_EMPTY)
	var definition := _definition_by_id(slot.item_id)
	if definition == null or definition.store_id != store_id:
		return _result(false, RESULT_INVALID_ITEM)
	var total := selected_price()
	if wallet.money < total:
		return _result(false, RESULT_INSUFFICIENT_FUNDS)

	var purchased := CardItemState.new(
		_next_instance_id(),
		definition.id,
		day,
		store_id,
		total,
	)

	# Validation is complete before the first mutation, so checkout is atomic.
	wallet.money -= total
	slot.clear()
	inventory.append(purchased)
	selected_shelf_slot_id = &""
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"total": total,
		"purchased": [purchased],
	}


func clear_selection() -> bool:
	if not has_selection():
		return false
	var previous_slot_id := selected_shelf_slot_id
	selected_shelf_slot_id = &""
	selection_changed.emit(previous_slot_id, &"")
	return true


func _next_instance_id() -> int:
	var result := 1
	for card in inventory:
		result = maxi(result, card.instance_id + 1)
	return result


func _definition_by_id(item_id: StringName) -> CardItemDefinition:
	if definition_resolver.is_valid():
		return definition_resolver.call(item_id) as CardItemDefinition
	return null


func _result(ok: bool, reason: StringName) -> Dictionary:
	return {"ok": ok, "reason": reason}
