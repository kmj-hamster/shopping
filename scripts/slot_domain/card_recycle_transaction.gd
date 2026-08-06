class_name CardRecycleTransaction
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_EMPTY := &"empty"
const RESULT_NOT_OWNED := &"not_owned"
const RESULT_UNAVAILABLE := &"unavailable"

var inventory: Array[CardItemState] = []
var wallet: PlayerWallet
var staged_instance_ids: Array[int] = []


func _init(
	shared_inventory: Array[CardItemState] = [],
	shared_wallet: PlayerWallet = null,
) -> void:
	inventory = shared_inventory
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new()


func stage(card: CardItemState) -> Dictionary:
	if card == null or not inventory.has(card) or card.location != CardItemState.Location.HAND:
		return _result(false, RESULT_NOT_OWNED)
	var definition := SlotDemoCatalog.item_by_id(card.definition_id)
	if definition == null or not definition.can_recycle:
		return _result(false, RESULT_UNAVAILABLE)
	card.assign_to(&"recycling", &"counter", CardItemState.Location.RECYCLE)
	staged_instance_ids.append(card.instance_id)
	state_changed.emit()
	return _result(true, RESULT_OK)


func unstage(card: CardItemState) -> bool:
	if card == null or not staged_instance_ids.has(card.instance_id):
		return false
	staged_instance_ids.erase(card.instance_id)
	card.return_to_hand()
	state_changed.emit()
	return true


func staged_cards() -> Array[CardItemState]:
	var result: Array[CardItemState] = []
	for card in inventory:
		if staged_instance_ids.has(card.instance_id):
			result.append(card)
	return result


func cart_count() -> int:
	return staged_instance_ids.size()


func cart_total() -> int:
	var total := 0
	for card in staged_cards():
		var definition := SlotDemoCatalog.item_by_id(card.definition_id)
		if definition != null:
			total += (
				card.purchase_price
				if card.purchase_price > 0
				else definition.resale_value()
			)
	return total


func checkout() -> Dictionary:
	var staged := staged_cards()
	if staged.is_empty():
		return _result(false, RESULT_EMPTY)
	if staged.size() != staged_instance_ids.size():
		return _result(false, RESULT_NOT_OWNED)
	var total := cart_total()
	for card in staged:
		var definition := SlotDemoCatalog.item_by_id(card.definition_id)
		if definition == null or not definition.can_recycle:
			return _result(false, RESULT_UNAVAILABLE)

	for card in staged:
		inventory.erase(card)
	staged_instance_ids.clear()
	wallet.money += total
	state_changed.emit()
	return {"ok": true, "reason": RESULT_OK, "total": total, "count": staged.size()}


func cancel() -> int:
	var staged := staged_cards()
	for card in staged:
		card.return_to_hand()
	staged_instance_ids.clear()
	if not staged.is_empty():
		state_changed.emit()
	return staged.size()


func _result(ok: bool, reason: StringName) -> Dictionary:
	return {"ok": ok, "reason": reason}
