class_name SlotSaveRepository
extends RefCounted

const SAVE_VERSION := 2
const CONTENT_VERSION := "slot-demo-0.9"
const DEFAULT_PATH := "user://save_slot_demo_v2.json"

var save_path: String


func _init(selected_path: String = DEFAULT_PATH) -> void:
	save_path = selected_path


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(_backup_path())


func save(commerce: SlotCommerceState) -> bool:
	if commerce == null:
		return false
	var file := FileAccess.open(_temporary_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(commerce), "\t"))
	file.flush()
	file.close()
	return _replace_with_temporary_file()


func load_into(commerce: SlotCommerceState) -> Dictionary:
	if commerce == null:
		return {"ok": false, "reason": &"missing_state"}
	var payload := _read_payload(save_path)
	if payload.is_empty():
		payload = _read_payload(_backup_path())
	if payload.is_empty():
		return {"ok": false, "reason": &"missing_or_invalid"}
	if int(payload.get("save_version", 0)) != SAVE_VERSION:
		return {"ok": false, "reason": &"unsupported_version"}
	var restored := _restore(commerce, payload)
	return {
		"ok": restored,
		"reason": &"ok" if restored else &"invalid_content",
	}


func erase() -> bool:
	var removed := false
	for path in [save_path, _temporary_path(), _backup_path()]:
		if FileAccess.file_exists(path):
			removed = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK \
				or removed
	return removed


func to_dictionary(commerce: SlotCommerceState) -> Dictionary:
	var inventory_data: Array[Dictionary] = []
	for card in commerce.inventory:
		inventory_data.append({
			"instance_id": card.instance_id,
			"definition_id": String(card.definition_id),
			"acquired_day": card.acquired_day,
			"acquisition_source": String(card.acquisition_source),
			"purchase_price": card.purchase_price,
			"location": card.location,
			"activity_id": String(card.activity_id),
			"slot_id": String(card.slot_id),
			"use_count": card.use_count,
		})
	var stores: Dictionary = {}
	for raw_store_id in commerce.store_transactions:
		var store_id := StringName(raw_store_id)
		var transaction := commerce.transaction_for_store(store_id)
		var shelves: Array[Dictionary] = []
		for slot in transaction.shelf_slots:
			shelves.append({
				"slot_id": String(slot.slot_id),
				"item_id": String(slot.item_id),
				"page_index": slot.page_index,
			})
		stores[String(store_id)] = {
			"unlocked_page_count": transaction.unlocked_page_count,
			"discount_rate": transaction.discount_rate,
			"selected_shelf_slot_ids": _string_array(transaction.selected_shelf_slot_ids),
			"shelves": shelves,
		}
	var relationships: Dictionary = {}
	for raw_owner_id in commerce.owner_relationships:
		var owner_id := StringName(raw_owner_id)
		var relationship := commerce.relationship_state_for_owner(owner_id)
		relationships[String(owner_id)] = {
			"experience": relationship.experience,
			"level": relationship.level,
			"lifetime_spend": relationship.lifetime_spend,
			"awarded_spend_experience": relationship.awarded_spend_experience,
			"last_talk_day": relationship.last_talk_day,
			"completed_request_ids": _dictionary_keys(relationship.completed_request_ids),
			"flags": _string_dictionary(relationship.flags),
		}
	return {
		"save_version": SAVE_VERSION,
		"content_version": CONTENT_VERSION,
		"day": commerce.day,
		"wallet": commerce.wallet.money,
		"random_state": commerce.random.state,
		"inventory": inventory_data,
		"stores": stores,
		"active_daily_wish_ids": _string_array(
			commerce.activity_state.active_daily_wish_ids
		),
		"confirmed_daily_wish_ids": _dictionary_keys(
			commerce.activity_state.confirmed_daily_wish_ids
		),
		"known_recipe_ids": _string_array(commerce.activity_state.known_recipe_ids),
		"active_request_ids": _string_array(commerce.activity_state.active_request_ids),
		"locked_activity_ids": _dictionary_keys(
			commerce.activity_state.locked_activity_ids
		),
		"assignments": _serialize_assignments(commerce.activity_state.assignments),
		"recycle_staged_instance_ids": commerce.recycle_transaction.staged_instance_ids,
		"protagonist_aspect_counts": _string_dictionary(
			commerce.protagonist_aspect_counts
		),
		"first_crafted_output_ids": _dictionary_keys(
			commerce.first_crafted_output_ids
		),
		"relationships": relationships,
		"story_flags": _string_dictionary(commerce.story_flags),
		"last_synthesis_result": _serialize_synthesis_result(
			commerce.last_synthesis_result
		),
		"last_owner_request_result": _serialize_request_result(
			commerce.last_owner_request_result
		),
		"pending_transition": _serialize_transition(commerce.pending_transition),
		"active_synthesis": _serialize_active_synthesis(commerce.active_synthesis),
	}


func _restore(commerce: SlotCommerceState, payload: Dictionary) -> bool:
	commerce.day = maxi(1, int(payload.get("day", 1)))
	commerce.wallet.money = maxi(0, int(payload.get("wallet", 120)))
	commerce.random.state = int(payload.get("random_state", commerce.random.state))
	commerce.inventory.clear()
	for raw_card in payload.get("inventory", []):
		var card_data := raw_card as Dictionary
		var definition_id := StringName(card_data.get("definition_id", ""))
		if SlotDemoCatalog.item_by_id(definition_id) == null:
			return false
		var card := CardItemState.new(
			int(card_data.get("instance_id", 0)),
			definition_id,
			int(card_data.get("acquired_day", 1)),
			StringName(card_data.get("acquisition_source", "shop")),
			int(card_data.get("purchase_price", 0)),
		)
		card.location = clampi(
			int(card_data.get("location", CardItemState.Location.HAND)),
			CardItemState.Location.HAND,
			CardItemState.Location.RECYCLE,
		) as CardItemState.Location
		card.activity_id = StringName(card_data.get("activity_id", ""))
		card.slot_id = StringName(card_data.get("slot_id", ""))
		card.use_count = maxi(0, int(card_data.get("use_count", 0)))
		commerce.inventory.append(card)
	_restore_stores(commerce, payload.get("stores", {}))
	_restore_activities(commerce, payload)
	_restore_relationships(commerce, payload.get("relationships", {}))
	commerce.recycle_transaction.staged_instance_ids = _int_array(
		payload.get("recycle_staged_instance_ids", [])
	)
	commerce.protagonist_aspect_counts = _name_int_dictionary(
		payload.get("protagonist_aspect_counts", {})
	)
	commerce.first_crafted_output_ids = _name_set(
		payload.get("first_crafted_output_ids", [])
	)
	commerce.story_flags = _name_dictionary(payload.get("story_flags", {}))
	commerce.last_synthesis_result = _restore_synthesis_result(
		payload.get("last_synthesis_result", {})
	)
	commerce.last_owner_request_result = _restore_request_result(
		payload.get("last_owner_request_result", {})
	)
	commerce.pending_transition = _restore_transition(payload.get("pending_transition", {}))
	commerce.active_synthesis = _restore_active_synthesis(
		payload.get("active_synthesis", {})
	)
	if commerce.active_synthesis != null:
		commerce.activity_state.locked_activity_ids[
			commerce.active_synthesis.recipe_id
		] = true
	commerce.state_changed.emit()
	return true


func _restore_stores(commerce: SlotCommerceState, raw_stores: Dictionary) -> void:
	for store_key in raw_stores:
		var store_id := StringName(store_key)
		var transaction := commerce.transaction_for_store(store_id)
		if transaction == null:
			continue
		var store_data := raw_stores[store_key] as Dictionary
		transaction.shelf_slots.clear()
		var shelf_index := 0
		for raw_shelf in store_data.get("shelves", []):
			var shelf_data := raw_shelf as Dictionary
			var fallback_page := floori(
				float(shelf_index) / CardShopTransaction.PAGE_SIZE
			) + 1
			transaction.shelf_slots.append(ShelfSlotState.new(
				store_id,
				StringName(shelf_data.get("slot_id", "")),
				StringName(shelf_data.get("item_id", "")),
				int(shelf_data.get("page_index", fallback_page)),
			))
			shelf_index += 1
		transaction.selected_shelf_slot_ids = _name_array(
			store_data.get("selected_shelf_slot_ids", [])
		)
		transaction.discount_rate = clampf(
			float(store_data.get("discount_rate", 0.0)), 0.0, 0.9
		)
		var legacy_capacity := int(store_data.get("capacity", 0))
		var legacy_page_count := ceili(float(maxi(
			transaction.shelf_slots.size(), legacy_capacity
		)) / CardShopTransaction.PAGE_SIZE)
		transaction.unlocked_page_count = clampi(
			int(store_data.get("unlocked_page_count", maxi(1, legacy_page_count))),
			1,
			CardShopTransaction.MAX_PAGE_COUNT,
		)


func _restore_activities(commerce: SlotCommerceState, payload: Dictionary) -> void:
	var activity := commerce.activity_state
	activity.active_daily_wish_ids = _name_array(
		payload.get("active_daily_wish_ids", [])
	)
	activity.known_recipe_ids = _name_array(payload.get("known_recipe_ids", []))
	activity.active_request_ids = _name_array(payload.get("active_request_ids", []))
	activity.confirmed_daily_wish_ids = _name_set(
		payload.get("confirmed_daily_wish_ids", [])
	)
	activity.locked_activity_ids = _name_set(payload.get("locked_activity_ids", []))
	activity.assignments = {}
	var raw_assignments := payload.get("assignments", {}) as Dictionary
	for activity_key in raw_assignments:
		var restored_slots: Dictionary = {}
		var raw_slots := raw_assignments[activity_key] as Dictionary
		for slot_key in raw_slots:
			restored_slots[StringName(slot_key)] = int(raw_slots[slot_key])
		activity.assignments[StringName(activity_key)] = restored_slots


func _restore_relationships(commerce: SlotCommerceState, raw_relationships: Dictionary) -> void:
	commerce.owner_levels.clear()
	for owner_key in raw_relationships:
		var owner_id := StringName(owner_key)
		var state := commerce.relationship_state_for_owner(owner_id)
		if state == null:
			continue
		var data := raw_relationships[owner_key] as Dictionary
		state.experience = maxi(0, int(data.get("experience", 0)))
		state.level = maxi(0, int(data.get("level", 0)))
		state.lifetime_spend = maxi(0, int(data.get("lifetime_spend", 0)))
		state.awarded_spend_experience = maxi(
			0, int(data.get("awarded_spend_experience", 0))
		)
		state.last_talk_day = maxi(0, int(data.get("last_talk_day", 0)))
		state.completed_request_ids = _name_set(data.get("completed_request_ids", []))
		state.flags = _name_dictionary(data.get("flags", {}))
		commerce.owner_levels[owner_id] = state.level
		var definition := SlotDemoCatalog.owner_by_id(owner_id)
		var transaction := commerce.transaction_for_store(definition.store_id) \
			if definition != null else null
		if definition != null and transaction != null and state.level >= definition.discount_level:
			transaction.discount_rate = definition.discount_rate


func _serialize_transition(transition: SlotNightTransition) -> Dictionary:
	if transition == null:
		return {}
	var entries: Array[Dictionary] = []
	for entry in transition.entries:
		entries.append({
			"wish_id": String(entry.wish_id),
			"card_instance_id": int(entry.card_instance_id),
			"item_id": String(entry.item_id),
			"result_key": String(entry.result_key),
			"aspects": _string_array(entry.aspects),
		})
	return {
		"from_day": transition.from_day,
		"entries": entries,
		"consumption_applied": transition.consumption_applied,
		"next_result_index": transition.next_result_index,
	}


func _restore_transition(data: Dictionary) -> SlotNightTransition:
	if data.is_empty():
		return null
	var entries: Array[Dictionary] = []
	for raw_entry in data.get("entries", []):
		var entry := raw_entry as Dictionary
		entries.append({
			"wish_id": StringName(entry.get("wish_id", "")),
			"card_instance_id": int(entry.get("card_instance_id", 0)),
			"item_id": StringName(entry.get("item_id", "")),
			"result_key": StringName(entry.get("result_key", "")),
			"aspects": _name_array(entry.get("aspects", [])),
		})
	var transition := SlotNightTransition.new(int(data.get("from_day", 1)), entries)
	transition.consumption_applied = bool(data.get("consumption_applied", false))
	transition.next_result_index = clampi(
		int(data.get("next_result_index", 0)), 0, transition.entries.size()
	)
	return transition


func _serialize_active_synthesis(active: ActiveSynthesisState) -> Dictionary:
	if active == null:
		return {}
	return {
		"recipe_id": String(active.recipe_id),
		"input_instance_ids": active.input_instance_ids,
		"output_id": String(active.output_id),
		"preview_key": String(active.preview_key),
		"duration_seconds": active.duration_seconds,
		"remaining_seconds": active.remaining_seconds,
	}


func _restore_active_synthesis(data: Dictionary) -> ActiveSynthesisState:
	if data.is_empty():
		return null
	var active := ActiveSynthesisState.new(
		StringName(data.get("recipe_id", "")),
		_int_array(data.get("input_instance_ids", [])),
		StringName(data.get("output_id", "")),
		StringName(data.get("preview_key", "")),
		float(data.get("duration_seconds", 0.0)),
	)
	active.remaining_seconds = clampf(
		float(data.get("remaining_seconds", active.duration_seconds)),
		0.0,
		active.duration_seconds,
	)
	return active


func _serialize_synthesis_result(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	return {
		"ok": bool(result.get("ok", false)),
		"completed": bool(result.get("completed", false)),
		"recipe_id": String(result.get("recipe_id", "")),
		"output_id": String(result.get("output_id", "")),
		"consumed_count": int(result.get("consumed_count", 0)),
		"first_reward_applied": bool(result.get("first_reward_applied", false)),
	}


func _restore_synthesis_result(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	return {
		"ok": bool(data.get("ok", false)),
		"completed": bool(data.get("completed", false)),
		"recipe_id": StringName(data.get("recipe_id", "")),
		"output_id": StringName(data.get("output_id", "")),
		"consumed_count": int(data.get("consumed_count", 0)),
		"first_reward_applied": bool(data.get("first_reward_applied", false)),
	}


func _serialize_request_result(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	return {
		"ok": bool(result.get("ok", false)),
		"request_id": String(result.get("request_id", "")),
		"owner_id": String(result.get("owner_id", "")),
		"item_id": String(result.get("item_id", "")),
		"result_text_key": String(result.get("result_text_key", "")),
		"experience_gained": int(result.get("experience_gained", 0)),
		"consumed_count": int(result.get("consumed_count", 0)),
		"story_flag_value": String(result.get("story_flag_value", "")),
	}


func _restore_request_result(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	return {
		"ok": bool(data.get("ok", false)),
		"request_id": StringName(data.get("request_id", "")),
		"owner_id": StringName(data.get("owner_id", "")),
		"item_id": StringName(data.get("item_id", "")),
		"result_text_key": StringName(data.get("result_text_key", "")),
		"experience_gained": int(data.get("experience_gained", 0)),
		"consumed_count": int(data.get("consumed_count", 0)),
		"story_flag_value": StringName(data.get("story_flag_value", "")),
	}


func _serialize_assignments(assignments: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for activity_id in assignments:
		var slots: Dictionary = {}
		for slot_id in assignments[activity_id]:
			slots[String(slot_id)] = int(assignments[activity_id][slot_id])
		result[String(activity_id)] = slots
	return result


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


func _name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result


func _dictionary_keys(values: Dictionary) -> Array[String]:
	return _string_array(values.keys())


func _string_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[String(key)] = values[key]
	return result


func _name_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[StringName(key)] = StringName(values[key])
	return result


func _name_int_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[StringName(key)] = int(values[key])
	return result


func _name_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[StringName(value)] = true
	return result


func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _replace_with_temporary_file() -> bool:
	var target := ProjectSettings.globalize_path(save_path)
	var temporary := ProjectSettings.globalize_path(_temporary_path())
	var backup := ProjectSettings.globalize_path(_backup_path())
	if FileAccess.file_exists(_backup_path()):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(target, backup) != OK:
			return false
	var rename_error := DirAccess.rename_absolute(temporary, target)
	if rename_error != OK:
		if FileAccess.file_exists(_backup_path()):
			DirAccess.rename_absolute(backup, target)
		return false
	if FileAccess.file_exists(_backup_path()):
		DirAccess.remove_absolute(backup)
	return true


func _temporary_path() -> String:
	return "%s.tmp" % save_path


func _backup_path() -> String:
	return "%s.bak" % save_path
