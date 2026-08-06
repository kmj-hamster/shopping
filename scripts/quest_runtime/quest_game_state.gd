class_name QuestGameState
extends RefCounted

signal state_changed

const RESULT_OK := &"ok"
const RESULT_UNKNOWN_TASK := &"unknown_task"
const RESULT_UNKNOWN_SLOT := &"unknown_slot"
const RESULT_NOT_OWNED := &"not_owned"
const RESULT_REJECTED := &"rejected"
const RESULT_OCCUPIED := &"occupied"
const RESULT_LOCKED := &"locked"
const RESULT_NOT_READY := &"not_ready"
const RESULT_WRONG_SETTLEMENT := &"wrong_settlement"
const RESULT_TRANSITION_ACTIVE := &"transition_active"
const RESULT_NO_TRANSITION := &"no_transition"
const RESULT_EFFECTS_PENDING := &"effects_pending"
const RESULT_STORE_ALREADY_OPEN := &"store_already_open"
const RESULT_STORE_LOCKED := &"store_locked"

var day := 1
var wallet := PlayerWallet.new(10)
var inventory: Array[CardItemState] = []
var task_instances: Array[TaskInstanceState] = []
var task_history: Dictionary = {}
var story_flags: Dictionary = {}
var protagonist_aspect_counts: Dictionary = {}
var unlocked_store_ids: Dictionary = {}
var known_recipe_hint_ids: Dictionary = {}
var discovered_recipe_ids: Dictionary = {}
var owner_states: Dictionary = {}
var pending_arc: ArcTransitionState
var store_transactions: Dictionary = {}
var recycle_transaction: CardRecycleTransaction
var next_card_instance_id := 1
var next_task_instance_id := 1


func _init() -> void:
	reset()


func reset() -> void:
	var content := QuestArcCatalog.manifest()
	day = 1
	wallet = PlayerWallet.new(content.initial_money if content != null else 10)
	inventory = []
	task_instances = []
	task_history = {}
	story_flags = {}
	protagonist_aspect_counts = {}
	for aspect in CardPropertySet.ASPECTS:
		protagonist_aspect_counts[aspect] = 0
	unlocked_store_ids = {}
	if content != null:
		for raw_store in content.stores:
			var store := raw_store as StoreDefinition
			if store != null and store.initially_unlocked:
				unlocked_store_ids[store.id] = true
	known_recipe_hint_ids = {}
	discovered_recipe_ids = {}
	owner_states = {}
	pending_arc = null
	next_card_instance_id = 1
	next_task_instance_id = 1
	_build_commerce()
	activate_scheduled_tasks(day)
	state_changed.emit()


func activate_scheduled_tasks(for_day: int) -> Array[TaskInstanceState]:
	var activated: Array[TaskInstanceState] = []
	var content := QuestArcCatalog.manifest()
	if content == null:
		return activated
	for raw_task in content.tasks:
		var definition := raw_task as TaskDefinition
		if (
			definition == null
			or definition.category == TaskDefinition.Category.OWNER_REQUEST
			or definition.activation_day != for_day
			or has_task_definition(definition.id)
		):
			continue
		var instance := activate_task(definition.id)
		if instance != null:
			activated.append(instance)
	return activated


func activate_task(definition_id: StringName) -> TaskInstanceState:
	if QuestArcCatalog.task_by_id(definition_id) == null or has_task_definition(definition_id):
		return null
	var instance := TaskInstanceState.new(next_task_instance_id, definition_id, day)
	next_task_instance_id += 1
	task_instances.append(instance)
	state_changed.emit()
	return instance


func has_task_definition(definition_id: StringName) -> bool:
	if task_history.has(definition_id):
		return true
	return task_instances.any(func(instance: TaskInstanceState) -> bool:
		return instance.definition_id == definition_id and not instance.settled
	)


func active_tasks() -> Array[TaskInstanceState]:
	var result: Array[TaskInstanceState] = []
	for instance in task_instances:
		if not instance.settled:
			result.append(instance)
	return result


func task_instance(instance_id: int) -> TaskInstanceState:
	for instance in task_instances:
		if instance.instance_id == instance_id:
			return instance
	return null


func task_instance_for_definition(definition_id: StringName) -> TaskInstanceState:
	for instance in active_tasks():
		if instance.definition_id == definition_id:
			return instance
	return null


func card_by_instance_id(instance_id: int) -> CardItemState:
	for card in inventory:
		if card.instance_id == instance_id:
			return card
	return null


func transaction_for_store(store_id: StringName) -> CardShopTransaction:
	return store_transactions.get(store_id) as CardShopTransaction


func checkout_store(store_id: StringName) -> Dictionary:
	var transaction := transaction_for_store(store_id)
	if transaction == null or not is_store_unlocked(store_id):
		return _result(false, RESULT_STORE_LOCKED)
	var result := transaction.checkout(day)
	if result.ok:
		_sync_next_card_instance_id()
	return result


func stage_recycle_card(card: CardItemState) -> Dictionary:
	return recycle_transaction.stage(card)


func unstage_recycle_card(card: CardItemState) -> bool:
	return recycle_transaction.unstage(card)


func checkout_recycle() -> Dictionary:
	return recycle_transaction.checkout()


func cancel_recycle() -> int:
	return recycle_transaction.cancel()


func commerce_snapshot() -> Dictionary:
	var shelves: Dictionary = {}
	for store_id in store_transactions:
		var transaction := transaction_for_store(store_id)
		var item_ids: Array[String] = []
		for slot in transaction.shelf_slots:
			item_ids.append(String(slot.item_id))
		shelves[String(store_id)] = item_ids
	return {
		"shelves": shelves,
		"recycle_staged_instance_ids": recycle_transaction.staged_instance_ids.duplicate(),
	}


func restore_commerce_snapshot(snapshot: Dictionary) -> bool:
	for transaction_value in store_transactions.values():
		(transaction_value as CardShopTransaction).cancel_cart()
	for card in inventory:
		if card.location == CardItemState.Location.RECYCLE:
			card.return_to_hand()
	recycle_transaction.staged_instance_ids.clear()
	if snapshot.is_empty():
		return true
	var shelves := snapshot.get("shelves", {}) as Dictionary
	for raw_store_id in shelves:
		var store_id := StringName(raw_store_id)
		var transaction := transaction_for_store(store_id)
		var item_ids := shelves[raw_store_id] as Array
		if transaction == null or item_ids.size() != transaction.shelf_slots.size():
			return false
		for index in item_ids.size():
			var item_id := StringName(item_ids[index])
			var item := QuestArcCatalog.item_by_id(item_id) if not item_id.is_empty() else null
			if item != null and item.store_id != store_id:
				return false
			if not item_id.is_empty() and item == null:
				return false
			transaction.shelf_slots[index].stock(item_id)
	for raw_card_id in snapshot.get("recycle_staged_instance_ids", []):
		var card := card_by_instance_id(int(raw_card_id))
		if card == null or not recycle_transaction.stage(card).ok:
			return false
	return true


func reorder_hand_card(card: CardItemState, target_index: int) -> bool:
	if card == null or not inventory.has(card) or card.location != CardItemState.Location.HAND:
		return false
	var hand_cards: Array[CardItemState] = []
	for owned in inventory:
		if owned.location == CardItemState.Location.HAND and owned != card:
			hand_cards.append(owned)
	var normalized_index := clampi(target_index, 0, hand_cards.size())
	var inventory_index := inventory.size()
	if normalized_index < hand_cards.size():
		inventory_index = inventory.find(hand_cards[normalized_index])
	inventory.erase(card)
	inventory.insert(clampi(inventory_index, 0, inventory.size()), card)
	state_changed.emit()
	return true


func refill_daily_shelves() -> void:
	var content := QuestArcCatalog.manifest()
	if content == null:
		return
	for raw_store in content.stores:
		var store := raw_store as StoreDefinition
		var transaction := transaction_for_store(store.id) if store != null else null
		if store == null or transaction == null:
			continue
		transaction.cancel_cart()
		for index in mini(store.initial_shelf_item_ids.size(), transaction.shelf_slots.size()):
			var slot := transaction.shelf_slots[index]
			var item := QuestArcCatalog.item_by_id(store.initial_shelf_item_ids[index])
			if (
				slot.is_empty()
				and item != null
				and item.supply_mode == QuestItemDefinition.SupplyMode.DAILY_BASIC
			):
				slot.stock(item.id)
	state_changed.emit()


func grant_item(
	definition_id: StringName,
	source: StringName = &"debug",
	purchase_price: int = 0,
) -> CardItemState:
	if QuestArcCatalog.item_by_id(definition_id) == null:
		return null
	var card := CardItemState.new(
		next_card_instance_id,
		definition_id,
		day,
		source,
		purchase_price,
	)
	next_card_instance_id += 1
	inventory.append(card)
	state_changed.emit()
	return card


func assign_card(task_instance_id: int, slot_id: StringName, card: CardItemState) -> Dictionary:
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled:
		return _result(false, RESULT_UNKNOWN_TASK)
	if instance.confirmed:
		return _result(false, RESULT_LOCKED)
	if card == null or not inventory.has(card):
		return _result(false, RESULT_NOT_OWNED)
	if card.location not in [CardItemState.Location.HAND, CardItemState.Location.ACTIVITY_SLOT]:
		return _result(false, RESULT_NOT_OWNED)
	var previous_task := _task_containing_card(card.instance_id)
	if previous_task != null and previous_task.confirmed and previous_task != instance:
		return _result(false, RESULT_LOCKED)
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	var rule := _rule_by_id(definition, slot_id)
	if rule == null:
		return _result(false, RESULT_UNKNOWN_SLOT)
	var item := QuestArcCatalog.item_by_id(card.definition_id)
	var evaluation := CardRuleEvaluator.evaluate(rule, item)
	if not evaluation.can_place:
		return _result(false, RESULT_REJECTED, evaluation)
	var occupied_id := instance.assigned_instance_id(slot_id)
	if occupied_id > 0 and occupied_id != card.instance_id:
		return _result(false, RESULT_OCCUPIED, evaluation)
	_remove_card_assignment(card)
	instance.assignments[slot_id] = card.instance_id
	card.assign_to(StringName(str(instance.instance_id)), slot_id)
	state_changed.emit()
	return _result(true, RESULT_OK, evaluation)


func return_card_to_hand(card: CardItemState) -> bool:
	if card == null or not inventory.has(card) or card.location != CardItemState.Location.ACTIVITY_SLOT:
		return false
	var instance := _task_containing_card(card.instance_id)
	if instance == null or instance.confirmed:
		return false
	instance.clear_assignment_for_card(card.instance_id)
	card.return_to_hand()
	state_changed.emit()
	return true


func task_evaluation(task_instance_id: int) -> Dictionary:
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled:
		return {"is_ready": false, "slot_results": []}
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	var items: Array[CardItemDefinition] = []
	var slot_results: Array[Dictionary] = []
	var ready := definition != null and not definition.slot_rules.is_empty()
	for raw_rule in definition.slot_rules if definition != null else []:
		var rule := raw_rule as CardSlotRule
		var card := card_by_instance_id(instance.assigned_instance_id(rule.id))
		var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
		var evaluation := CardRuleEvaluator.evaluate(rule, item)
		slot_results.append(evaluation)
		items.append(item)
		ready = ready and evaluation.can_execute
	var outcome := QuestArcRules.outcome_for(
		definition,
		items,
		day,
		story_flags,
		task_history,
	) if ready else null
	return {
		"is_ready": ready and outcome != null,
		"slot_results": slot_results,
		"outcome": outcome,
	}


func confirm_task(task_instance_id: int) -> Dictionary:
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled:
		return _result(false, RESULT_UNKNOWN_TASK)
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	if definition == null or definition.settlement_mode != TaskDefinition.SettlementMode.ARC:
		return _result(false, RESULT_WRONG_SETTLEMENT)
	if instance.confirmed:
		return _result(true, RESULT_OK)
	var evaluation := task_evaluation(task_instance_id)
	if not evaluation.is_ready:
		return _result(false, RESULT_NOT_READY, evaluation)
	instance.confirmed = true
	instance.resolved_outcome_id = (evaluation.outcome as TaskOutcomeDefinition).id
	state_changed.emit()
	return _result(true, RESULT_OK, evaluation)


func cancel_task_confirmation(task_instance_id: int) -> bool:
	var instance := task_instance(task_instance_id)
	if instance == null or not instance.confirmed or pending_arc != null:
		return false
	instance.confirmed = false
	instance.resolved_outcome_id = &""
	state_changed.emit()
	return true


func begin_next_day() -> Dictionary:
	if pending_arc != null:
		return _result(false, RESULT_TRANSITION_ACTIVE)
	var entries: Array[Dictionary] = []
	for instance in active_tasks():
		if not instance.confirmed:
			continue
		var definition := QuestArcCatalog.task_by_id(instance.definition_id)
		if definition == null or definition.settlement_mode != TaskDefinition.SettlementMode.ARC:
			continue
		var outcome := definition.outcome_by_id(instance.resolved_outcome_id)
		if outcome == null:
			return _result(false, RESULT_NOT_READY)
		entries.append({
			"task_instance_id": instance.instance_id,
			"task_definition_id": definition.id,
			"outcome_id": outcome.id,
			"result_text_key": outcome.result_text_key,
			"card_instance_ids": instance.assigned_instance_ids(),
		})
	pending_arc = ArcTransitionState.new(day, entries)
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"confirmed_task_count": entries.size(),
		"empty_arc": entries.is_empty(),
	}


func apply_arc_effects() -> Dictionary:
	if pending_arc == null:
		return _result(false, RESULT_NO_TRANSITION)
	if pending_arc.effects_applied:
		return {"ok": true, "reason": RESULT_OK, "already_applied": true}
	var resolved_entries: Array[Dictionary] = []
	var claimed_card_ids: Dictionary = {}
	# Validate every referenced task, outcome, and card before the first mutation.
	# This keeps a multi-task Arc atomic even if a save payload is corrupted.
	for entry in pending_arc.entries:
		var instance := task_instance(int(entry.task_instance_id))
		var definition := QuestArcCatalog.task_by_id(StringName(entry.task_definition_id))
		var outcome := definition.outcome_by_id(StringName(entry.outcome_id)) if definition != null else null
		if instance == null or definition == null or outcome == null or instance.settled:
			return _result(false, RESULT_NOT_READY)
		var cards: Array[CardItemState] = []
		var items: Array[QuestItemDefinition] = []
		for raw_card_id in entry.card_instance_ids:
			var card_id := int(raw_card_id)
			var card := card_by_instance_id(card_id)
			var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
			if card == null or item == null or claimed_card_ids.has(card_id):
				return _result(false, RESULT_NOT_READY)
			claimed_card_ids[card_id] = true
			cards.append(card)
			items.append(item)
		resolved_entries.append({
			"instance": instance,
			"definition": definition,
			"outcome": outcome,
			"cards": cards,
			"items": items,
		})
	var consumed_count := 0
	var money_before := wallet.money
	for resolved in resolved_entries:
		var instance := resolved.instance as TaskInstanceState
		var definition := resolved.definition as TaskDefinition
		var outcome := resolved.outcome as TaskOutcomeDefinition
		var consumed_items: Array[QuestItemDefinition] = []
		consumed_items.assign(resolved.items)
		if definition.category == TaskDefinition.Category.SELF_CARE:
			for item in consumed_items:
				for aspect in item.property_set.present_aspects():
					protagonist_aspect_counts[aspect] = int(protagonist_aspect_counts.get(aspect, 0)) + 1
		for raw_effect in outcome.effects:
			_apply_story_effect(raw_effect as StoryEffect)
		for raw_card in resolved.cards:
			inventory.erase(raw_card as CardItemState)
			consumed_count += 1
		instance.assignments.clear()
		instance.confirmed = false
		instance.settled = true
		task_history[definition.id] = outcome.id
	pending_arc.effects_applied = true
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"already_applied": false,
		"consumed_count": consumed_count,
		"money_gained": wallet.money - money_before,
	}


func mark_arc_entry_shown() -> bool:
	if pending_arc == null or not pending_arc.effects_applied:
		return false
	if pending_arc.next_entry_index >= pending_arc.entries.size():
		return false
	pending_arc.next_entry_index += 1
	state_changed.emit()
	return true


func finish_arc() -> Dictionary:
	if pending_arc == null:
		return _result(false, RESULT_NO_TRANSITION)
	if not pending_arc.is_complete():
		return _result(false, RESULT_EFFECTS_PENDING)
	day += 1
	pending_arc = null
	refill_daily_shelves()
	var activated := activate_scheduled_tasks(day)
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"day": day,
		"activated_task_instance_ids": activated.map(
			func(instance: TaskInstanceState) -> int: return instance.instance_id
		),
	}


func submit_owner_task(task_instance_id: int) -> Dictionary:
	if pending_arc != null:
		return _result(false, RESULT_TRANSITION_ACTIVE)
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled:
		return _result(false, RESULT_UNKNOWN_TASK)
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	if definition == null or definition.settlement_mode != TaskDefinition.SettlementMode.OWNER_IMMEDIATE:
		return _result(false, RESULT_WRONG_SETTLEMENT)
	var evaluation := task_evaluation(task_instance_id)
	if not evaluation.is_ready:
		return _result(false, RESULT_NOT_READY, evaluation)
	var outcome := evaluation.outcome as TaskOutcomeDefinition
	var consumed_count := 0
	for card_id in instance.assigned_instance_ids():
		var card := card_by_instance_id(card_id)
		if card != null:
			inventory.erase(card)
			consumed_count += 1
	for raw_effect in outcome.effects:
		_apply_story_effect(raw_effect as StoryEffect)
	instance.assignments.clear()
	instance.resolved_outcome_id = outcome.id
	instance.settled = true
	task_history[definition.id] = outcome.id
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"outcome_id": outcome.id,
		"result_text_key": outcome.result_text_key,
		"consumed_count": consumed_count,
	}


func is_store_unlocked(store_id: StringName) -> bool:
	return unlocked_store_ids.has(store_id)


func unlock_store(store_id: StringName, card: CardItemState) -> Dictionary:
	var store := QuestArcCatalog.store_by_id(store_id)
	if store == null:
		return _result(false, RESULT_STORE_LOCKED)
	if is_store_unlocked(store_id):
		return _result(false, RESULT_STORE_ALREADY_OPEN)
	if card == null or not inventory.has(card) or card.location != CardItemState.Location.HAND:
		return _result(false, RESULT_NOT_OWNED)
	var unlock := QuestArcCatalog.store_unlock_for_store(store_id)
	var item := QuestArcCatalog.item_by_id(card.definition_id)
	if unlock == null or not QuestArcRules.store_unlock_accepts(unlock, item):
		return _result(false, RESULT_REJECTED)
	inventory.erase(card)
	unlocked_store_ids[store_id] = true
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"store_id": store_id,
		"consumed_instance_id": card.instance_id,
		"result_text_key": unlock.result_text_key,
	}


func _apply_story_effect(effect: StoryEffect) -> void:
	if effect == null:
		return
	match effect.kind:
		StoryEffect.Kind.ADD_MONEY:
			wallet.money += effect.amount
		StoryEffect.Kind.SET_FLAG:
			story_flags[effect.target_id] = effect.text_value
		StoryEffect.Kind.ADD_PROTAGONIST_ASPECT:
			protagonist_aspect_counts[effect.target_id] = int(
				protagonist_aspect_counts.get(effect.target_id, 0)
			) + effect.amount
		StoryEffect.Kind.UNLOCK_RECIPE_HINT:
			known_recipe_hint_ids[effect.target_id] = true
		StoryEffect.Kind.ACTIVATE_TASK:
			activate_task(effect.target_id)
		StoryEffect.Kind.SET_OWNER_STATE:
			owner_states[effect.target_id] = effect.text_value
		StoryEffect.Kind.UNLOCK_STORE:
			unlocked_store_ids[effect.target_id] = true
		StoryEffect.Kind.GIVE_ITEM:
			grant_item(effect.target_id, &"story")


func _build_commerce() -> void:
	store_transactions.clear()
	var resolver := func(item_id: StringName) -> QuestItemDefinition:
		return QuestArcCatalog.item_by_id(item_id)
	var content := QuestArcCatalog.manifest()
	if content != null:
		for raw_store in content.stores:
			var store := raw_store as StoreDefinition
			if store == null or store.id == &"recycling":
				continue
			var shelves: Array[ShelfSlotState] = []
			for index in store.initial_capacity:
				var item_id := (
					store.initial_shelf_item_ids[index]
					if index < store.initial_shelf_item_ids.size()
					else &""
				)
				shelves.append(ShelfSlotState.new(
					store.id,
					StringName("%s_shelf_%d" % [store.id, index + 1]),
					item_id,
					1,
				))
			var transaction := CardShopTransaction.new(
				store.id,
				wallet,
				inventory,
				shelves,
				resolver,
			)
			transaction.state_changed.connect(_on_transaction_state_changed)
			store_transactions[store.id] = transaction
	recycle_transaction = CardRecycleTransaction.new(inventory, wallet, resolver)
	recycle_transaction.state_changed.connect(_on_transaction_state_changed)


func _on_transaction_state_changed() -> void:
	state_changed.emit()


func _sync_next_card_instance_id() -> void:
	for card in inventory:
		next_card_instance_id = maxi(next_card_instance_id, card.instance_id + 1)


func _rule_by_id(definition: TaskDefinition, slot_id: StringName) -> CardSlotRule:
	if definition == null:
		return null
	for raw_rule in definition.slot_rules:
		var rule := raw_rule as CardSlotRule
		if rule != null and rule.id == slot_id:
			return rule
	return null


func _task_containing_card(card_instance_id: int) -> TaskInstanceState:
	for instance in active_tasks():
		if card_instance_id in instance.assigned_instance_ids():
			return instance
	return null


func _remove_card_assignment(card: CardItemState) -> void:
	var previous := _task_containing_card(card.instance_id)
	if previous != null:
		previous.clear_assignment_for_card(card.instance_id)


func _result(ok: bool, reason: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {"ok": ok, "reason": reason}
	result.merge(details, true)
	return result
