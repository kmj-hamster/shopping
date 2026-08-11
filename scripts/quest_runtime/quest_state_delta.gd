class_name QuestStateDelta
extends RefCounted

## A mergeable description of presentation-relevant state changes.
##
## `QuestGameState.state_changed` remains the compatibility/save notification.
## Interactive UI should subscribe to `state_delta` and only reconcile the
## scopes it renders.

var reasons: Array[StringName] = []
var full_reconcile := false
var hand_added_instance_ids: Array[int] = []
var hand_removed_instance_ids: Array[int] = []
var hand_location_instance_ids: Array[int] = []
var hand_order_changed := false
var task_instance_ids: Array[int] = []
var task_list_changed := false
var synthesis_draft_changed := false
var synthesis_persona_changed := false
var synthesis_candidate_changed := false
var wallet_changed := false
var day_changed := false
var store_state_ids: Array[StringName] = []
var shelf_store_ids: Array[StringName] = []


func mark_reason(reason: StringName) -> QuestStateDelta:
	if not reason.is_empty() and not reasons.has(reason):
		reasons.append(reason)
	return self


func mark_full_reconcile(reason: StringName = &"") -> QuestStateDelta:
	full_reconcile = true
	mark_reason(reason)
	return self


func mark_hand_added(instance_id: int, reason: StringName = &"") -> QuestStateDelta:
	_append_unique(hand_added_instance_ids, instance_id)
	mark_reason(reason)
	return self


func mark_hand_removed(instance_id: int, reason: StringName = &"") -> QuestStateDelta:
	_append_unique(hand_removed_instance_ids, instance_id)
	mark_reason(reason)
	return self


func mark_hand_location(instance_id: int, reason: StringName = &"") -> QuestStateDelta:
	_append_unique(hand_location_instance_ids, instance_id)
	mark_reason(reason)
	return self


func mark_hand_order(reason: StringName = &"") -> QuestStateDelta:
	hand_order_changed = true
	mark_reason(reason)
	return self


func mark_task_instance(instance_id: int, reason: StringName = &"") -> QuestStateDelta:
	_append_unique(task_instance_ids, instance_id)
	mark_reason(reason)
	return self


func mark_task_list(reason: StringName = &"") -> QuestStateDelta:
	task_list_changed = true
	mark_reason(reason)
	return self


func mark_synthesis_draft(reason: StringName = &"") -> QuestStateDelta:
	synthesis_draft_changed = true
	mark_reason(reason)
	return self


func mark_synthesis_persona(reason: StringName = &"") -> QuestStateDelta:
	synthesis_persona_changed = true
	synthesis_candidate_changed = true
	mark_reason(reason)
	return self


func mark_synthesis_candidate(reason: StringName = &"") -> QuestStateDelta:
	synthesis_candidate_changed = true
	mark_reason(reason)
	return self


func mark_wallet(reason: StringName = &"") -> QuestStateDelta:
	wallet_changed = true
	mark_reason(reason)
	return self


func mark_day(reason: StringName = &"") -> QuestStateDelta:
	day_changed = true
	mark_reason(reason)
	return self


func mark_store_state(store_id: StringName, reason: StringName = &"") -> QuestStateDelta:
	_append_unique_name(store_state_ids, store_id)
	mark_reason(reason)
	return self


func mark_shelf(store_id: StringName, reason: StringName = &"") -> QuestStateDelta:
	_append_unique_name(shelf_store_ids, store_id)
	mark_reason(reason)
	return self


func affects_hand() -> bool:
	return (
		full_reconcile
		or not hand_added_instance_ids.is_empty()
		or not hand_removed_instance_ids.is_empty()
		or not hand_location_instance_ids.is_empty()
		or hand_order_changed
	)


func affects_synthesis() -> bool:
	return (
		full_reconcile
		or synthesis_draft_changed
		or synthesis_persona_changed
		or synthesis_candidate_changed
	)


func affects_tasks() -> bool:
	return full_reconcile or task_list_changed or not task_instance_ids.is_empty()


func affects_hud() -> bool:
	return full_reconcile or wallet_changed or day_changed


func affects_map() -> bool:
	return full_reconcile or not store_state_ids.is_empty()


func is_empty() -> bool:
	return (
		not affects_hand()
		and not affects_tasks()
		and not affects_synthesis()
		and not affects_hud()
		and not affects_map()
		and shelf_store_ids.is_empty()
	)


func merge(other: QuestStateDelta) -> QuestStateDelta:
	if other == null:
		return self
	full_reconcile = full_reconcile or other.full_reconcile
	hand_order_changed = hand_order_changed or other.hand_order_changed
	task_list_changed = task_list_changed or other.task_list_changed
	synthesis_draft_changed = synthesis_draft_changed or other.synthesis_draft_changed
	synthesis_persona_changed = synthesis_persona_changed or other.synthesis_persona_changed
	synthesis_candidate_changed = (
		synthesis_candidate_changed or other.synthesis_candidate_changed
	)
	wallet_changed = wallet_changed or other.wallet_changed
	day_changed = day_changed or other.day_changed
	for reason in other.reasons:
		mark_reason(reason)
	for instance_id in other.hand_added_instance_ids:
		_append_unique(hand_added_instance_ids, instance_id)
	for instance_id in other.hand_removed_instance_ids:
		_append_unique(hand_removed_instance_ids, instance_id)
	for instance_id in other.hand_location_instance_ids:
		_append_unique(hand_location_instance_ids, instance_id)
	for instance_id in other.task_instance_ids:
		_append_unique(task_instance_ids, instance_id)
	for store_id in other.store_state_ids:
		_append_unique_name(store_state_ids, store_id)
	for store_id in other.shelf_store_ids:
		_append_unique_name(shelf_store_ids, store_id)
	return self


func _append_unique(values: Array[int], instance_id: int) -> void:
	if instance_id > 0 and not values.has(instance_id):
		values.append(instance_id)


func _append_unique_name(values: Array[StringName], value: StringName) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)
