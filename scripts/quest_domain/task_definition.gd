class_name TaskDefinition
extends Resource

enum Category {
	ORDER,
	SELF_CARE,
	OWNER_REQUEST,
}

enum SettlementMode {
	ARC,
	OWNER_IMMEDIATE,
}

@export var id: StringName
@export var display_name_key: StringName
@export var body_text_key: StringName
@export var category := Category.ORDER
@export var settlement_mode := SettlementMode.ARC
@export_range(1, 999, 1) var activation_day := 1
@export var owner_id: StringName
@export var store_id: StringName
@export var slot_rules: Array[Resource] = []
@export var outcomes: Array[Resource] = []
@export var tie_priority: Array[StringName] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or display_name_key.is_empty() or body_text_key.is_empty():
		errors.append("Task needs id, display name, and body text: %s." % id)
	if slot_rules.is_empty() or slot_rules.size() > 4:
		errors.append("Task %s needs one to four slots." % id)
	for raw_rule in slot_rules:
		var rule := raw_rule as CardSlotRule
		if rule == null:
			errors.append("Task %s contains an invalid slot rule." % id)
		else:
			errors.append_array(rule.validation_errors())
	if outcomes.is_empty():
		errors.append("Task %s needs at least one outcome." % id)
	var fallback_count := 0
	for raw_outcome in outcomes:
		var outcome := raw_outcome as TaskOutcomeDefinition
		if outcome == null:
			errors.append("Task %s contains an invalid outcome." % id)
		else:
			errors.append_array(outcome.validation_errors())
			fallback_count += int(outcome.is_fallback)
	if fallback_count != 1:
		errors.append("Task %s needs exactly one fallback outcome." % id)
	if category == Category.OWNER_REQUEST:
		if settlement_mode != SettlementMode.OWNER_IMMEDIATE:
			errors.append("Owner task %s must settle immediately." % id)
		if owner_id.is_empty() or store_id.is_empty():
			errors.append("Owner task %s needs owner and store ids." % id)
	elif settlement_mode != SettlementMode.ARC:
		errors.append("Non-owner task %s must settle in the Arc." % id)
	for aspect in tie_priority:
		if aspect not in CardPropertySet.ASPECTS:
			errors.append("Task %s has unknown tie-priority aspect %s." % [id, aspect])
	return errors
