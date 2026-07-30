class_name DailyWishSolver
extends RefCounted

static var _cached_definitions_by_id: Dictionary = {}
static var _cached_wishes_by_id: Dictionary = {}


static func evaluate(
	wish_ids: Array[StringName],
	confirmed_wish_ids: Dictionary,
	inventory: Array[CardItemState],
	store_transactions: Dictionary,
	open_store_ids: Array[StringName],
	wallet_amount: int,
	added_item_ids: Array[StringName] = [],
	excluded_shelf_keys: Dictionary = {},
) -> Dictionary:
	var unresolved: Array[StringName] = []
	for wish_id in wish_ids:
		if not confirmed_wish_ids.has(wish_id):
			unresolved.append(wish_id)
	if unresolved.is_empty():
		return _result(true, 0, [])

	var definitions_by_id := _item_definitions()
	var wishes_by_id := _wish_definitions()
	var options_by_wish: Dictionary = {}
	for wish_id in unresolved:
		options_by_wish[wish_id] = []
	for card in inventory:
		if not _card_is_available(card, wish_ids, confirmed_wish_ids):
			continue
		_add_candidate(
			options_by_wish,
			unresolved,
			wishes_by_id,
			definitions_by_id.get(card.definition_id) as CardItemDefinition,
			"card:%d" % card.instance_id,
			0,
		)
	for index in range(added_item_ids.size()):
		_add_candidate(
			options_by_wish,
			unresolved,
			wishes_by_id,
			definitions_by_id.get(added_item_ids[index]) as CardItemDefinition,
			"added:%d" % index,
			0,
		)
	for store_id in open_store_ids:
		var transaction := store_transactions.get(store_id) as CardShopTransaction
		if transaction == null:
			continue
		for slot in transaction.shelf_slots:
			if slot.is_empty() or excluded_shelf_keys.has(_shelf_key(slot)):
				continue
			var definition := definitions_by_id.get(slot.item_id) as CardItemDefinition
			_add_candidate(
				options_by_wish,
				unresolved,
				wishes_by_id,
				definition,
				"shelf:%s" % _shelf_key(slot),
				transaction.price_for(definition),
			)

	var best := {"cost": 1_000_000, "choices": []}
	_search_assignments(
		unresolved,
		options_by_wish,
		0,
		{},
		0,
		wallet_amount,
		[],
		best,
	)
	return _result(best.cost <= wallet_amount, best.cost, best.choices)


static func feasible_pairs(
	wish_ids: Array[StringName],
	inventory: Array[CardItemState],
	store_transactions: Dictionary,
	open_store_ids: Array[StringName],
	wallet_amount: int,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for first_index in range(wish_ids.size()):
		for second_index in range(first_index + 1, wish_ids.size()):
			var pair: Array[StringName] = [wish_ids[first_index], wish_ids[second_index]]
			var evaluation := evaluate(
				pair,
				{},
				inventory,
				store_transactions,
				open_store_ids,
				wallet_amount,
			)
			if evaluation.feasible:
				result.append({
					"wish_ids": pair,
					"minimum_cost": evaluation.minimum_cost,
					"choices": evaluation.choices,
				})
	return result


static func shelf_key(slot: ShelfSlotState) -> String:
	return _shelf_key(slot)


static func _item_definitions() -> Dictionary:
	if _cached_definitions_by_id.is_empty():
		for definition in SlotDemoCatalog.all_items():
			_cached_definitions_by_id[definition.id] = definition
	return _cached_definitions_by_id


static func _wish_definitions() -> Dictionary:
	if _cached_wishes_by_id.is_empty():
		for wish in SlotDemoCatalog.wishes():
			_cached_wishes_by_id[wish.id] = wish
	return _cached_wishes_by_id


static func _card_is_available(
	card: CardItemState,
	wish_ids: Array[StringName],
	confirmed_wish_ids: Dictionary,
) -> bool:
	if card.location == CardItemState.Location.HAND:
		return true
	return (
		card.location == CardItemState.Location.ACTIVITY_SLOT
		and card.activity_id in wish_ids
		and not confirmed_wish_ids.has(card.activity_id)
	)


static func _add_candidate(
	options_by_wish: Dictionary,
	wish_ids: Array[StringName],
	wishes_by_id: Dictionary,
	definition: CardItemDefinition,
	source_key: String,
	cost: int,
) -> void:
	if definition == null:
		return
	for wish_id in wish_ids:
		var wish := wishes_by_id.get(wish_id) as DailyWishDefinition
		if wish == null:
			continue
		if CardRuleEvaluator.evaluate(wish.slot_rule, definition).can_execute:
			(options_by_wish[wish_id] as Array).append({
				"wish_id": wish_id,
				"item_id": definition.id,
				"source_key": source_key,
				"cost": cost,
			})


static func _search_assignments(
	wish_ids: Array[StringName],
	options_by_wish: Dictionary,
	index: int,
	used_sources: Dictionary,
	cost: int,
	wallet_amount: int,
	choices: Array[Dictionary],
	best: Dictionary,
) -> void:
	if cost > wallet_amount or cost >= int(best.cost):
		return
	if index >= wish_ids.size():
		best.cost = cost
		best.choices = choices.duplicate(true)
		return
	var wish_id := wish_ids[index]
	for raw_option in options_by_wish.get(wish_id, []):
		var option := raw_option as Dictionary
		var source_key := String(option.source_key)
		if used_sources.has(source_key):
			continue
		used_sources[source_key] = true
		choices.append(option)
		_search_assignments(
			wish_ids,
			options_by_wish,
			index + 1,
			used_sources,
			cost + int(option.cost),
			wallet_amount,
			choices,
			best,
		)
		choices.pop_back()
		used_sources.erase(source_key)


static func _shelf_key(slot: ShelfSlotState) -> String:
	return "%s:%s" % [slot.store_id, slot.slot_id]


static func _result(feasible: bool, minimum_cost: int, choices: Array) -> Dictionary:
	return {
		"feasible": feasible,
		"minimum_cost": minimum_cost if feasible else -1,
		"choices": choices if feasible else [],
	}
