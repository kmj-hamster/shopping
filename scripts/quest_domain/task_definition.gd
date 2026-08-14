class_name TaskDefinition
extends Resource

enum Category {
	ORDER,
	SELF_CARE,
	OWNER_REQUEST,
	GIFT,
}

enum SettlementMode {
	ARC,
	GIFT_PICKUP,
}

enum SlotMode {
	ALL,
	ANY,
}

@export var id: StringName
@export var display_name_key: StringName
@export var body_text_key: StringName
@export var footer_text_key: StringName
@export var category := Category.ORDER
@export var settlement_mode := SettlementMode.ARC
@export var slot_mode := SlotMode.ALL
@export_range(1, 999, 1) var activation_day := 1
@export_range(0, 999, 1) var repeat_interval_days := 0
@export var activation_store_id: StringName
@export var required_before_next_day := false
@export var owner_id: StringName
@export var store_id: StringName
@export var gift_item_id: StringName
@export_range(0, 9999, 1) var gift_money := 0
@export var slot_rules: Array[Resource] = []
@export var outcomes: Array[Resource] = []
@export var persona_tie_priority: Array[StringName] = []


func outcome_by_id(outcome_id: StringName) -> TaskOutcomeDefinition:
	for raw_outcome in outcomes:
		var outcome := raw_outcome as TaskOutcomeDefinition
		if outcome != null and outcome.id == outcome_id:
			return outcome
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or display_name_key.is_empty() or body_text_key.is_empty():
		errors.append("Task needs id, display name, and body text: %s." % id)
	var is_gift := category == Category.GIFT
	if is_gift and not slot_rules.is_empty():
		errors.append("Gift task %s cannot contain submission slots." % id)
	elif not is_gift and (slot_rules.is_empty() or slot_rules.size() > 4):
		errors.append("Task %s needs one to four slots." % id)
	for raw_rule in slot_rules:
		var rule := raw_rule as CardSlotRule
		if rule == null:
			errors.append("Task %s contains an invalid slot rule." % id)
		else:
			errors.append_array(rule.validation_errors())
	if is_gift and not outcomes.is_empty():
		errors.append("Gift task %s cannot contain settlement outcomes." % id)
	elif not is_gift and outcomes.is_empty():
		errors.append("Task %s needs at least one outcome." % id)
	var fallback_count := 0
	for raw_outcome in outcomes:
		var outcome := raw_outcome as TaskOutcomeDefinition
		if outcome == null:
			errors.append("Task %s contains an invalid outcome." % id)
		else:
			errors.append_array(outcome.validation_errors())
			fallback_count += int(outcome.is_fallback)
	if not is_gift and fallback_count != 1:
		errors.append("Task %s needs exactly one fallback outcome." % id)
	if is_gift:
		if settlement_mode != SettlementMode.GIFT_PICKUP:
			errors.append("Gift task %s must use gift-pickup settlement." % id)
		if gift_item_id.is_empty() == (gift_money <= 0):
			errors.append("Gift task %s needs exactly one item or money reward." % id)
	else:
		if settlement_mode != SettlementMode.ARC:
			errors.append("Submitted task %s must settle in the Arc." % id)
	if category == Category.OWNER_REQUEST:
		if owner_id.is_empty() or store_id.is_empty():
			errors.append("Owner task %s needs owner and store ids." % id)
	for persona_id in persona_tie_priority:
		if persona_id not in CardPropertySet.PERSONAS:
			errors.append("Task %s has unknown tie-priority persona %s." % [id, persona_id])
	if required_before_next_day and repeat_interval_days <= 0:
		errors.append("Required task %s must have a repeat interval." % id)
	return errors
