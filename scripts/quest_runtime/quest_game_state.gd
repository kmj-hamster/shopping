class_name QuestGameState
extends RefCounted

signal state_changed
signal state_delta(delta: QuestStateDelta)

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
const RESULT_UNKNOWN_OWNER := &"unknown_owner"
const EXPEDITION_WORK_REWARD := 12
const EXPEDITION_SUCCESS_ITEM_ID := &"expedition_salvage"
const EXPEDITION_FAILURE_ITEM_ID := &"expedition_wound"

var day := 1
var wallet := PlayerWallet.new(0)
var inventory: Array[CardItemState] = []
var task_instances: Array[TaskInstanceState] = []
var task_history: Dictionary = {}
var story_flags: Dictionary = {}
var protagonist_persona_counts: Dictionary = {}
var unlocked_store_ids: Dictionary = {}
var discovered_recipe_ids: Dictionary = {}
var owner_states: Dictionary = {}
var pending_persona_reveal_ids: Array[StringName] = []
var visited_store_ids: Dictionary = {}
var bgm_playback_positions: Dictionary = {}
var pending_arc: ArcTransitionState
var expedition := MallExpeditionState.new()
var synthesis_base_instance_id := 0
var synthesis_helper_instance_id := 0
var synthesis_persona_id: StringName
var synthesis_candidate_recipe_id: StringName
var store_transactions: Dictionary = {}
var recycle_transaction: CardRecycleTransaction
var next_card_instance_id := 1
var next_task_instance_id := 1
var _change_batch_depth := 0
var _state_change_pending := false
var _pending_delta: QuestStateDelta
var _synthesis_snapshot_revision := -1
var _synthesis_input_revision := 0
var _cached_synthesis_snapshot: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_begin_change_batch()
	var content := QuestArcCatalog.manifest()
	day = 1
	wallet = PlayerWallet.new(content.initial_money if content != null else 0)
	inventory = []
	task_instances = []
	task_history = {}
	story_flags = {&"flower_request_available": &"true"}
	protagonist_persona_counts = {}
	for stat_id in CardPropertySet.PERSONAS:
		protagonist_persona_counts[stat_id] = int(
			content.initial_protagonist_stats.get(stat_id, 0) if content != null else 0
		)
	unlocked_store_ids = {}
	if content != null:
		for raw_store in content.stores:
			var store := raw_store as StoreDefinition
			if store != null and store.initially_unlocked:
				unlocked_store_ids[store.id] = true
	discovered_recipe_ids = {}
	owner_states = {}
	pending_persona_reveal_ids = []
	visited_store_ids = {}
	bgm_playback_positions = {}
	pending_arc = null
	expedition = MallExpeditionState.new()
	synthesis_base_instance_id = 0
	synthesis_helper_instance_id = 0
	synthesis_persona_id = &""
	synthesis_candidate_recipe_id = &""
	next_card_instance_id = 1
	next_task_instance_id = 1
	_build_commerce()
	if content != null:
		for item_id in content.starting_item_ids:
			grant_item(item_id, &"demo_start")
	activate_scheduled_tasks(day)
	_mark_state_changed(QuestStateDelta.new().mark_full_reconcile(&"reset"))
	_end_change_batch()


func bgm_playback_position(track_id: StringName) -> float:
	return maxf(0.0, float(bgm_playback_positions.get(track_id, 0.0)))


func remember_bgm_playback_position(track_id: StringName, position: float) -> void:
	if track_id.is_empty():
		return
	var safe_position := maxf(0.0, position)
	if is_equal_approx(bgm_playback_position(track_id), safe_position):
		return
	bgm_playback_positions[track_id] = safe_position
	# BGM progress only needs persistence; it does not invalidate gameplay UI.
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
			or not _task_is_due(definition, for_day)
			or (
				not definition.activation_store_id.is_empty()
				and not is_store_unlocked(definition.activation_store_id)
			)
			or _has_active_task_definition(definition.id)
			or (definition.repeat_interval_days <= 0 and task_history.has(definition.id))
		):
			continue
		var instance := activate_task(definition.id)
		if instance != null:
			activated.append(instance)
	return activated


func activate_task(definition_id: StringName) -> TaskInstanceState:
	var definition := QuestArcCatalog.task_by_id(definition_id)
	if (
		definition == null
		or _has_active_task_definition(definition_id)
		or (
			definition.repeat_interval_days <= 0
			and task_history.has(definition_id)
		)
	):
		return null
	var instance := TaskInstanceState.new(next_task_instance_id, definition_id, day)
	next_task_instance_id += 1
	task_instances.append(instance)
	_mark_state_changed(
		QuestStateDelta.new()
			.mark_task_list(&"task_activated")
			.mark_task_instance(instance.instance_id, &"task_activated")
	)
	return instance


func has_task_definition(definition_id: StringName) -> bool:
	if task_history.has(definition_id):
		return true
	return _has_active_task_definition(definition_id)


func _has_active_task_definition(definition_id: StringName) -> bool:
	return task_instances.any(func(instance: TaskInstanceState) -> bool:
		return instance.definition_id == definition_id and not instance.settled
	)


func _task_is_due(definition: TaskDefinition, for_day: int) -> bool:
	if definition == null or for_day < definition.activation_day:
		return false
	if definition.repeat_interval_days <= 0:
		return for_day == definition.activation_day
	return (for_day - definition.activation_day) % definition.repeat_interval_days == 0


func _activate_tasks_for_store(store_id: StringName) -> Array[TaskInstanceState]:
	var activated: Array[TaskInstanceState] = []
	var content := QuestArcCatalog.manifest()
	if content == null:
		return activated
	for raw_task in content.tasks:
		var definition := raw_task as TaskDefinition
		if (
			definition == null
			or definition.activation_store_id != store_id
		):
			continue
		var instance := activate_task(definition.id)
		if instance != null:
			activated.append(instance)
	return activated


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


func reveal_task_gift(task_instance_id: int) -> Dictionary:
	var instance := task_instance(task_instance_id)
	var definition := (
		QuestArcCatalog.task_by_id(instance.definition_id) if instance != null else null
	)
	if instance == null or instance.settled:
		return _result(false, RESULT_UNKNOWN_TASK)
	if (
		definition == null
		or definition.settlement_mode != TaskDefinition.SettlementMode.GIFT_PICKUP
	):
		return _result(false, RESULT_WRONG_SETTLEMENT)
	if instance.gift_revealed:
		return _result(true, RESULT_OK)
	instance.gift_revealed = true
	var delta := QuestStateDelta.new().mark_task_instance(
		instance.instance_id, &"task_gift_revealed"
	)
	if definition.gift_money > 0:
		wallet.money += definition.gift_money
		instance.gift_claimed = true
		delta.mark_wallet(&"task_money_gift_claimed")
	_mark_state_changed(
		delta
	)
	return _result(true, RESULT_OK, {"money": definition.gift_money})


func can_claim_task_gift(task_instance_id: int) -> bool:
	var instance := task_instance(task_instance_id)
	if (
		instance == null
		or instance.settled
		or not instance.gift_revealed
		or instance.gift_claimed
	):
		return false
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	return (
		definition != null
		and definition.settlement_mode == TaskDefinition.SettlementMode.GIFT_PICKUP
		and definition.gift_money <= 0
		and QuestArcCatalog.item_by_id(definition.gift_item_id) != null
	)


func claim_task_gift(task_instance_id: int) -> Dictionary:
	if not can_claim_task_gift(task_instance_id):
		return _result(false, RESULT_NOT_READY)
	var instance := task_instance(task_instance_id)
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	_begin_change_batch()
	var card := grant_item(definition.gift_item_id, &"task_gift")
	instance.gift_claimed = true
	_mark_state_changed(
		QuestStateDelta.new().mark_task_instance(instance.instance_id, &"task_gift_claimed")
	)
	_end_change_batch()
	return _result(true, RESULT_OK, {"card": card})


func dismiss_claimed_gift_task(task_instance_id: int) -> bool:
	var instance := task_instance(task_instance_id)
	if instance == null or instance.settled or not instance.gift_claimed:
		return false
	var definition := QuestArcCatalog.task_by_id(instance.definition_id)
	if (
		definition == null
		or definition.settlement_mode != TaskDefinition.SettlementMode.GIFT_PICKUP
	):
		return false
	instance.settled = true
	task_history[definition.id] = &"gift_collected"
	_mark_state_changed(
		QuestStateDelta.new()
			.mark_task_instance(instance.instance_id, &"task_gift_dismissed")
			.mark_task_list(&"task_gift_dismissed")
	)
	return true


func card_by_instance_id(instance_id: int) -> CardItemState:
	for card in inventory:
		if card.instance_id == instance_id:
			return card
	return null


func definition_for_card(card: CardItemState) -> CardItemDefinition:
	if card == null:
		return null
	var definition := QuestArcCatalog.item_by_id(card.definition_id)
	if definition != null:
		return definition
	return PersonaMaskCatalog.definition_for_card(card, protagonist_persona_counts)


func transaction_for_store(store_id: StringName) -> CardShopTransaction:
	return store_transactions.get(store_id) as CardShopTransaction


func checkout_store(store_id: StringName) -> Dictionary:
	var transaction := transaction_for_store(store_id)
	if transaction == null or not is_store_unlocked(store_id):
		return _result(false, RESULT_STORE_LOCKED)
	var result := transaction.checkout(day)
	if result.ok:
		_sync_next_card_instance_id()
		var delta := QuestStateDelta.new().mark_wallet(&"shop_checkout").mark_shelf(
			store_id, &"shop_checkout"
		)
		for purchased_card in result.purchased:
			delta.mark_hand_added((purchased_card as CardItemState).instance_id, &"shop_checkout")
		_mark_delta(delta)
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
		discovered_recipe_ids[recipe.id] = true
		if not recipe.unlock_story_flag.is_empty():
			story_flags[recipe.unlock_story_flag] = &"true"
	var task := activate_task(owner.request_task_id)
	if task == null:
		return _owner_result(owner, owner.idle_dialogue_key, false)
	var stocked_event_item := _stock_owner_event_item(owner)
	_mark_state_changed(
		QuestStateDelta.new().mark_shelf(owner.event_item_store_id, &"owner_event_stock")
		if stocked_event_item
		else null
	)
	return _owner_result(owner, owner.request_dialogue_key, true, task.instance_id)


func stage_recycle_card(card: CardItemState) -> Dictionary:
	var result := recycle_transaction.stage(card)
	if result.ok:
		_mark_delta(QuestStateDelta.new().mark_hand_location(card.instance_id, &"recycle_stage"))
	return result


func unstage_recycle_card(card: CardItemState) -> bool:
	var changed := recycle_transaction.unstage(card)
	if changed:
		_mark_delta(QuestStateDelta.new().mark_hand_location(card.instance_id, &"recycle_unstage"))
	return changed


func checkout_recycle() -> Dictionary:
	var removed_ids := recycle_transaction.staged_instance_ids.duplicate()
	var result := recycle_transaction.checkout()
	if result.ok:
		var delta := QuestStateDelta.new().mark_wallet(&"recycle_checkout")
		for instance_id in removed_ids:
			delta.mark_hand_removed(instance_id, &"recycle_checkout")
		_mark_delta(delta)
	return result


func cancel_recycle() -> int:
	var returned_ids := recycle_transaction.staged_instance_ids.duplicate()
	var count := recycle_transaction.cancel()
	if count > 0:
		var delta := QuestStateDelta.new()
		for instance_id in returned_ids:
			delta.mark_hand_location(instance_id, &"recycle_cancel")
		_mark_delta(delta)
	return count


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
		(transaction_value as CardShopTransaction).clear_selection()
	for card in inventory:
		if card.location == CardItemState.Location.RECYCLE:
			card.return_to_hand()
	recycle_transaction.staged_instance_ids.clear()
	if snapshot.is_empty():
		return true
	if not snapshot.has("stores") or not snapshot.stores is Dictionary:
		return false
	var stores := snapshot.stores as Dictionary
	if stores.size() != store_transactions.size():
		return false
	for raw_store_id in stores:
		var store_id := StringName(raw_store_id)
		var transaction := transaction_for_store(store_id)
		if transaction == null:
			return false
		var store_snapshot: Variant = stores[raw_store_id]
		if not store_snapshot is Dictionary:
			return false
		var data := store_snapshot as Dictionary
		if not _restore_store_slots(
			transaction,
			data.get("slots", []) as Array,
			int(data.get("unlocked_page_count", 1)),
		):
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
		if owned.location == CardItemState.Location.HAND:
			hand_cards.append(owned)
	var original_index := hand_cards.find(card)
	hand_cards.erase(card)
	var normalized_index := clampi(target_index, 0, hand_cards.size())
	if original_index == normalized_index:
		return true
	hand_cards.insert(normalized_index, card)
	# Rewrite only the hand positions. This keeps assigned/recycled entries in
	# place and avoids using an inventory index that becomes stale after erase().
	var hand_index := 0
	for inventory_index in inventory.size():
		if inventory[inventory_index].location != CardItemState.Location.HAND:
			continue
		inventory[inventory_index] = hand_cards[hand_index]
		hand_index += 1
	_mark_state_changed(QuestStateDelta.new().mark_hand_order(&"hand_reorder"))
	return true


func move_card_to_hand(card: CardItemState, target_index: int) -> bool:
	if card == null or not inventory.has(card):
		return false
	_begin_change_batch()
	var returned := true
	if card.location == CardItemState.Location.ACTIVITY_SLOT:
		returned = return_card_to_hand(card)
	elif card.location == CardItemState.Location.RECYCLE:
		returned = unstage_recycle_card(card)
	elif card.location != CardItemState.Location.HAND:
		returned = false
	var reordered := reorder_hand_card(card, target_index) if returned else false
	_end_change_batch()
	return returned and reordered


func refill_scheduled_shelves(for_day: int = day) -> void:
	var content := QuestArcCatalog.manifest()
	if content == null:
		return
	for raw_store in content.stores:
		var store := raw_store as StoreDefinition
		var transaction := transaction_for_store(store.id) if store != null else null
		if store == null or transaction == null or not store.is_restock_day(for_day):
			continue
		transaction.clear_selection()
		for index in mini(store.initial_shelf_item_ids.size(), transaction.shelf_slots.size()):
			var slot := transaction.shelf_slots[index]
			var item := QuestArcCatalog.item_by_id(store.initial_shelf_item_ids[index])
			if (
				slot.is_empty()
				and item != null
				and item.supply_mode == QuestItemDefinition.SupplyMode.DAILY_BASIC
			):
				slot.stock(item.id)
	_mark_state_changed()


func restock_nights_remaining(store_id: StringName) -> int:
	var store := QuestArcCatalog.store_by_id(store_id)
	return store.nights_until_restock(day) if store != null else 0


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
	_mark_state_changed(QuestStateDelta.new().mark_hand_added(card.instance_id, &"item_granted"))
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
	var item := definition_for_card(card)
	var effective_rule := effective_task_rule(instance, rule)
	var evaluation := CardRuleEvaluator.evaluate(effective_rule, item)
	if not evaluation.can_place:
		return _result(false, RESULT_REJECTED, evaluation)
	var occupied_id := instance.assigned_instance_id(slot_id)
	var replaced_card: CardItemState = (
		card_by_instance_id(occupied_id)
		if occupied_id > 0 and occupied_id != card.instance_id
		else null
	)
	if occupied_id > 0 and occupied_id != card.instance_id and replaced_card == null:
		return _result(false, RESULT_OCCUPIED, evaluation)
	_remove_card_assignment(card)
	if replaced_card != null:
		instance.clear_assignment_for_card(replaced_card.instance_id)
		replaced_card.return_to_hand()
	instance.assignments[slot_id] = card.instance_id
	card.assign_to(StringName(str(instance.instance_id)), slot_id)
	var delta := (
		QuestStateDelta.new()
			.mark_hand_location(card.instance_id, &"task_assignment")
			.mark_task_instance(instance.instance_id, &"task_assignment")
	)
	if replaced_card != null:
		delta.mark_hand_location(replaced_card.instance_id, &"task_card_replaced")
	if previous_task != null and previous_task != instance:
		delta.mark_task_instance(previous_task.instance_id, &"task_reassignment")
	_mark_state_changed(delta)
	return _result(true, RESULT_OK, evaluation)


func return_card_to_hand(card: CardItemState) -> bool:
	if card == null or not inventory.has(card) or card.location != CardItemState.Location.ACTIVITY_SLOT:
		return false
	var was_synthesis_material := card.activity_id == &"synthesis"
	var instance := _task_containing_card(card.instance_id)
	if instance != null:
		if instance.confirmed:
			return false
		instance.clear_assignment_for_card(card.instance_id)
	elif not _clear_synthesis_assignment_for_card(card.instance_id):
		return false
	card.return_to_hand()
	var delta := QuestStateDelta.new().mark_hand_location(card.instance_id, &"return_to_hand")
	if was_synthesis_material:
		delta.mark_synthesis_draft(&"synthesis_material_returned")
		_mark_transient_changed(delta, true)
	else:
		if instance != null:
			delta.mark_task_instance(instance.instance_id, &"task_card_returned")
		_mark_state_changed(delta)
	return true


func clear_synthesis_draft() -> bool:
	var changed := (
		synthesis_base_instance_id > 0
		or synthesis_helper_instance_id > 0
		or not synthesis_persona_id.is_empty()
		or not synthesis_candidate_recipe_id.is_empty()
	)
	var delta := QuestStateDelta.new().mark_synthesis_draft(&"synthesis_clear")
	for card_id in [synthesis_base_instance_id, synthesis_helper_instance_id]:
		var card := card_by_instance_id(card_id)
		if card != null:
			card.return_to_hand()
			changed = true
			delta.mark_hand_location(card.instance_id, &"synthesis_clear")
	synthesis_base_instance_id = 0
	synthesis_helper_instance_id = 0
	synthesis_persona_id = &""
	synthesis_candidate_recipe_id = &""
	if changed:
		_mark_transient_changed(delta, true)
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


func assign_synthesis_base(card: CardItemState) -> Dictionary:
	return _assign_synthesis_card(&"base", card)


func assign_synthesis_helper(card: CardItemState) -> Dictionary:
	if synthesis_base_instance_id <= 0 or card == null or card.instance_id == synthesis_base_instance_id:
		return _result(false, RESULT_NOT_READY)
	return _assign_synthesis_card(&"helper", card)


func _assign_synthesis_card(role_id: StringName, card: CardItemState) -> Dictionary:
	if role_id not in [&"base", &"helper"]:
		return _result(false, RESULT_UNKNOWN_SLOT)
	if card == null or not inventory.has(card):
		return _result(false, RESULT_NOT_OWNED)
	var previous_task := _task_containing_card(card.instance_id)
	if previous_task != null and previous_task.confirmed:
		return _result(false, RESULT_LOCKED)
	var occupied_id := (
		synthesis_base_instance_id if role_id == &"base" else synthesis_helper_instance_id
	)
	var previous_helper := (
		card_by_instance_id(synthesis_helper_instance_id)
		if role_id == &"base" and synthesis_helper_instance_id > 0
		else null
	)
	var replaced_card := (
		card_by_instance_id(occupied_id)
		if occupied_id > 0 and occupied_id != card.instance_id
		else null
	)
	if previous_task != null:
		previous_task.clear_assignment_for_card(card.instance_id)
	if role_id == &"base":
		_clear_synthesis_reinforcement()
	_clear_synthesis_assignment_for_card(card.instance_id)
	if replaced_card != null:
		_clear_synthesis_assignment_for_card(replaced_card.instance_id)
		replaced_card.return_to_hand()
	if role_id == &"base":
		synthesis_base_instance_id = card.instance_id
	else:
		synthesis_helper_instance_id = card.instance_id
	card.assign_to(&"synthesis", role_id)
	synthesis_candidate_recipe_id = &""
	var delta := (
		QuestStateDelta.new()
			.mark_hand_location(card.instance_id, &"synthesis_assignment")
			.mark_synthesis_draft(&"synthesis_assignment")
	)
	if replaced_card != null:
		delta.mark_hand_location(replaced_card.instance_id, &"synthesis_card_replaced")
	if previous_helper != null and previous_helper != card and previous_helper != replaced_card:
		delta.mark_hand_location(previous_helper.instance_id, &"synthesis_helper_returned")
	if previous_task != null:
		delta.mark_task_instance(previous_task.instance_id, &"task_to_synthesis")
		_mark_state_changed(delta)
	else:
		_mark_transient_changed(delta, true)
	return _result(true, RESULT_OK)


func select_synthesis_persona(persona_id: StringName) -> bool:
	if (
		synthesis_base_instance_id <= 0
		or persona_id not in CardPropertySet.PERSONAS
		or int(protagonist_persona_counts.get(persona_id, 0)) <= 0
	):
		return false
	synthesis_persona_id = &"" if synthesis_persona_id == persona_id else persona_id
	synthesis_candidate_recipe_id = &""
	_mark_transient_changed(
		QuestStateDelta.new().mark_synthesis_persona(&"synthesis_persona"),
		true,
	)
	return true


func synthesis_base_card() -> CardItemState:
	return card_by_instance_id(synthesis_base_instance_id)


func synthesis_helper_card() -> CardItemState:
	return card_by_instance_id(synthesis_helper_instance_id)


func synthesis_persona_totals() -> Dictionary:
	return (synthesis_evaluation_snapshot().totals as Dictionary).duplicate()


func synthesis_evaluation_snapshot() -> Dictionary:
	if _synthesis_snapshot_revision == _synthesis_input_revision:
		return _cached_synthesis_snapshot
	var base_card := synthesis_base_card()
	var helper_card := synthesis_helper_card()
	var base_item := (
		QuestArcCatalog.item_by_id(base_card.definition_id) if base_card != null else null
	)
	var totals := SynthesisRules.persona_totals(
		base_item,
		QuestArcCatalog.item_by_id(helper_card.definition_id) if helper_card != null else null,
		synthesis_persona_id,
		protagonist_persona_counts,
	)
	var candidates: Array[Dictionary] = []
	if base_item != null:
		for recipe_id in available_synthesis_recipe_ids():
			var recipe := QuestArcCatalog.recipe_by_id(recipe_id)
			var evaluation := SynthesisRules.evaluate_candidate(recipe, base_item, totals)
			if evaluation.is_visible:
				evaluation["recipe_id"] = recipe.id
				evaluation["required_personas"] = recipe.required_personas.duplicate()
				evaluation["is_discovered"] = discovered_recipe_ids.has(recipe.id)
				evaluation["shows_output"] = (
					evaluation.is_complete or discovered_recipe_ids.has(recipe.id)
				)
				candidates.append(evaluation)
	_cached_synthesis_snapshot = {
		"base_card": base_card,
		"helper_card": helper_card,
		"base_item": base_item,
		"totals": totals,
		"candidates": candidates,
	}
	_synthesis_snapshot_revision = _synthesis_input_revision
	return _cached_synthesis_snapshot


func synthesis_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(synthesis_evaluation_snapshot().candidates)
	return result


func select_synthesis_candidate(recipe_id: StringName) -> bool:
	for candidate in synthesis_candidates():
		if StringName(candidate.recipe_id) != recipe_id:
			continue
		synthesis_candidate_recipe_id = recipe_id
		var delta := QuestStateDelta.new().mark_synthesis_candidate(&"synthesis_candidate")
		if candidate.is_complete and not discovered_recipe_ids.has(recipe_id):
			discovered_recipe_ids[recipe_id] = true
			_mark_state_changed(delta)
		else:
			_mark_transient_changed(delta)
		return true
	return false


func clear_synthesis_candidate() -> bool:
	if synthesis_candidate_recipe_id.is_empty():
		return false
	synthesis_candidate_recipe_id = &""
	_mark_transient_changed(
		QuestStateDelta.new().mark_synthesis_candidate(&"synthesis_candidate_cleared")
	)
	return true


func begin_synthesis() -> Dictionary:
	var recipe := QuestArcCatalog.recipe_by_id(synthesis_candidate_recipe_id)
	if recipe == null or not recipe_is_available(recipe.id):
		return _result(false, RESULT_UNKNOWN_RECIPE)
	var selected: Dictionary = {}
	for candidate in synthesis_candidates():
		if StringName(candidate.recipe_id) == recipe.id:
			selected = candidate
			break
	if selected.is_empty() or not selected.is_complete:
		return _result(false, RESULT_NOT_READY, selected)
	var input_ids: Array[int] = [synthesis_base_instance_id]
	if synthesis_helper_instance_id > 0:
		input_ids.append(synthesis_helper_instance_id)
	for card_id in input_ids:
		var card := card_by_instance_id(card_id)
		if card == null or card.activity_id != &"synthesis":
			return _result(false, RESULT_NOT_READY)
	_begin_change_batch()
	var delta := (
		QuestStateDelta.new()
		.mark_synthesis_draft(&"synthesis_complete")
		.mark_synthesis_persona(&"synthesis_persona_returned")
	)
	for card_id in input_ids:
		inventory.erase(card_by_instance_id(card_id))
		delta.mark_hand_removed(card_id, &"synthesis_complete")
	discovered_recipe_ids[recipe.id] = true
	synthesis_base_instance_id = 0
	synthesis_helper_instance_id = 0
	synthesis_persona_id = &""
	synthesis_candidate_recipe_id = &""
	var output := grant_item(recipe.output_id, &"synthesis")
	_mark_state_changed(delta)
	_end_change_batch()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"output": output,
		"recipe_id": recipe.id,
		"process_text_keys": recipe.process_text_keys.duplicate(),
	}


func effective_task_rule(
	_instance: TaskInstanceState,
	base_rule: CardSlotRule,
) -> CardSlotRule:
	return base_rule


func can_assign_card_to_task(
	task_instance_id: int,
	slot_id: StringName,
	card: CardItemState,
) -> bool:
	var instance := task_instance(task_instance_id)
	var definition := (
		QuestArcCatalog.task_by_id(instance.definition_id) if instance != null else null
	)
	var rule := _rule_by_id(definition, slot_id)
	return (
		instance != null
		and not instance.confirmed
		and card != null
		and card in inventory
		and CardRuleEvaluator.can_place(
			effective_task_rule(instance, rule),
			definition_for_card(card),
		)
	)


func item_category_ids(item: CardItemDefinition) -> Array[StringName]:
	var result: Array[StringName] = []
	if item == null or item.property_set == null:
		return result
	for property_id in item.property_set.property_ids():
		var property := QuestArcCatalog.property_by_id(property_id)
		if property != null and property.is_item_category and property_id not in result:
			result.append(property_id)
	return result


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
		var item := definition_for_card(card)
		var evaluation := CardRuleEvaluator.evaluate(
			effective_task_rule(instance, rule), item
		)
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
	_mark_state_changed(
		QuestStateDelta.new().mark_task_instance(instance.instance_id, &"task_confirmed")
	)
	return _result(true, RESULT_OK, evaluation)


func cancel_task_confirmation(task_instance_id: int) -> bool:
	# shopping0807 treats submission as a permanent choice.
	# Keep this API for save compatibility, but never reopen a submitted task.
	return false


func _self_care_growth_for_items(item_definition_ids: Array[StringName]) -> Dictionary:
	var persona_totals: Dictionary = {}
	for persona_id in CardPropertySet.PERSONAS:
		persona_totals[persona_id] = 0
	for item_definition_id in item_definition_ids:
		var item := QuestArcCatalog.item_by_id(item_definition_id)
		if item == null:
			continue
		for persona_id in CardPropertySet.PERSONAS:
			persona_totals[persona_id] = (
				int(persona_totals[persona_id]) + item.property_value(persona_id)
			)
	var result: Dictionary = {}
	for persona_id in CardPropertySet.PERSONAS:
		var difference := int(persona_totals.get(persona_id, 0)) - int(
			protagonist_persona_counts.get(persona_id, 0)
		)
		if difference > 0:
			result[persona_id] = 1
	return result


func acknowledge_persona_reveal(persona_id: StringName) -> bool:
	if persona_id not in pending_persona_reveal_ids:
		return false
	pending_persona_reveal_ids.erase(persona_id)
	_mark_state_changed()
	return true


func begin_mall_expedition(seed_value: int = 0) -> Dictionary:
	if expedition.active:
		return _result(false, RESULT_TRANSITION_ACTIVE)
	var content := QuestArcCatalog.manifest()
	if content == null or content.expedition_rooms.is_empty():
		return _result(false, RESULT_NOT_READY)
	var selected_seed := seed_value
	if selected_seed <= 0:
		selected_seed = maxi(
			1,
			int(Time.get_unix_time_from_system()) ^ (day * 104729) ^ next_card_instance_id,
		)
	expedition.begin_night(day, selected_seed)
	_generate_expedition_doors()
	_mark_state_changed(QuestStateDelta.new().mark_full_reconcile(&"expedition_started"))
	return {
		"ok": true,
		"reason": RESULT_OK,
		"door_ids": expedition.current_door_ids.duplicate(),
	}


func evaluate_expedition_challenge_round(
	room_id: StringName,
	card_instance_ids: Array[int],
	persona_ids: Array[StringName],
	approach_index: int,
	round_index: int = 0,
) -> Dictionary:
	var room := QuestArcCatalog.mall_room_by_id(room_id)
	if (
		room == null
		or room.category not in [
			MallRoomDefinition.Category.CHALLENGE,
			MallRoomDefinition.Category.BOSS,
		]
		or approach_index < 0
		or approach_index >= room.approach_title_keys.size()
		or round_index < 0
		or round_index >= room.boss_round_count
		or card_instance_ids.size() + persona_ids.size() > room.slot_count
	):
		return _result(false, RESULT_NOT_READY)
	var resolved := _expedition_input_definitions(card_instance_ids, persona_ids)
	if not bool(resolved.ok):
		return resolved
	var evaluation := MallChallengeRules.evaluate(room, resolved.definitions)
	var roll := _expedition_challenge_roll(
		room_id,
		card_instance_ids,
		persona_ids,
		approach_index,
		round_index,
	)
	evaluation["ok"] = true
	evaluation["reason"] = RESULT_OK
	evaluation["roll_percent"] = roll
	evaluation["success"] = MallChallengeRules.succeeds(evaluation, roll)
	return evaluation


func complete_expedition_room(
	room_id: StringName,
	card_instance_ids: Array[int] = [],
	persona_ids: Array[StringName] = [],
	challenge_rounds: Array[Dictionary] = [],
) -> Dictionary:
	if not expedition.active or not expedition.has_current_door(room_id):
		return _result(false, RESULT_NOT_READY)
	var room := QuestArcCatalog.mall_room_by_id(room_id)
	if room == null:
		return _result(false, RESULT_NOT_READY)
	var consumed_ids: Array[int] = []
	var persona_growth: Dictionary = {}
	var money_gained := 0
	var reward_item_id: StringName
	var new_persona_ids: Array[StringName] = []
	var room_success := true
	var boss_failed := false
	var demo_complete := false

	match room.category:
		MallRoomDefinition.Category.CHALLENGE, MallRoomDefinition.Category.BOSS:
			var challenge_result := _resolve_expedition_challenge_submission(
				room, challenge_rounds
			)
			if not bool(challenge_result.ok):
				return challenge_result
			consumed_ids = _int_array_from_variant(challenge_result.consumed_card_ids)
			room_success = bool(challenge_result.success)
			boss_failed = room.category == MallRoomDefinition.Category.BOSS and not room_success
			demo_complete = room.category == MallRoomDefinition.Category.BOSS and room_success
			reward_item_id = (
				EXPEDITION_SUCCESS_ITEM_ID if room_success else EXPEDITION_FAILURE_ITEM_ID
			)
		MallRoomDefinition.Category.REST:
			var rest_result := _resolve_expedition_rest_submission(
				room, card_instance_ids, persona_ids
			)
			if not bool(rest_result.ok):
				return rest_result
			consumed_ids = _int_array_from_variant(rest_result.consumed_card_ids)
			persona_growth = rest_result.persona_growth
			money_gained = int(rest_result.money_gained)
		MallRoomDefinition.Category.WORK:
			if not card_instance_ids.is_empty() or not persona_ids.is_empty():
				return _result(false, RESULT_REJECTED)
			money_gained = EXPEDITION_WORK_REWARD

	_begin_change_batch()
	var delta := QuestStateDelta.new().mark_full_reconcile(&"expedition_room_committed")
	for card_id in consumed_ids:
		var card := card_by_instance_id(card_id)
		if card != null:
			inventory.erase(card)
			delta.mark_hand_removed(card.instance_id, &"expedition_consumed")
	for raw_persona_id in persona_growth:
		var persona_id := StringName(raw_persona_id)
		var previous_amount := int(protagonist_persona_counts.get(persona_id, 0))
		protagonist_persona_counts[persona_id] = previous_amount + int(
			persona_growth[raw_persona_id]
		)
		if previous_amount <= 0 and int(persona_growth[raw_persona_id]) > 0:
			if persona_id not in pending_persona_reveal_ids:
				pending_persona_reveal_ids.append(persona_id)
			new_persona_ids.append(persona_id)
		delta.mark_synthesis_persona(&"expedition_persona_growth")
	if money_gained > 0:
		wallet.money += money_gained
	if not reward_item_id.is_empty():
		grant_item(reward_item_id, &"expedition")
	expedition.discovered_room_ids[room.id] = true
	expedition.entered_room_ids[room.id] = true
	if room.category == MallRoomDefinition.Category.CHALLENGE and room_success:
		expedition.first_cleared_challenge_ids[room.id] = true
	if demo_complete:
		expedition.boss_cleared = true
		expedition.active = false
		expedition.current_door_ids.clear()
	elif boss_failed:
		_finish_expedition_night(delta)
	else:
		expedition.rooms_completed += 1
		if expedition.reached_night_limit():
			_finish_expedition_night(delta)
		else:
			_generate_expedition_doors()
	_mark_state_changed(delta)
	_end_change_batch()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"success": room_success,
		"boss_failed": boss_failed,
		"demo_complete": demo_complete,
		"night_finished": not expedition.active and not demo_complete,
		"reward_item_id": reward_item_id,
		"money_gained": money_gained,
		"persona_growth": persona_growth,
		"new_persona_ids": new_persona_ids,
		"door_ids": expedition.current_door_ids.duplicate(),
	}


func expedition_card_can_be_used(card: CardItemState) -> bool:
	if card == null or not inventory.has(card) or card.location != CardItemState.Location.HAND:
		return false
	return MallChallengeRules.can_use_in_challenge(definition_for_card(card))


func expedition_room_accepts_card(
	room_id: StringName,
	card: CardItemState,
	persona_id: StringName = &"",
) -> bool:
	var room := QuestArcCatalog.mall_room_by_id(room_id)
	if room == null:
		return false
	if not persona_id.is_empty():
		return (
			int(protagonist_persona_counts.get(persona_id, 0)) > 0
			and (
				room.category in [
					MallRoomDefinition.Category.CHALLENGE,
					MallRoomDefinition.Category.BOSS,
				]
				or room.rest_mode == MallRoomDefinition.RestMode.PERSONA_GROWTH
			)
		)
	if not expedition_card_can_be_used(card):
		return false
	var definition := definition_for_card(card)
	if room.category in [
		MallRoomDefinition.Category.CHALLENGE,
		MallRoomDefinition.Category.BOSS,
	]:
		return true
	if room.rest_mode == MallRoomDefinition.RestMode.SALVAGE:
		return definition != null and definition.can_recycle
	if room.rest_mode != MallRoomDefinition.RestMode.ITEM_GROWTH:
		return false
	return room.allowed_type_ids.is_empty() or room.allowed_type_ids.any(
		func(type_id: StringName) -> bool: return definition.has_property(type_id)
	)


func _resolve_expedition_challenge_submission(
	room: MallRoomDefinition,
	challenge_rounds: Array[Dictionary],
) -> Dictionary:
	if challenge_rounds.is_empty() or challenge_rounds.size() > room.boss_round_count:
		return _result(false, RESULT_NOT_READY)
	if room.category == MallRoomDefinition.Category.CHALLENGE and challenge_rounds.size() != 1:
		return _result(false, RESULT_NOT_READY)
	var consumed_ids: Array[int] = []
	var all_success := true
	for round_index in challenge_rounds.size():
		var round := challenge_rounds[round_index]
		var round_card_ids := _int_array_from_variant(round.get("card_instance_ids", []))
		var round_persona_ids := _name_array_from_variant(round.get("persona_ids", []))
		for card_id in round_card_ids:
			if card_id in consumed_ids:
				return _result(false, RESULT_REJECTED)
		var evaluation := evaluate_expedition_challenge_round(
			room.id,
			round_card_ids,
			round_persona_ids,
			int(round.get("approach_index", -1)),
			round_index,
		)
		if not bool(evaluation.ok):
			return evaluation
		consumed_ids.append_array(round_card_ids)
		if not bool(evaluation.success):
			all_success = false
			break
	if room.category == MallRoomDefinition.Category.BOSS:
		all_success = all_success and challenge_rounds.size() == room.boss_round_count
	return {
		"ok": true,
		"reason": RESULT_OK,
		"success": all_success,
		"consumed_card_ids": consumed_ids,
	}


func _resolve_expedition_rest_submission(
	room: MallRoomDefinition,
	card_instance_ids: Array[int],
	persona_ids: Array[StringName],
) -> Dictionary:
	if card_instance_ids.size() + persona_ids.size() > room.slot_count:
		return _result(false, RESULT_REJECTED)
	if room.rest_mode == MallRoomDefinition.RestMode.PERSONA_GROWTH:
		if card_instance_ids.size() > 0 or persona_ids.size() != 1:
			return _result(false, RESULT_NOT_READY)
		var persona_id := persona_ids[0]
		if int(protagonist_persona_counts.get(persona_id, 0)) <= 0:
			return _result(false, RESULT_REJECTED)
		return {
			"ok": true,
			"reason": RESULT_OK,
			"consumed_card_ids": [],
			"persona_growth": {persona_id: 1},
			"money_gained": 0,
		}
	if not persona_ids.is_empty():
		return _result(false, RESULT_REJECTED)
	var resolved_cards: Array[CardItemState] = []
	var seen_card_ids: Dictionary = {}
	for card_id in card_instance_ids:
		var card := card_by_instance_id(card_id)
		if (
			seen_card_ids.has(card_id)
			or card == null
			or not expedition_room_accepts_card(room.id, card)
		):
			return _result(false, RESULT_REJECTED)
		seen_card_ids[card_id] = true
		resolved_cards.append(card)
	if room.rest_mode == MallRoomDefinition.RestMode.SALVAGE:
		var total := 0
		for card in resolved_cards:
			var definition := definition_for_card(card)
			total += card.purchase_price if card.purchase_price > 0 else definition.resale_value()
		return {
			"ok": true,
			"reason": RESULT_OK,
			"consumed_card_ids": card_instance_ids.duplicate(),
			"persona_growth": {},
			"money_gained": total,
		}
	var growth: Dictionary = {}
	if not resolved_cards.is_empty():
		var definition := definition_for_card(resolved_cards[0])
		for persona_id in CardPropertySet.PERSONAS:
			if definition.property_value(persona_id) > int(
				protagonist_persona_counts.get(persona_id, 0)
			):
				growth[persona_id] = 1
	return {
		"ok": true,
		"reason": RESULT_OK,
		"consumed_card_ids": card_instance_ids.duplicate(),
		"persona_growth": growth,
		"money_gained": 0,
	}


func _expedition_input_definitions(
	card_instance_ids: Array[int],
	persona_ids: Array[StringName],
) -> Dictionary:
	var definitions: Array[CardItemDefinition] = []
	var seen_card_ids: Dictionary = {}
	for card_id in card_instance_ids:
		var card := card_by_instance_id(card_id)
		if seen_card_ids.has(card_id) or not expedition_card_can_be_used(card):
			return _result(false, RESULT_REJECTED)
		seen_card_ids[card_id] = true
		definitions.append(definition_for_card(card))
	for persona_id in persona_ids:
		var amount := int(protagonist_persona_counts.get(persona_id, 0))
		if persona_id not in CardPropertySet.PERSONAS or amount <= 0:
			return _result(false, RESULT_REJECTED)
		definitions.append(_expedition_persona_definition(persona_id, amount))
	return {"ok": true, "reason": RESULT_OK, "definitions": definitions}


func _expedition_persona_definition(persona_id: StringName, amount: int) -> CardItemDefinition:
	var properties := CardPropertySet.new()
	properties.tags = [CardPropertySet.PROPERTY_PERSONA]
	properties.values = {persona_id: amount}
	var definition := CardItemDefinition.new()
	definition.id = StringName("expedition_persona_%s" % persona_id)
	definition.property_set = properties
	return definition


func _expedition_challenge_roll(
	room_id: StringName,
	card_instance_ids: Array[int],
	persona_ids: Array[StringName],
	approach_index: int,
	round_index: int,
) -> int:
	var card_key := card_instance_ids.duplicate()
	card_key.sort()
	var persona_key := persona_ids.duplicate()
	persona_key.sort()
	var signature := "%d|%d|%s|%d|%d|%s|%s" % [
		expedition.rng_seed,
		expedition.checkpoint_serial,
		room_id,
		approach_index,
		round_index,
		card_key,
		persona_key,
	]
	return absi(hash(signature)) % 100


func _generate_expedition_doors() -> void:
	var content := QuestArcCatalog.manifest()
	if content == null:
		expedition.current_door_ids.clear()
		return
	var rng := RandomNumberGenerator.new()
	if expedition.rng_state != 0:
		rng.state = expedition.rng_state
	else:
		rng.seed = expedition.rng_seed
	expedition.current_door_ids = MallDoorGenerator.generate(
		expedition, content.expedition_rooms, rng
	)
	expedition.rng_state = rng.state
	expedition.checkpoint_serial += 1


func _finish_expedition_night(delta: QuestStateDelta) -> void:
	day += 1
	expedition.end_night()
	refill_scheduled_shelves(day)
	delta.mark_day(&"expedition_night_finished")
	for store_id in store_transactions:
		delta.mark_shelf(StringName(store_id), &"expedition_shelf_refill")


func _int_array_from_variant(values: Variant) -> Array[int]:
	var result: Array[int] = []
	for value in values as Array:
		result.append(int(value))
	return result


func _name_array_from_variant(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values as Array:
		result.append(StringName(value))
	return result


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
			elif effect.kind == StoryEffect.Kind.ADD_PROTAGONIST_PERSONA:
				reward_stats[effect.target_id] = int(
					reward_stats.get(effect.target_id, 0)
				) + effect.amount
		var persona_growth := (
			_self_care_growth_for_items(item_definition_ids)
			if definition.category == TaskDefinition.Category.SELF_CARE
			else {}
		)
		for raw_persona_id in persona_growth:
			var persona_id := StringName(raw_persona_id)
			reward_stats[persona_id] = int(reward_stats.get(persona_id, 0)) + int(
				persona_growth[raw_persona_id]
		)
		entries.append({
			"task_instance_id": instance.instance_id,
			"task_definition_id": definition.id,
			"outcome_id": outcome.id,
			"result_text_key": outcome.result_text_key,
			"card_instance_ids": instance.assigned_instance_ids(),
			"item_definition_ids": item_definition_ids,
			"reward_money": reward_money,
			"reward_stats": reward_stats,
			"persona_growth": persona_growth,
		})
	var confirmed_task_count := entries.size()
	pending_arc = ArcTransitionState.new(day, entries)
	_mark_state_changed()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"confirmed_task_count": confirmed_task_count,
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
		var outcome := (
			definition.outcome_by_id(StringName(entry.outcome_id))
			if definition != null
			else null
		)
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
			"entry": entry,
			"instance": instance,
			"definition": definition,
			"outcome": outcome,
			"cards": cards,
			"items": items,
		})
	_begin_change_batch()
	var consumed_count := 0
	var hand_delta := QuestStateDelta.new()
	var money_before := wallet.money
	for resolved in resolved_entries:
		var instance := resolved.instance as TaskInstanceState
		var definition := resolved.definition as TaskDefinition
		var outcome := resolved.outcome as TaskOutcomeDefinition
		var entry := resolved.entry as Dictionary
		for raw_effect in outcome.effects:
			_apply_story_effect(raw_effect as StoryEffect, hand_delta)
		for raw_persona_id in (entry.get("persona_growth", {}) as Dictionary):
			var persona_id := StringName(raw_persona_id)
			var previous_amount := int(protagonist_persona_counts.get(persona_id, 0))
			var growth := int((entry.persona_growth as Dictionary)[raw_persona_id])
			protagonist_persona_counts[persona_id] = previous_amount + growth
			if previous_amount <= 0 and growth > 0 and persona_id not in pending_persona_reveal_ids:
				pending_persona_reveal_ids.append(persona_id)
			if growth > 0:
				hand_delta.mark_synthesis_persona(&"self_care_growth")
		for raw_card in resolved.cards:
			var consumed_card := raw_card as CardItemState
			inventory.erase(consumed_card)
			hand_delta.mark_hand_removed(consumed_card.instance_id, &"arc_settlement")
			consumed_count += 1
		instance.assignments.clear()
		instance.confirmed = false
		instance.settled = true
		hand_delta.mark_task_instance(instance.instance_id, &"arc_settlement")
		task_history[definition.id] = outcome.id
	pending_arc.effects_applied = true
	if not resolved_entries.is_empty():
		hand_delta.mark_task_list(&"arc_settlement")
	_mark_state_changed(hand_delta)
	_end_change_batch()
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
	_mark_state_changed()
	return true


func finish_arc() -> Dictionary:
	if pending_arc == null:
		return _result(false, RESULT_NO_TRANSITION)
	if not pending_arc.is_complete():
		return _result(false, RESULT_EFFECTS_PENDING)
	_begin_change_batch()
	day += 1
	pending_arc = null
	refill_scheduled_shelves(day)
	var activated := activate_scheduled_tasks(day)
	var finish_delta := QuestStateDelta.new().mark_day(&"arc_finished")
	for store_id in store_transactions:
		finish_delta.mark_shelf(StringName(store_id), &"daily_shelf_refill")
	_mark_state_changed(finish_delta)
	_end_change_batch()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"day": day,
		"activated_task_instance_ids": activated.map(
			func(instance: TaskInstanceState) -> int: return instance.instance_id
		),
	}


func is_store_unlocked(store_id: StringName) -> bool:
	return unlocked_store_ids.has(store_id)


func is_store_visible(store_id: StringName) -> bool:
	var store := QuestArcCatalog.store_by_id(store_id)
	if store == null:
		return false
	for prerequisite_store_id in store.visible_after_store_ids:
		if not is_store_unlocked(prerequisite_store_id):
			return false
	return true


func has_visited_store(store_id: StringName) -> bool:
	return visited_store_ids.has(store_id)


func mark_store_visited(store_id: StringName) -> bool:
	if has_visited_store(store_id):
		return false
	visited_store_ids[store_id] = true
	_mark_state_changed()
	return true


func unlock_store(store_id: StringName, card: CardItemState) -> Dictionary:
	var store := QuestArcCatalog.store_by_id(store_id)
	if store == null or not is_store_visible(store_id):
		return _result(false, RESULT_STORE_LOCKED)
	if is_store_unlocked(store_id):
		return _result(false, RESULT_STORE_ALREADY_OPEN)
	var unlock := QuestArcCatalog.store_unlock_for_store(store_id)
	if unlock == null or card == null or card.location != CardItemState.Location.HAND:
		return _result(false, RESULT_NOT_OWNED)
	var item := definition_for_card(card)
	var persona_id := PersonaMaskCatalog.persona_for_card(card)
	if not persona_id.is_empty() and int(protagonist_persona_counts.get(persona_id, 0)) <= 0:
		return _result(false, RESULT_REJECTED)
	if unlock == null or not QuestArcRules.store_unlock_accepts(unlock, item):
		return _result(false, RESULT_REJECTED)
	var is_persona := not persona_id.is_empty()
	if unlock.consume_item and (is_persona or not inventory.has(card)):
		return _result(false, RESULT_NOT_OWNED)
	if not unlock.consume_item and not is_persona:
		return _result(false, RESULT_REJECTED)
	_begin_change_batch()
	if unlock.consume_item:
		inventory.erase(card)
	unlocked_store_ids[store_id] = true
	var activated := _activate_tasks_for_store(store_id)
	var delta := QuestStateDelta.new().mark_store_state(store_id, &"store_unlock")
	if unlock.consume_item:
		delta.mark_hand_removed(card.instance_id, &"store_unlock")
	_mark_state_changed(
		delta
	)
	_end_change_batch()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"store_id": store_id,
		"consumed_instance_id": card.instance_id if unlock.consume_item else 0,
		"activated_task_instance_ids": activated.map(
			func(instance: TaskInstanceState) -> int: return instance.instance_id
		),
		"result_text_key": unlock.result_text_key,
	}


func _apply_story_effect(effect: StoryEffect, delta: QuestStateDelta = null) -> void:
	if effect == null:
		return
	match effect.kind:
		StoryEffect.Kind.ADD_MONEY:
			wallet.money += effect.amount
			if delta != null:
				delta.mark_wallet(&"story_effect")
		StoryEffect.Kind.SET_FLAG:
			story_flags[effect.target_id] = effect.text_value
		StoryEffect.Kind.ADD_PROTAGONIST_PERSONA:
			var previous_amount := int(
				protagonist_persona_counts.get(effect.target_id, 0)
			)
			protagonist_persona_counts[effect.target_id] = previous_amount + effect.amount
			if (
				previous_amount <= 0
				and effect.amount > 0
				and effect.target_id not in pending_persona_reveal_ids
			):
				pending_persona_reveal_ids.append(effect.target_id)
			if delta != null:
				delta.mark_synthesis_persona(&"story_effect")
		StoryEffect.Kind.DISCOVER_RECIPE:
			discovered_recipe_ids[effect.target_id] = true
		StoryEffect.Kind.ACTIVATE_TASK:
			activate_task(effect.target_id)
		StoryEffect.Kind.SET_OWNER_STATE:
			owner_states[effect.target_id] = effect.text_value
		StoryEffect.Kind.UNLOCK_STORE:
			unlocked_store_ids[effect.target_id] = true
			if delta != null:
				delta.mark_store_state(effect.target_id, &"story_effect")
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


func _restore_store_slots(
	transaction: CardShopTransaction,
	raw_slots: Array,
	unlocked_page_count: int,
) -> bool:
	if raw_slots.is_empty():
		if not transaction.shelf_slots.is_empty():
			return false
		transaction.unlocked_page_count = 1
		return true
	if raw_slots.size() > CardShopTransaction.PAGE_SIZE * 3:
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


func _begin_change_batch() -> void:
	_change_batch_depth += 1


func _end_change_batch() -> void:
	assert(_change_batch_depth > 0, "QuestGameState change batch underflow")
	_change_batch_depth -= 1
	if _change_batch_depth > 0:
		return
	var delta := _pending_delta
	_pending_delta = null
	if delta != null and not delta.is_empty():
		state_delta.emit(delta)
	if _state_change_pending:
		_state_change_pending = false
		state_changed.emit()


func _mark_state_changed(delta: QuestStateDelta = null) -> void:
	# Persistent changes may alter story gates or protagonist Personas used by
	# synthesis, so invalidate its input cache conservatively. Transient draft
	# changes use _mark_transient_changed() and never request autosave.
	_synthesis_input_revision += 1
	_mark_delta(delta)
	if _change_batch_depth > 0:
		_state_change_pending = true
	else:
		state_changed.emit()


func _mark_transient_changed(
	delta: QuestStateDelta,
	invalidate_synthesis_inputs: bool = false,
) -> void:
	if invalidate_synthesis_inputs:
		_synthesis_input_revision += 1
	_mark_delta(delta)


func _mark_delta(delta: QuestStateDelta) -> void:
	if delta == null or delta.is_empty():
		return
	if _change_batch_depth > 0:
		if _pending_delta == null:
			_pending_delta = QuestStateDelta.new()
		_pending_delta.merge(delta)
	else:
		state_delta.emit(delta)


func _on_transaction_state_changed() -> void:
	_mark_state_changed()


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


func _clear_synthesis_assignment_for_card(card_instance_id: int) -> bool:
	if synthesis_base_instance_id == card_instance_id:
		synthesis_base_instance_id = 0
		_clear_synthesis_reinforcement()
		return true
	if synthesis_helper_instance_id == card_instance_id:
		synthesis_helper_instance_id = 0
		synthesis_candidate_recipe_id = &""
		return true
	return false


func _clear_synthesis_reinforcement() -> void:
	var helper := synthesis_helper_card()
	if helper != null:
		helper.return_to_hand()
	synthesis_helper_instance_id = 0
	synthesis_persona_id = &""
	synthesis_candidate_recipe_id = &""


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
