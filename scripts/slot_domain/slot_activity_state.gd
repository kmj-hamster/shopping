class_name SlotActivityState
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_UNKNOWN_ACTIVITY := &"unknown_activity"
const RESULT_UNKNOWN_SLOT := &"unknown_slot"
const RESULT_NOT_OWNED := &"not_owned"
const RESULT_REJECTED := &"rejected"
const RESULT_OCCUPIED := &"occupied"

var inventory: Array[CardItemState] = []
var active_daily_wish_ids: Array[StringName] = [
	&"wish_hungry",
	&"wish_bedside",
]
var known_recipe_ids: Array[StringName] = [&"recipe_night_radio"]
var active_request_ids: Array[StringName] = []
var assignments: Dictionary = {}


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


func _remove_assignment_for_card(card: CardItemState) -> void:
	for activity_id in assignments.keys():
		var activity_assignments: Dictionary = assignments[activity_id]
		for slot_id in activity_assignments.keys():
			if int(activity_assignments[slot_id]) == card.instance_id:
				activity_assignments.erase(slot_id)
		assignments[activity_id] = activity_assignments


func _result(
	ok: bool,
	reason: StringName,
	placement: Dictionary = {},
) -> Dictionary:
	return {"ok": ok, "reason": reason, "placement": placement}
