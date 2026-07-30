class_name SlotCommerceState
extends RefCounted

signal state_changed
signal synthesis_progressed(active_synthesis: ActiveSynthesisState)
signal synthesis_completed(result: Dictionary)

const DAILY_INCOME := 100
const DEMO_NIGHT_COUNT := 3
const BALLOON_OWNER := &"balloon"
const TEDDY_RECIPE := &"recipe_teddy"
const BALLOON_HUG_REQUEST := &"request_balloon_hug"
const RESULT_OK := &"ok"
const RESULT_DAILY_INCOMPLETE := &"daily_incomplete"
const RESULT_DAILY_RISK := &"daily_risk"
const RESULT_TRANSITION_ACTIVE := &"transition_active"
const RESULT_NO_TRANSITION := &"no_transition"
const RESULT_CONSUMPTION_PENDING := &"consumption_pending"
const RESULT_SYNTHESIS_ACTIVE := &"synthesis_active"
const RESULT_UNKNOWN_RECIPE := &"unknown_recipe"
const RESULT_RECIPE_NOT_READY := &"recipe_not_ready"
const RESULT_INPUTS_CHANGED := &"inputs_changed"
const RESULT_UNKNOWN_OWNER := &"unknown_owner"
const RESULT_UNKNOWN_REQUEST := &"unknown_request"
const RESULT_REQUEST_COMPLETED := &"request_completed"

const PREFERRED_DAILY_WISHES := {
	1: [&"wish_hungry", &"wish_bedside"],
	2: [&"wish_stay_awake", &"wish_remember"],
	3: [&"wish_settle_down", &"wish_rain_close"],
}

var day := 1
var wallet: PlayerWallet
var inventory: Array[CardItemState] = []
var store_transactions: Dictionary = {}
var owner_levels: Dictionary = {}
var owner_relationships: Dictionary = {}
var recycle_transaction: CardRecycleTransaction
var activity_state: SlotActivityState
var protagonist_aspect_counts: Dictionary = {}
var pending_transition: SlotNightTransition
var active_synthesis: ActiveSynthesisState
var first_crafted_output_ids: Dictionary = {}
var last_synthesis_result: Dictionary = {}
var last_owner_request_result: Dictionary = {}
var story_flags: Dictionary = {}
var random := RandomNumberGenerator.new()


func _init(shared_wallet: PlayerWallet = null, random_seed: int = 1999) -> void:
	reset(shared_wallet, random_seed)


func reset(shared_wallet: PlayerWallet = null, random_seed: int = 1999) -> void:
	day = 1
	wallet = shared_wallet if shared_wallet != null else PlayerWallet.new(120)
	inventory = []
	store_transactions = {}
	owner_levels = {}
	owner_relationships = {}
	for owner_id in SlotDemoCatalog.STORE_OWNER_IDS.values():
		var normalized_owner_id := StringName(owner_id)
		owner_relationships[normalized_owner_id] = OwnerRelationshipState.new(
			normalized_owner_id
		)
	random.seed = random_seed
	for store_id in SlotDemoCatalog.INITIAL_SHELF_ITEMS:
		var shelves := _make_initial_shelves(store_id)
		var transaction := CardShopTransaction.new(store_id, wallet, inventory, shelves)
		transaction.state_changed.connect(_on_child_state_changed)
		store_transactions[store_id] = transaction
	recycle_transaction = CardRecycleTransaction.new(inventory, wallet)
	recycle_transaction.state_changed.connect(_on_child_state_changed)
	activity_state = SlotActivityState.new(inventory)
	activity_state.state_changed.connect(_on_child_state_changed)
	protagonist_aspect_counts = {}
	for aspect in CardPropertySet.ASPECTS:
		protagonist_aspect_counts[aspect] = 0
	pending_transition = null
	active_synthesis = null
	first_crafted_output_ids = {}
	last_synthesis_result = {}
	last_owner_request_result = {}
	story_flags = {}
	select_daily_wishes_for_day(day)
	state_changed.emit()


func transaction_for_store(store_id: StringName) -> CardShopTransaction:
	return store_transactions.get(store_id) as CardShopTransaction


func checkout_store(store_id: StringName) -> Dictionary:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return {"ok": false, "reason": CardShopTransaction.RESULT_INVALID_ITEM}
	if (
		not activity_state.all_daily_wishes_confirmed()
		and transaction.cart_count() > 0
		and transaction.cart_total() <= wallet.money
	):
		var added_item_ids: Array[StringName] = []
		var excluded_shelf_keys: Dictionary = {}
		for slot_id in transaction.selected_shelf_slot_ids:
			var slot := transaction.shelf_slot(slot_id)
			if slot != null and not slot.is_empty():
				added_item_ids.append(slot.item_id)
				excluded_shelf_keys[DailyWishSolver.shelf_key(slot)] = true
		var viability := tonight_is_satisfiable(
			wallet.money - transaction.cart_total(),
			added_item_ids,
			excluded_shelf_keys,
		)
		if not viability.feasible:
			return {"ok": false, "reason": RESULT_DAILY_RISK}
	var result := transaction.checkout(day)
	if not result.ok:
		return result
	var relationship_update := _record_store_spend(store_id, int(result.total))
	result["owner_experience_gained"] = relationship_update.experience_gained
	result["owner_level_ups"] = relationship_update.level_ups
	result["owner_level_up_keys"] = relationship_update.level_up_keys
	state_changed.emit()
	return result


func stage_recycle_card(card: CardItemState) -> Dictionary:
	return recycle_transaction.stage(card)


func unstage_recycle_card(card: CardItemState) -> bool:
	return recycle_transaction.unstage(card)


func checkout_recycling() -> Dictionary:
	if not activity_state.all_daily_wishes_confirmed():
		var viability := tonight_is_satisfiable(
			wallet.money + recycle_transaction.cart_total()
		)
		if not viability.feasible:
			return {"ok": false, "reason": RESULT_DAILY_RISK}
	return recycle_transaction.checkout()


func card_by_instance_id(instance_id: int) -> CardItemState:
	for card in inventory:
		if card.instance_id == instance_id:
			return card
	return null


func reorder_hand_card(card: CardItemState, target_index: int) -> bool:
	if card == null or card.location != CardItemState.Location.HAND:
		return false
	var hand_cards: Array[CardItemState] = []
	for inventory_card in inventory:
		if inventory_card.location == CardItemState.Location.HAND:
			hand_cards.append(inventory_card)
	var current_index := hand_cards.find(card)
	if current_index < 0:
		return false
	hand_cards.remove_at(current_index)
	hand_cards.insert(clampi(target_index, 0, hand_cards.size()), card)
	var changed := hand_cards.find(card) != current_index
	if not changed:
		return true
	var hand_index := 0
	for inventory_index in range(inventory.size()):
		if inventory[inventory_index].location != CardItemState.Location.HAND:
			continue
		inventory[inventory_index] = hand_cards[hand_index]
		hand_index += 1
	state_changed.emit()
	return true


func relationship_state_for_owner(owner_id: StringName) -> OwnerRelationshipState:
	return owner_relationships.get(owner_id) as OwnerRelationshipState


func relationship_state_for_store(store_id: StringName) -> OwnerRelationshipState:
	return relationship_state_for_owner(SlotDemoCatalog.owner_id_for_store(store_id))


func talk_to_store_owner(store_id: StringName) -> Dictionary:
	var owner_id := SlotDemoCatalog.owner_id_for_store(store_id)
	var relationship := relationship_state_for_owner(owner_id)
	if owner_id.is_empty() or relationship == null:
		return {"ok": false, "reason": RESULT_UNKNOWN_OWNER}
	var definition := SlotDemoCatalog.owner_by_id(owner_id)
	var already_talked := relationship.has_talked_today(day)
	var update := relationship.record_daily_talk(day, definition)
	var level_up_keys := _apply_relationship_update(owner_id, update)
	var dialogue_key := &"slot.owner.placeholder.talk"
	if already_talked:
		dialogue_key = (
			definition.repeat_dialogue_key
			if definition != null else &"slot.owner.placeholder.repeat"
		)
	elif definition != null:
		dialogue_key = definition.dialogue_key_for_day(day)
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"owner_id": owner_id,
		"dialogue_key": dialogue_key,
		"experience_gained": update.experience_gained,
		"level_ups": update.level_ups,
		"level_up_keys": level_up_keys,
		"already_talked": already_talked,
	}


func is_request_completed(request_id: StringName) -> bool:
	var request := SlotDemoCatalog.request_by_id(request_id)
	var relationship := (
		relationship_state_for_owner(request.owner_id)
		if request != null else null
	)
	return relationship != null and relationship.completed_request_ids.has(request_id)


func submit_owner_request(request_id: StringName) -> Dictionary:
	if active_synthesis != null:
		return {"ok": false, "reason": RESULT_SYNTHESIS_ACTIVE}
	if pending_transition != null:
		return {"ok": false, "reason": RESULT_TRANSITION_ACTIVE}
	var request := SlotDemoCatalog.request_by_id(request_id)
	if request == null or request_id not in activity_state.active_request_ids:
		return {"ok": false, "reason": RESULT_UNKNOWN_REQUEST}
	if is_request_completed(request_id):
		return {"ok": false, "reason": RESULT_REQUEST_COMPLETED}
	var evaluation := activity_state.evaluation_for(request_id)
	if not evaluation.is_ready:
		return {"ok": false, "reason": RESULT_RECIPE_NOT_READY}
	if not activity_state.all_daily_wishes_confirmed():
		var viability := tonight_is_satisfiable()
		if not viability.feasible:
			return {"ok": false, "reason": RESULT_DAILY_RISK}
	var cards := activity_state.cards_for_activity(request_id)
	if cards.size() != 1:
		return {"ok": false, "reason": RESULT_INPUTS_CHANGED}
	var card := cards[0]
	var item_id := card.definition_id
	var result_text_key := request.result_text_key_for_item(item_id)
	if result_text_key.is_empty():
		return {"ok": false, "reason": RESULT_INPUTS_CHANGED}
	var relationship := relationship_state_for_owner(request.owner_id)
	var owner_definition := SlotDemoCatalog.owner_by_id(request.owner_id)
	if relationship == null or owner_definition == null:
		return {"ok": false, "reason": RESULT_UNKNOWN_OWNER}
	var consumed := activity_state.consume_activity_cards(request_id)
	activity_state.lock_activity(request_id)
	var reward := request.experience_for_item(item_id)
	var update := relationship.complete_request(request_id, reward, owner_definition)
	var level_up_keys := _apply_relationship_update(request.owner_id, update)
	var flag_value := request.story_flag_value_for_item(item_id)
	if not request.story_flag_key.is_empty() and not flag_value.is_empty():
		story_flags[request.story_flag_key] = flag_value
	last_owner_request_result = {
		"ok": true,
		"reason": RESULT_OK,
		"request_id": request_id,
		"owner_id": request.owner_id,
		"item_id": item_id,
		"result_text_key": result_text_key,
		"experience_gained": update.experience_gained,
		"level_ups": update.level_ups,
		"level_up_keys": level_up_keys,
		"consumed_count": consumed.size(),
		"story_flag_value": flag_value,
	}
	state_changed.emit()
	return last_owner_request_result


func begin_new_day(new_day: int) -> void:
	day = new_day
	for store_id in store_transactions:
		_refill_empty_slots(store_id)
	select_daily_wishes_for_day(day)
	state_changed.emit()


func tonight_is_satisfiable(
	wallet_amount: int = -1,
	added_item_ids: Array[StringName] = [],
	excluded_shelf_keys: Dictionary = {},
) -> Dictionary:
	return DailyWishSolver.evaluate(
		activity_state.active_daily_wish_ids,
		activity_state.confirmed_daily_wish_ids,
		inventory,
		store_transactions,
		ShopSchedule.open_store_ids(day),
		wallet.money if wallet_amount < 0 else wallet_amount,
		added_item_ids,
		excluded_shelf_keys,
	)


func select_daily_wishes_for_day(selected_day: int) -> Dictionary:
	var preferred: Array[StringName] = []
	for wish_id in PREFERRED_DAILY_WISHES.get(selected_day, []):
		preferred.append(StringName(wish_id))
	var open_stores := ShopSchedule.open_store_ids(selected_day)
	if preferred.size() == 2:
		var preferred_result := DailyWishSolver.evaluate(
			preferred,
			{},
			inventory,
			store_transactions,
			open_stores,
			wallet.money,
		)
		if preferred_result.feasible:
			activity_state.configure_daily_wishes(preferred)
			return {"ok": true, "wish_ids": preferred, "fallback": false}
	var all_wish_ids: Array[StringName] = []
	for wish in SlotDemoCatalog.wishes():
		all_wish_ids.append(wish.id)
	var feasible := DailyWishSolver.feasible_pairs(
		all_wish_ids,
		inventory,
		store_transactions,
		open_stores,
		wallet.money,
	)
	if feasible.is_empty():
		return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	var selected: Dictionary = feasible[random.randi_range(0, feasible.size() - 1)]
	var selected_ids: Array[StringName] = []
	for wish_id in selected.wish_ids:
		selected_ids.append(StringName(wish_id))
	activity_state.configure_daily_wishes(selected_ids)
	return {"ok": true, "wish_ids": selected_ids, "fallback": true}


func begin_night_transition() -> Dictionary:
	if pending_transition != null:
		return {"ok": false, "reason": RESULT_TRANSITION_ACTIVE}
	if active_synthesis != null:
		return {"ok": false, "reason": RESULT_SYNTHESIS_ACTIVE}
	var snapshot := activity_state.build_daily_transition_entries()
	if not snapshot.ok:
		return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	pending_transition = SlotNightTransition.new(day, snapshot.entries)
	state_changed.emit()
	return {"ok": true, "reason": RESULT_OK, "transition": pending_transition}


func begin_synthesis(recipe_id: StringName, duration_override: float = -1.0) -> Dictionary:
	if active_synthesis != null:
		return {"ok": false, "reason": RESULT_SYNTHESIS_ACTIVE}
	if pending_transition != null:
		return {"ok": false, "reason": RESULT_TRANSITION_ACTIVE}
	if recipe_id not in activity_state.known_recipe_ids:
		return {"ok": false, "reason": RESULT_UNKNOWN_RECIPE}
	var recipe := SlotDemoCatalog.recipe_by_id(recipe_id)
	var evaluation := activity_state.evaluation_for(recipe_id)
	if (
		recipe == null
		or not evaluation.is_ready
		or not evaluation.has("synthesis")
		or not evaluation.synthesis.is_complete
		or StringName(evaluation.synthesis.output_id).is_empty()
	):
		return {"ok": false, "reason": RESULT_RECIPE_NOT_READY}
	var output_id := StringName(evaluation.synthesis.output_id)
	if not activity_state.all_daily_wishes_confirmed():
		var viability := tonight_is_satisfiable(wallet.money, [output_id])
		if not viability.feasible:
			return {"ok": false, "reason": RESULT_DAILY_RISK}
	var input_ids: Array[int] = []
	for card in activity_state.cards_for_activity(recipe_id):
		input_ids.append(card.instance_id)
	if input_ids.size() != recipe.slot_rules.size():
		return {"ok": false, "reason": RESULT_RECIPE_NOT_READY}
	if not activity_state.lock_activity(recipe_id):
		return {"ok": false, "reason": RESULT_SYNTHESIS_ACTIVE}
	var duration := recipe.duration_seconds if duration_override < 0.0 else duration_override
	active_synthesis = ActiveSynthesisState.new(
		recipe_id,
		input_ids,
		output_id,
		StringName(evaluation.synthesis.preview_key),
		duration,
	)
	last_synthesis_result = {}
	state_changed.emit()
	return {"ok": true, "reason": RESULT_OK, "synthesis": active_synthesis}


func advance_synthesis(delta: float) -> Dictionary:
	if active_synthesis == null:
		return {"ok": false, "reason": RESULT_NO_TRANSITION}
	var finished := active_synthesis.advance(delta)
	synthesis_progressed.emit(active_synthesis)
	if not finished:
		return {
			"ok": true,
			"reason": RESULT_OK,
			"completed": false,
			"progress": active_synthesis.progress_ratio(),
		}
	return _complete_synthesis()


func _complete_synthesis() -> Dictionary:
	var synthesis := active_synthesis
	if synthesis == null:
		return {"ok": false, "reason": RESULT_NO_TRANSITION}
	var recipe := SlotDemoCatalog.recipe_by_id(synthesis.recipe_id)
	var expected_cards := activity_state.cards_for_activity(synthesis.recipe_id)
	if recipe == null or expected_cards.size() != synthesis.input_instance_ids.size():
		return _fail_synthesis(RESULT_INPUTS_CHANGED)
	for instance_id in synthesis.input_instance_ids:
		var card := card_by_instance_id(instance_id)
		if (
			card == null
			or card not in expected_cards
			or card.location != CardItemState.Location.ACTIVITY_SLOT
			or card.activity_id != synthesis.recipe_id
		):
			return _fail_synthesis(RESULT_INPUTS_CHANGED)
	var output_definition := SlotDemoCatalog.item_by_id(synthesis.output_id)
	if output_definition == null or not output_definition.is_crafted:
		return _fail_synthesis(RESULT_UNKNOWN_RECIPE)
	var consumed := activity_state.consume_activity_cards(synthesis.recipe_id)
	var output_card := CardItemState.new(
		_next_inventory_instance_id(),
		output_definition.id,
		day,
		synthesis.recipe_id,
	)
	inventory.append(output_card)
	var first_reward_applied := false
	if not first_crafted_output_ids.has(output_definition.id):
		first_crafted_output_ids[output_definition.id] = true
		var reward_aspect := recipe.first_reward_aspect_for_output(output_definition.id)
		if not reward_aspect.is_empty():
			protagonist_aspect_counts[reward_aspect] = int(
				protagonist_aspect_counts.get(reward_aspect, 0)
			) + 1
			first_reward_applied = true
	active_synthesis = null
	last_synthesis_result = {
		"ok": true,
		"reason": RESULT_OK,
		"completed": true,
		"recipe_id": synthesis.recipe_id,
		"output_id": output_definition.id,
		"output_card": output_card,
		"consumed_count": consumed.size(),
		"first_reward_applied": first_reward_applied,
	}
	state_changed.emit()
	synthesis_completed.emit(last_synthesis_result)
	return last_synthesis_result


func _fail_synthesis(reason: StringName) -> Dictionary:
	var recipe_id := active_synthesis.recipe_id if active_synthesis != null else &""
	active_synthesis = null
	activity_state.unlock_activity(recipe_id)
	last_synthesis_result = {"ok": false, "reason": reason, "completed": false}
	state_changed.emit()
	return last_synthesis_result


func _next_inventory_instance_id() -> int:
	var result := 1
	for card in inventory:
		result = maxi(result, card.instance_id + 1)
	return result


func apply_night_transition_consumption() -> Dictionary:
	if pending_transition == null:
		return {"ok": false, "reason": RESULT_NO_TRANSITION}
	if pending_transition.consumption_applied:
		return {"ok": true, "reason": RESULT_OK, "already_applied": true}
	for entry in pending_transition.entries:
		var card := card_by_instance_id(int(entry.card_instance_id))
		if card == null or card.definition_id != StringName(entry.item_id):
			return {"ok": false, "reason": RESULT_DAILY_INCOMPLETE}
	for entry in pending_transition.entries:
		for aspect in entry.aspects:
			protagonist_aspect_counts[aspect] = int(
				protagonist_aspect_counts.get(aspect, 0)
			) + 1
	var consumed := activity_state.consume_confirmed_daily_cards()
	pending_transition.consumption_applied = true
	state_changed.emit()
	return {
		"ok": true,
		"reason": RESULT_OK,
		"consumed_count": consumed.size(),
		"already_applied": false,
	}


func mark_night_transition_result_shown() -> bool:
	if (
		pending_transition == null
		or pending_transition.next_result_index >= pending_transition.entries.size()
	):
		return false
	pending_transition.next_result_index += 1
	state_changed.emit()
	return true


func finish_night_transition() -> Dictionary:
	if pending_transition == null:
		return {"ok": false, "reason": RESULT_NO_TRANSITION}
	if not pending_transition.consumption_applied:
		return {"ok": false, "reason": RESULT_CONSUMPTION_PENDING}
	day += 1
	wallet.money += DAILY_INCOME
	for store_id in store_transactions:
		_refill_empty_slots(store_id)
	var selection := select_daily_wishes_for_day(day)
	var finished_transition := pending_transition
	pending_transition = null
	state_changed.emit()
	return {
		"ok": selection.ok,
		"reason": RESULT_OK if selection.ok else selection.reason,
		"day": day,
		"income": DAILY_INCOME,
		"demo_complete": finished_transition.from_day >= DEMO_NIGHT_COUNT,
		"wish_ids": selection.get("wish_ids", []),
	}


func set_owner_level(owner_id: StringName, level: int) -> void:
	var relationship := relationship_state_for_owner(owner_id)
	var definition := SlotDemoCatalog.owner_by_id(owner_id)
	if relationship == null or definition == null or level <= relationship.level:
		return
	var previous := relationship.level
	var gained_levels := relationship.force_level(level, definition)
	_apply_owner_level_unlocks(owner_id, previous, relationship.level)
	owner_levels[owner_id] = relationship.level
	if not gained_levels.is_empty():
		state_changed.emit()


func _record_store_spend(store_id: StringName, paid_amount: int) -> Dictionary:
	var owner_id := SlotDemoCatalog.owner_id_for_store(store_id)
	var relationship := relationship_state_for_owner(owner_id)
	var definition := SlotDemoCatalog.owner_by_id(owner_id)
	if relationship == null:
		return _empty_relationship_update()
	var update := relationship.record_spend(paid_amount, definition)
	var level_up_keys := _apply_relationship_update(owner_id, update)
	return {
		"experience_gained": update.experience_gained,
		"level_ups": update.level_ups,
		"level_up_keys": level_up_keys,
	}


func _apply_relationship_update(owner_id: StringName, update: Dictionary) -> Array[StringName]:
	var relationship := relationship_state_for_owner(owner_id)
	var definition := SlotDemoCatalog.owner_by_id(owner_id)
	if relationship == null:
		return []
	var gained_levels: Array = update.get("level_ups", [])
	var previous_level := relationship.level - gained_levels.size()
	owner_levels[owner_id] = relationship.level
	_apply_owner_level_unlocks(owner_id, previous_level, relationship.level)
	var level_up_keys: Array[StringName] = []
	if definition != null:
		for raw_level in gained_levels:
			var key := definition.level_up_text_key(int(raw_level))
			if not key.is_empty():
				level_up_keys.append(key)
	return level_up_keys


func _apply_owner_level_unlocks(
	owner_id: StringName,
	previous_level: int,
	level: int,
) -> void:
	for definition in SlotDemoCatalog.retail_items():
		if (
			definition.unlock_owner_id == owner_id
			and previous_level < definition.unlock_level
			and level >= definition.unlock_level
		):
			_unlock_store_item(definition)
	if owner_id != BALLOON_OWNER:
		return
	if previous_level < 2 and level >= 2:
		if TEDDY_RECIPE not in activity_state.known_recipe_ids:
			activity_state.known_recipe_ids.append(TEDDY_RECIPE)
		if BALLOON_HUG_REQUEST not in activity_state.active_request_ids:
			activity_state.active_request_ids.append(BALLOON_HUG_REQUEST)
		activity_state.state_changed.emit()
	if previous_level < 3 and level >= 3:
		var definition := SlotDemoCatalog.owner_by_id(owner_id)
		var transaction := transaction_for_store(SlotDemoCatalog.STORE_TOY)
		if definition != null and transaction != null:
			transaction.set_discount_rate(definition.discount_rate)


func _empty_relationship_update() -> Dictionary:
	return {
		"experience_gained": 0,
		"level_ups": [],
		"level_up_keys": [],
	}


func _make_initial_shelves(store_id: StringName) -> Array[ShelfSlotState]:
	var shelves: Array[ShelfSlotState] = []
	var item_ids := SlotDemoCatalog.initial_shelf_item_ids(store_id)
	for index in range(item_ids.size()):
		shelves.append(ShelfSlotState.new(
			store_id,
			StringName("%s_shelf_%d" % [store_id, index + 1]),
			item_ids[index],
			1,
		))
	return shelves


func _unlock_store_item(definition: CardItemDefinition) -> void:
	var transaction := transaction_for_store(definition.store_id)
	if transaction == null:
		return
	if transaction.add_shelf_slot(definition.id, definition.shelf_page) == null:
		return
	transaction.unlock_page(definition.shelf_page)


func _refill_empty_slots(store_id: StringName) -> void:
	var transaction := transaction_for_store(store_id)
	if transaction == null:
		return
	for slot in transaction.shelf_slots:
		if slot.is_empty():
			var available := _available_restock_items(store_id, slot.page_index)
			var definition := _weighted_choice(available)
			if definition != null:
				slot.stock(definition.id)


func _available_restock_items(
	store_id: StringName,
	page_index: int,
) -> Array[CardItemDefinition]:
	var result: Array[CardItemDefinition] = []
	for definition in SlotDemoCatalog.retail_items_for_store(store_id):
		if definition.shelf_page != page_index:
			continue
		if (
			definition.unlock_owner_id.is_empty()
			or int(owner_levels.get(definition.unlock_owner_id, 0)) >= definition.unlock_level
		):
			result.append(definition)
	return result


func _weighted_choice(items: Array[CardItemDefinition]) -> CardItemDefinition:
	var total_weight := 0
	for item in items:
		total_weight += item.restock_weight
	if total_weight <= 0:
		return null
	var roll := random.randi_range(1, total_weight)
	for item in items:
		roll -= item.restock_weight
		if roll <= 0:
			return item
	return items.back() if not items.is_empty() else null


func _on_child_state_changed() -> void:
	state_changed.emit()
