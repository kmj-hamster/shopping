class_name SlotActivityState
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_UNKNOWN_ACTIVITY := &"unknown_activity"
const RESULT_UNKNOWN_SLOT := &"unknown_slot"
const RESULT_NOT_OWNED := &"not_owned"
const RESULT_REJECTED := &"rejected"
const RESULT_OCCUPIED := &"occupied"
const RESULT_NOT_DAILY := &"not_daily"
const RESULT_NOT_READY := &"not_ready"
const RESULT_LOCKED := &"locked"

var inventory: Array[CardItemState] = []
var active_daily_wish_ids: Array[StringName] = [
	&"wish_hungry",
	&"wish_bedside",
]
var known_recipe_ids: Array[StringName] = [&"recipe_night_radio"]
var active_request_ids: Array[StringName] = []
var assignments: Dictionary = {}
var confirmed_daily_wish_ids: Dictionary = {}
var locked_activity_ids: Dictionary = {}


func _init(shared_inventory: Array[CardItemState] = []) -> void:
	inventory = shared_inventory


func rules_for_activity(activity_id: StringName) -> Array[CardSlotRule]:
	var result: Array[CardSlotRule] = []
	var wish := SlotDemoCatalog.wish_by_id(activity_id)
	if wish != null:
		result.append(wish.slot_rule)
		return result
	var recipe := SlotDemoCatalog.recipe_by_id(activity_id)
	if recipe != null:
		for raw_rule in recipe.slot_rules:
			var rule := raw_rule as CardSlotRule
			if rule != null:
				result.append(rule)
		return result
	var request := SlotDemoCatalog.request_by_id(activity_id)
	if request != null and request.slot_rule != null:
		result.append(request.slot_rule)
	return result


func rule_for(activity_id: StringName, slot_id: StringName) -> CardSlotRule:
	for rule in rules_for_activity(activity_id):
		if rule.id == slot_id:
			return rule
	return null


func assign_card(
	activity_id: StringName,
	slot_id: StringName,
	card: CardItemState,
) -> Dictionary:
	var rule := rule_for(activity_id, slot_id)
	if rule == null:
		return _result(false, RESULT_UNKNOWN_SLOT)
	if card == null or not inventory.has(card):
		return _result(false, RESULT_NOT_OWNED)
	if not can_edit_activity(activity_id) or _card_is_in_locked_activity(card):
		return _result(false, RESULT_LOCKED)
	if card.location not in [CardItemState.Location.HAND, CardItemState.Location.ACTIVITY_SLOT]:
		return _result(false, RESULT_NOT_OWNED)
	var definition := SlotDemoCatalog.item_by_id(card.definition_id)
	var placement := CardRuleEvaluator.evaluate(rule, definition)
	if not placement.can_place:
		return _result(false, RESULT_REJECTED, placement)
	var occupied := card_for_slot(activity_id, slot_id)
	if occupied != null and occupied != card:
		return _result(false, RESULT_OCCUPIED, placement)

	_remove_assignment_for_card(card)
	var activity_assignments: Dictionary = assignments.get(activity_id, {})
	activity_assignments[slot_id] = card.instance_id
	assignments[activity_id] = activity_assignments
	card.assign_to(activity_id, slot_id)
	state_changed.emit()
	return _result(true, RESULT_OK, placement)


func return_card_to_hand(card: CardItemState) -> bool:
	if card == null or not inventory.has(card):
		return false
	if card.location != CardItemState.Location.ACTIVITY_SLOT:
		return false
	if _card_is_in_locked_activity(card):
		return false
	_remove_assignment_for_card(card)
	card.return_to_hand()
	state_changed.emit()
	return true


func card_for_slot(activity_id: StringName, slot_id: StringName) -> CardItemState:
	var activity_assignments: Dictionary = assignments.get(activity_id, {})
	var instance_id := int(activity_assignments.get(slot_id, 0))
	return card_by_instance_id(instance_id) if instance_id > 0 else null


func card_by_instance_id(instance_id: int) -> CardItemState:
	for card in inventory:
		if card.instance_id == instance_id:
			return card
	return null


func evaluation_for(activity_id: StringName) -> Dictionary:
	var rules := rules_for_activity(activity_id)
	var slot_results: Array[Dictionary] = []
	var all_ready := not rules.is_empty()
	for rule in rules:
		var card := card_for_slot(activity_id, rule.id)
		var definition := (
			SlotDemoCatalog.item_by_id(card.definition_id)
			if card != null else null
		)
		var result := CardRuleEvaluator.evaluate(rule, definition)
		slot_results.append(result)
		if not result.can_execute:
			all_ready = false
	var response := {
		"activity_id": activity_id,
		"is_ready": all_ready,
		"slot_results": slot_results,
	}
	var recipe := SlotDemoCatalog.recipe_by_id(activity_id)
	if recipe != null:
		var inputs: Array[CardItemDefinition] = []
		for rule in rules:
			var card := card_for_slot(activity_id, rule.id)
			inputs.append(
				SlotDemoCatalog.item_by_id(card.definition_id)
				if card != null else null
			)
		response["synthesis"] = SynthesisRules.evaluate(recipe, inputs)
	return response


func configure_daily_wishes(wish_ids: Array[StringName]) -> void:
	for old_wish_id in active_daily_wish_ids:
		if assignments.has(old_wish_id):
			assignments.erase(old_wish_id)
	active_daily_wish_ids = wish_ids.duplicate()
	confirmed_daily_wish_ids.clear()
	state_changed.emit()


func confirm_daily_wish(wish_id: StringName) -> Dictionary:
	if wish_id not in active_daily_wish_ids:
		return _result(false, RESULT_NOT_DAILY)
	if is_daily_confirmed(wish_id):
		return _result(true, RESULT_OK)
	var evaluation := evaluation_for(wish_id)
	if not evaluation.is_ready:
		return _result(false, RESULT_NOT_READY, evaluation)
	confirmed_daily_wish_ids[wish_id] = true
	state_changed.emit()
	return _result(true, RESULT_OK, evaluation)


func cancel_daily_confirmation(wish_id: StringName) -> bool:
	if not confirmed_daily_wish_ids.has(wish_id):
		return false
	confirmed_daily_wish_ids.erase(wish_id)
	state_changed.emit()
	return true


func is_daily_confirmed(wish_id: StringName) -> bool:
	return confirmed_daily_wish_ids.has(wish_id)


func all_daily_wishes_confirmed() -> bool:
	return (
		active_daily_wish_ids.size() == 2
		and active_daily_wish_ids.all(
			func(wish_id: StringName) -> bool: return is_daily_confirmed(wish_id)
		)
	)


func can_edit_activity(activity_id: StringName) -> bool:
	return not is_daily_confirmed(activity_id) and not locked_activity_ids.has(activity_id)


func lock_activity(activity_id: StringName) -> bool:
	if locked_activity_ids.has(activity_id) or rules_for_activity(activity_id).is_empty():
		return false
	locked_activity_ids[activity_id] = true
	state_changed.emit()
	return true


func unlock_activity(activity_id: StringName) -> bool:
	if not locked_activity_ids.has(activity_id):
		return false
	locked_activity_ids.erase(activity_id)
	state_changed.emit()
	return true


func cards_for_activity(activity_id: StringName) -> Array[CardItemState]:
	var result: Array[CardItemState] = []
	for rule in rules_for_activity(activity_id):
		var card := card_for_slot(activity_id, rule.id)
		if card != null:
			result.append(card)
	return result


func consume_activity_cards(activity_id: StringName) -> Array[CardItemState]:
	var consumed := cards_for_activity(activity_id)
	for card in consumed:
		_remove_assignment_for_card(card)
		inventory.erase(card)
	locked_activity_ids.erase(activity_id)
	state_changed.emit()
	return consumed


func build_daily_transition_entries() -> Dictionary:
	if not all_daily_wishes_confirmed():
		return _result(false, RESULT_NOT_READY)
	var entries: Array[Dictionary] = []
	for wish_id in active_daily_wish_ids:
		var wish := SlotDemoCatalog.wish_by_id(wish_id)
		var rules := rules_for_activity(wish_id)
		var card := card_for_slot(wish_id, rules[0].id) if not rules.is_empty() else null
		var definition := (
			SlotDemoCatalog.item_by_id(card.definition_id)
			if card != null else null
		)
		if wish == null or card == null or definition == null:
			return _result(false, RESULT_NOT_READY)
		var result_key := wish.result_key_for(definition.id)
		if result_key.is_empty():
			return _result(false, RESULT_NOT_READY)
		entries.append({
			"wish_id": wish_id,
			"card_instance_id": card.instance_id,
			"item_id": definition.id,
			"result_key": result_key,
			"aspects": definition.property_set.present_aspects(),
		})
	return {"ok": true, "reason": RESULT_OK, "entries": entries}


func consume_confirmed_daily_cards() -> Array[CardItemState]:
	var consumed: Array[CardItemState] = []
	for wish_id in active_daily_wish_ids:
		for rule in rules_for_activity(wish_id):
			var card := card_for_slot(wish_id, rule.id)
			if card != null:
				consumed.append(card)
				_remove_assignment_for_card(card)
	for card in consumed:
		inventory.erase(card)
	confirmed_daily_wish_ids.clear()
	state_changed.emit()
	return consumed


func _remove_assignment_for_card(card: CardItemState) -> void:
	for activity_id in assignments.keys():
		var activity_assignments: Dictionary = assignments[activity_id]
		for slot_id in activity_assignments.keys():
			if int(activity_assignments[slot_id]) == card.instance_id:
				activity_assignments.erase(slot_id)
		assignments[activity_id] = activity_assignments


func _card_is_in_locked_activity(card: CardItemState) -> bool:
	return (
		card != null
		and card.location == CardItemState.Location.ACTIVITY_SLOT
		and not can_edit_activity(card.activity_id)
	)


func _result(
	ok: bool,
	reason: StringName,
	placement: Dictionary = {},
) -> Dictionary:
	return {"ok": ok, "reason": reason, "placement": placement}
