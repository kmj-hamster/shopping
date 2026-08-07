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
const RESULT_UNKNOWN_RECIPE := &"unknown_recipe"
const RESULT_SYNTHESIS_ACTIVE := &"synthesis_active"
const RESULT_UNKNOWN_OWNER := &"unknown_owner"

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
var synthesis_recipe_id: StringName = &"recipe_scissors"
var synthesis_assignments: Dictionary = {}
var active_synthesis: ActiveSynthesisState
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
	story_flags = {&"flower_request_available": &"true"}
	protagonist_aspect_counts = {}
	for stat_id in CardPropertySet.PROTAGONIST_STATS:
		protagonist_aspect_counts[stat_id] = 0
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
	synthesis_recipe_id = &"recipe_scissors"
	synthesis_assignments = {}
	active_synthesis = null
	next_card_instance_id = 1
	next_task_instance_id = 1
	_build_commerce()
	if content != null:
		for item_id in content.starting_item_ids:
			grant_item(item_id, &"demo_start")
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


func owner_dialogue_key(store_id: StringName) -> StringName:
	var owner := QuestArcCatalog.owner_for_store(store_id)
	if owner == null:
		return &""
	var owner_state := StringName(owner_states.get(owner.id, &""))
	if not owner_state.is_empty():
		return owner.dialogue_for_state(owner_state)
	if task_instance_for_definition(owner.request_task_id) != null:
		return owner.reminder_dialogue_key
	return owner.idle_dialogue_key


func owner_is_visible(store_id: StringName) -> bool:
	var owner := QuestArcCatalog.owner_for_store(store_id)
	if owner == null:
		return false
	return StringName(owner_states.get(owner.id, &"")) not in owner.portrait_hidden_states


func interact_with_store_owner(store_id: StringName) -> Dictionary:
	var owner := QuestArcCatalog.owner_for_store(store_id)
	if owner == null:
		return _result(false, RESULT_UNKNOWN_OWNER)
	var owner_state := StringName(owner_states.get(owner.id, &""))
	if not owner_state.is_empty():
		return _owner_result(owner, owner.dialogue_for_state(owner_state), false)
	if owner.request_task_id.is_empty():
		return _owner_result(owner, owner.idle_dialogue_key, false)
	if task_instance_for_definition(owner.request_task_id) != null:
		return _owner_result(owner, owner.reminder_dialogue_key, false)
	if task_history.has(owner.request_task_id):
		return _owner_result(owner, owner.idle_dialogue_key, false)
	if (
		StringName(story_flags.get(owner.request_available_flag, &""))
		!= owner.request_required_value
	):
		return _owner_result(owner, owner.idle_dialogue_key, false)

	var recipe := QuestArcCatalog.recipe_by_id(owner.request_recipe_id)
	if recipe != null:
		known_recipe_hint_ids[recipe.id] = true
		if not recipe.unlock_story_flag.is_empty():
			story_flags[recipe.unlock_story_flag] = &"true"
	var task := activate_task(owner.request_task_id)
	if task == null:
		return _owner_result(owner, owner.idle_dialogue_key, false)
	_stock_owner_event_item(owner)
	state_changed.emit()
	return _owner_result(owner, owner.request_dialogue_key, true, task.instance_id)


func stage_recycle_card(card: CardItemState) -> Dictionary:
	return recycle_transaction.stage(card)


func unstage_recycle_card(card: CardItemState) -> bool:
	return recycle_transaction.unstage(card)


func checkout_recycle() -> Dictionary:
	return recycle_transaction.checkout()


func cancel_recycle() -> int:
	return recycle_transaction.cancel()


func commerce_snapshot() -> Dictionary:
	var stores: Dictionary = {}
	for store_id in store_transactions:
		var transaction := transaction_for_store(store_id)
		var slots: Array[Dictionary] = []
		for slot in transaction.shelf_slots:
			slots.append({
				"item_id": String(slot.item_id),
				"page_index": slot.page_index,
			})
		stores[String(store_id)] = {
			"unlocked_page_count": transaction.unlocked_page_count,
			"slots": slots,
		}
	return {
		"stores": stores,
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
	var stores := snapshot.get("stores", snapshot.get("shelves", {})) as Dictionary
	var modern_format := snapshot.has("stores")
	for raw_store_id in stores:
		var store_id := StringName(raw_store_id)
		var transaction := transaction_for_store(store_id)
		if transaction == null:
			return false
		var store_snapshot: Variant = stores[raw_store_id]
		if modern_format:
			if not store_snapshot is Dictionary:
				return false
			var data := store_snapshot as Dictionary
			if not _restore_store_slots(
				transaction,
				data.get("slots", []) as Array,
				int(data.get("unlocked_page_count", 1)),
			):
				return false
		else:
			if not _restore_legacy_store_slots(transaction, store_snapshot as Array):
				return false
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
	if instance != null:
		if instance.confirmed:
			return false
		instance.clear_assignment_for_card(card.instance_id)
	elif active_synthesis != null or not _clear_synthesis_assignment_for_card(card.instance_id):
		return false
	card.return_to_hand()
	state_changed.emit()
	return true


func select_synthesis_recipe(recipe_id: StringName) -> bool:
	if active_synthesis != null or not recipe_is_available(recipe_id):
		return false
	for card_id in synthesis_assignments.values():
		var card := card_by_instance_id(int(card_id))
		if card != null:
			card.return_to_hand()
	synthesis_assignments.clear()
	synthesis_recipe_id = recipe_id
	state_changed.emit()
	return true


func clear_synthesis_assignments() -> bool:
	if active_synthesis != null:
		return false
	if synthesis_assignments.is_empty():
		return true
	for card_id in synthesis_assignments.values():
		var card := card_by_instance_id(int(card_id))
		if card != null:
			card.return_to_hand()
	synthesis_assignments.clear()
	state_changed.emit()
	return true


func recipe_is_available(recipe_id: StringName) -> bool:
	var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
	if recipe == null:
		return false
	if not recipe.unlock_story_flag.is_empty():
		return StringName(story_flags.get(recipe.unlock_story_flag, &"")) == &"true"
	return true


func available_synthesis_recipe_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var content := QuestArcCatalog.manifest()
	if content == null:
		return result
	for raw_recipe in content.recipes:
		var recipe := raw_recipe as SynthesisRecipeDefinition
		if recipe != null and recipe_is_available(recipe.id):
			result.append(recipe.id)
	return result


func assign_synthesis_card(slot_id: StringName, card: CardItemState) -> Dictionary:
	if active_synthesis != null:
		return _result(false, RESULT_SYNTHESIS_ACTIVE)
	var recipe := QuestArcCatalog.recipe_by_id(synthesis_recipe_id)
	if recipe == null or not recipe_is_available(recipe.id):
		return _result(false, RESULT_UNKNOWN_RECIPE)
	if card == null or not inventory.has(card):
		return _result(false, RESULT_NOT_OWNED)
	var previous_task := _task_containing_card(card.instance_id)
	if previous_task != null and previous_task.confirmed:
		return _result(false, RESULT_LOCKED)
	var rule := _recipe_rule_by_id(recipe, slot_id)
	if rule == null:
		return _result(false, RESULT_UNKNOWN_SLOT)
	var evaluation := CardRuleEvaluator.evaluate(rule, QuestArcCatalog.item_by_id(card.definition_id))
	if not evaluation.can_place:
		return _result(false, RESULT_REJECTED, evaluation)
	var occupied_id := int(synthesis_assignments.get(slot_id, 0))
	if occupied_id > 0 and occupied_id != card.instance_id:
		return _result(false, RESULT_OCCUPIED, evaluation)
	if previous_task != null:
		previous_task.clear_assignment_for_card(card.instance_id)
	_clear_synthesis_assignment_for_card(card.instance_id)
	synthesis_assignments[slot_id] = card.instance_id
	card.assign_to(synthesis_recipe_id, slot_id)
	state_changed.emit()
	return _result(true, RESULT_OK, evaluation)


func synthesis_evaluation() -> Dictionary:
	var recipe := QuestArcCatalog.recipe_by_id(synthesis_recipe_id)
	if recipe == null or not recipe_is_available(recipe.id):
		return {"is_complete": false, "slot_results": []}
	var items: Array[CardItemDefinition] = []
	for raw_rule in recipe.slot_rules:
		var rule := raw_rule as CardSlotRule
		var card := card_by_instance_id(int(synthesis_assignments.get(rule.id, 0)))
		items.append(QuestArcCatalog.item_by_id(card.definition_id) if card != null else null)
	return SynthesisRules.evaluate(recipe, items)


func begin_synthesis() -> Dictionary:
	if active_synthesis != null:
		return _result(false, RESULT_SYNTHESIS_ACTIVE)
	var recipe := QuestArcCatalog.recipe_by_id(synthesis_recipe_id)
	if recipe == null or not recipe_is_available(recipe.id):
		return _result(false, RESULT_UNKNOWN_RECIPE)
	var evaluation := synthesis_evaluation()
	if not evaluation.is_complete:
		return _result(false, RESULT_NOT_READY, evaluation)
	var input_ids: Array[int] = []
	for raw_rule in recipe.slot_rules:
		input_ids.append(int(synthesis_assignments.get((raw_rule as CardSlotRule).id, 0)))
	active_synthesis = ActiveSynthesisState.new(
		recipe.id,
		input_ids,
		StringName(evaluation.output_id),
		StringName(evaluation.preview_key),
		recipe.duration_seconds,
	)
	discovered_recipe_ids[recipe.id] = true
	state_changed.emit()
	return _result(true, RESULT_OK, evaluation)


func advance_synthesis(delta: float) -> Dictionary:
	if active_synthesis == null:
		return _result(false, RESULT_NOT_READY)
	if not active_synthesis.advance(delta):
		return {
			"ok": true,
			"reason": RESULT_OK,
			"completed": false,
			"progress": active_synthesis.progress_ratio(),
		}
	for card_id in active_synthesis.input_instance_ids:
		var card := card_by_instance_id(card_id)
		if card == null or int(synthesis_assignments.get(card.slot_id, 0)) != card_id:
			return _result(false, RESULT_NOT_READY)
	var output_id := active_synthesis.output_id
	var preview_key := active_synthesis.preview_key
	for card_id in active_synthesis.input_instance_ids:
		inventory.erase(card_by_instance_id(card_id))
	synthesis_assignments.clear()
	active_synthesis = null
	var output := grant_item(output_id, &"synthesis")
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"completed": true,
		"output": output,
		"preview_key": preview_key,
	}


func task_evaluation(task_instance_id: int) -> Dictionary:
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled:
		return {"is_ready": false, "slot_results": []}
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	var items: Array[CardItemDefinition] = []
	var slot_results: Array[Dictionary] = []
	var ready := definition != null and not definition.slot_rules.is_empty()
	var executable_slot_count := 0
	for raw_rule in definition.slot_rules if definition != null else []:
		var rule := raw_rule as CardSlotRule
		var card := card_by_instance_id(instance.assigned_instance_id(rule.id))
		var item := QuestArcCatalog.item_by_id(card.definition_id) if card != null else null
		var evaluation := CardRuleEvaluator.evaluate(rule, item)
		slot_results.append(evaluation)
		items.append(item)
		executable_slot_count += int(evaluation.can_execute)
		if definition.slot_mode == TaskDefinition.SlotMode.ALL:
			ready = ready and evaluation.can_execute
	if definition != null and definition.slot_mode == TaskDefinition.SlotMode.ANY:
		ready = executable_slot_count > 0
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
	# shopping0807 treats submission as a permanent choice.
	# Keep this API for save compatibility, but never reopen a submitted task.
	return false


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
		var item_definition_ids: Array[StringName] = []
		for card_id in instance.assigned_instance_ids():
			var card := card_by_instance_id(card_id)
			if card != null:
				item_definition_ids.append(card.definition_id)
		var reward_money := 0
		var reward_stats: Dictionary = {}
		for raw_effect in outcome.effects:
			var effect := raw_effect as StoryEffect
			if effect == null:
				continue
			if effect.kind == StoryEffect.Kind.ADD_MONEY:
				reward_money += effect.amount
			elif effect.kind == StoryEffect.Kind.ADD_PROTAGONIST_ASPECT:
				reward_stats[effect.target_id] = int(
					reward_stats.get(effect.target_id, 0)
				) + effect.amount
		entries.append({
			"task_instance_id": instance.instance_id,
			"task_definition_id": definition.id,
			"outcome_id": outcome.id,
			"result_text_key": outcome.result_text_key,
			"card_instance_ids": instance.assigned_instance_ids(),
			"item_definition_ids": item_definition_ids,
			"reward_money": reward_money,
			"reward_stats": reward_stats,
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


func submit_owner_task(task_instance_id: int, store_id: StringName = &"") -> Dictionary:
	if pending_arc != null:
		return _result(false, RESULT_TRANSITION_ACTIVE)
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled:
		return _result(false, RESULT_UNKNOWN_TASK)
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	if definition == null or definition.settlement_mode != TaskDefinition.SettlementMode.OWNER_IMMEDIATE:
		return _result(false, RESULT_WRONG_SETTLEMENT)
	if store_id != definition.store_id:
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


func _stock_owner_event_item(owner: OwnerDefinition) -> bool:
	if owner == null or owner.event_item_id.is_empty():
		return false
	var transaction := transaction_for_store(owner.event_item_store_id)
	var item := QuestArcCatalog.item_by_id(owner.event_item_id)
	if transaction == null or item == null or item.store_id != owner.event_item_store_id:
		return false
	for slot in transaction.shelf_slots:
		if slot.item_id == owner.event_item_id:
			return false
	transaction.unlock_page(owner.event_item_page)
	return transaction.add_shelf_slot(owner.event_item_id, owner.event_item_page) != null


func _owner_result(
	owner: OwnerDefinition,
	text_key: StringName,
	activated: bool,
	task_instance_id: int = 0,
) -> Dictionary:
	return {
		"ok": true,
		"reason": RESULT_OK,
		"owner_id": owner.id,
		"text_key": text_key,
		"activated": activated,
		"task_instance_id": task_instance_id,
	}


func _restore_legacy_store_slots(
	transaction: CardShopTransaction,
	item_ids: Array,
) -> bool:
	if item_ids.size() != transaction.shelf_slots.size():
		return false
	for index in item_ids.size():
		var item_id := StringName(item_ids[index])
		if not _shelf_item_is_valid(item_id, transaction.store_id):
			return false
		transaction.shelf_slots[index].stock(item_id)
	return true


func _restore_store_slots(
	transaction: CardShopTransaction,
	raw_slots: Array,
	unlocked_page_count: int,
) -> bool:
	if raw_slots.is_empty() or raw_slots.size() > CardShopTransaction.PAGE_SIZE * 3:
		return false
	var required_page_one_count := transaction.shelf_slots_for_page(1).size()
	var page_counts: Dictionary = {}
	var restored: Array[ShelfSlotState] = []
	var highest_page := 1
	for index in raw_slots.size():
		if not raw_slots[index] is Dictionary:
			return false
		var data := raw_slots[index] as Dictionary
		var item_id := StringName(data.get("item_id", ""))
		var page_index := int(data.get("page_index", 1))
		if (
			page_index < 1
			or page_index > ShelfSlotState.MAX_PAGE_COUNT
			or int(page_counts.get(page_index, 0)) >= CardShopTransaction.PAGE_SIZE
			or not _shelf_item_is_valid(item_id, transaction.store_id)
		):
			return false
		page_counts[page_index] = int(page_counts.get(page_index, 0)) + 1
		highest_page = maxi(highest_page, page_index)
		restored.append(ShelfSlotState.new(
			transaction.store_id,
			StringName("%s_shelf_%d" % [transaction.store_id, index + 1]),
			item_id,
			page_index,
		))
	if (
		int(page_counts.get(1, 0)) != required_page_one_count
		or unlocked_page_count < highest_page
	):
		return false
	transaction.shelf_slots = restored
	transaction.unlocked_page_count = clampi(
		unlocked_page_count,
		1,
		ShelfSlotState.MAX_PAGE_COUNT,
	)
	return true


func _shelf_item_is_valid(item_id: StringName, store_id: StringName) -> bool:
	if item_id.is_empty():
		return true
	var item := QuestArcCatalog.item_by_id(item_id)
	return item != null and item.store_id == store_id


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


func _recipe_rule_by_id(
	recipe: SynthesisRecipeDefinition,
	slot_id: StringName,
) -> CardSlotRule:
	if recipe == null:
		return null
	for raw_rule in recipe.slot_rules:
		var rule := raw_rule as CardSlotRule
		if rule != null and rule.id == slot_id:
			return rule
	return null


func _clear_synthesis_assignment_for_card(card_instance_id: int) -> bool:
	for slot_id in synthesis_assignments.keys():
		if int(synthesis_assignments[slot_id]) == card_instance_id:
			synthesis_assignments.erase(slot_id)
			return true
	return false


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
