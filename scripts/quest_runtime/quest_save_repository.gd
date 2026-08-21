class_name QuestSaveRepository
extends RefCounted

const SAVE_VERSION := 16
const CONTENT_VERSION := "store-unlock-chain-1"
const DEFAULT_PATH := "user://save_shopping0807_v1.json"

var save_path: String


func _init(selected_path: String = DEFAULT_PATH) -> void:
	save_path = selected_path


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(_backup_path())


func save(state: QuestGameState) -> bool:
	if state == null:
		return false
	var file := FileAccess.open(_temporary_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary(state), "\t"))
	file.flush()
	file.close()
	return _replace_with_temporary_file()


func load_into(state: QuestGameState) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": &"missing_state"}
	var payload := _read_payload(save_path)
	if payload.is_empty():
		payload = _read_payload(_backup_path())
	if payload.is_empty():
		return {"ok": false, "reason": &"missing_or_invalid"}
	if int(payload.get("save_version", 0)) != SAVE_VERSION:
		return {"ok": false, "reason": &"unsupported_version"}
	if String(payload.get("content_version", "")) != CONTENT_VERSION:
		return {"ok": false, "reason": &"unsupported_content"}
	var restored := _restore(state, payload)
	return {"ok": restored, "reason": &"ok" if restored else &"invalid_content"}


func erase() -> bool:
	var removed := false
	for path in [save_path, _temporary_path(), _backup_path()]:
		if FileAccess.file_exists(path):
			removed = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK or removed
	return removed


func to_dictionary(state: QuestGameState) -> Dictionary:
	var cards: Array[Dictionary] = []
	for card in state.inventory:
		var is_temporary_synthesis_card := (
			card.location == CardItemState.Location.ACTIVITY_SLOT
			and card.activity_id == &"synthesis"
		)
		cards.append({
			"instance_id": card.instance_id,
			"definition_id": String(card.definition_id),
			"acquired_day": card.acquired_day,
			"acquisition_source": String(card.acquisition_source),
			"purchase_price": card.purchase_price,
			"location": (
				CardItemState.Location.HAND if is_temporary_synthesis_card else card.location
			),
			"activity_id": "" if is_temporary_synthesis_card else String(card.activity_id),
			"slot_id": "" if is_temporary_synthesis_card else String(card.slot_id),
			"use_count": card.use_count,
		})
	var tasks: Array[Dictionary] = []
	for instance in state.task_instances:
		tasks.append({
			"instance_id": instance.instance_id,
			"definition_id": String(instance.definition_id),
			"activation_day": instance.activation_day,
			"assignments": _string_int_dictionary(instance.assignments),
			"confirmed": instance.confirmed,
			"resolved_outcome_id": String(instance.resolved_outcome_id),
			"settled": instance.settled,
			"gift_revealed": instance.gift_revealed,
			"gift_claimed": instance.gift_claimed,
		})
	return {
		"save_version": SAVE_VERSION,
		"content_version": CONTENT_VERSION,
		"day": state.day,
		"wallet": state.wallet.money,
		"next_card_instance_id": state.next_card_instance_id,
		"next_task_instance_id": state.next_task_instance_id,
		"inventory": cards,
		"task_instances": tasks,
		"task_history": _string_dictionary(state.task_history),
		"story_flags": _string_dictionary(state.story_flags),
		"protagonist_shape_levels": _string_int_dictionary(state.protagonist_shape_levels),
		"unlocked_store_ids": _string_array(state.unlocked_store_ids.keys()),
		"store_unlock_days": _string_int_dictionary(state.store_unlock_days),
		"store_purchase_counts": _string_int_dictionary(state.store_purchase_counts),
		"purchased_item_ids": _string_array(state.purchased_item_ids.keys()),
		"available_owner_request_ids": _string_array(
			state.available_owner_request_ids.keys()
		),
		"unlocked_store_item_ids": _string_array(state.unlocked_store_item_ids.keys()),
		"discovered_recipe_ids": _string_array(state.discovered_recipe_ids.keys()),
		"synthesis_recipe_use_counts": _string_int_dictionary(
			state.synthesis_recipe_use_counts
		),
		"owner_states": _string_dictionary(state.owner_states),
		"pending_persona_reveal_shape_ids": _string_array(state.pending_persona_reveal_shape_ids),
		"visited_store_ids": _string_array(state.visited_store_ids.keys()),
		"bgm_playback_positions": _string_float_dictionary(state.bgm_playback_positions),
		"pending_arc": _serialize_arc(state.pending_arc),
		"expedition": _serialize_expedition(state.expedition),
		"commerce": state.commerce_snapshot(),
	}


func _restore(state: QuestGameState, payload: Dictionary) -> bool:
	state.day = maxi(1, int(payload.get("day", 1)))
	state.wallet.money = maxi(0, int(payload.get("wallet", 0)))
	state.inventory.clear()
	for raw_card in payload.get("inventory", []):
		var data := raw_card as Dictionary
		var definition_id := StringName(data.get("definition_id", ""))
		if QuestArcCatalog.item_by_id(definition_id) == null:
			return false
		var card := CardItemState.new(
			int(data.get("instance_id", 0)),
			definition_id,
			int(data.get("acquired_day", 1)),
			StringName(data.get("acquisition_source", "shop")),
			int(data.get("purchase_price", 0)),
		)
		card.location = clampi(
			int(data.get("location", CardItemState.Location.HAND)),
			CardItemState.Location.HAND,
			CardItemState.Location.RECYCLE,
		) as CardItemState.Location
		card.activity_id = StringName(data.get("activity_id", ""))
		card.slot_id = StringName(data.get("slot_id", ""))
		card.use_count = maxi(0, int(data.get("use_count", 0)))
		state.inventory.append(card)
	state.task_instances.clear()
	for raw_task in payload.get("task_instances", []):
		var data := raw_task as Dictionary
		var definition_id := StringName(data.get("definition_id", ""))
		if QuestArcCatalog.task_by_id(definition_id) == null:
			return false
		var instance := TaskInstanceState.new(
			int(data.get("instance_id", 0)),
			definition_id,
			int(data.get("activation_day", 1)),
		)
		instance.assignments = _name_int_dictionary(data.get("assignments", {}))
		instance.confirmed = bool(data.get("confirmed", false))
		instance.resolved_outcome_id = StringName(data.get("resolved_outcome_id", ""))
		instance.settled = bool(data.get("settled", false))
		instance.gift_revealed = bool(data.get("gift_revealed", false))
		instance.gift_claimed = bool(data.get("gift_claimed", false))
		state.task_instances.append(instance)
	state.task_history = _name_dictionary(payload.get("task_history", {}))
	state.story_flags = _name_dictionary(payload.get("story_flags", {}))
	state.protagonist_shape_levels = _name_int_dictionary(
		payload.get("protagonist_shape_levels", {})
	)
	for stat_id in CardPropertySet.SHAPES:
		if not state.protagonist_shape_levels.has(stat_id):
			state.protagonist_shape_levels[stat_id] = 0
	state.unlocked_store_ids = _name_set(payload.get("unlocked_store_ids", []))
	state.store_unlock_days = _name_int_dictionary(payload.get("store_unlock_days", {}))
	state.store_purchase_counts = _name_int_dictionary(
		payload.get("store_purchase_counts", {})
	)
	state.purchased_item_ids = _name_set(payload.get("purchased_item_ids", []))
	state.available_owner_request_ids = _name_set(
		payload.get("available_owner_request_ids", [])
	)
	state.unlocked_store_item_ids = _name_set(
		payload.get("unlocked_store_item_ids", [])
	)
	state.discovered_recipe_ids = _name_set(payload.get("discovered_recipe_ids", []))
	state.synthesis_recipe_use_counts = _name_int_dictionary(
		payload.get("synthesis_recipe_use_counts", {})
	)
	for raw_recipe_id in state.synthesis_recipe_use_counts:
		var recipe := QuestArcCatalog.recipe_by_id(StringName(raw_recipe_id))
		if (
			recipe == null
			or not recipe.escalating_shape_requirement
			or int(state.synthesis_recipe_use_counts[raw_recipe_id]) < 0
		):
			return false
	state.owner_states = _name_dictionary(payload.get("owner_states", {}))
	state.pending_persona_reveal_shape_ids = _name_array(
		payload.get("pending_persona_reveal_shape_ids", [])
	)
	state.visited_store_ids = _name_set(payload.get("visited_store_ids", []))
	state.bgm_playback_positions = _name_float_dictionary(
		payload.get("bgm_playback_positions", {})
	)
	state.pending_arc = _restore_arc(payload.get("pending_arc", {}))
	state.expedition = _restore_expedition(payload.get("expedition", {}))
	if state.expedition == null:
		return false
	# Synthesis placement is a screen-local draft and never survives loading.
	state.synthesis_base_instance_id = 0
	state.synthesis_helper_instance_id = 0
	state.synthesis_persona_shape_id = &""
	state.synthesis_candidate_recipe_id = &""
	for card in state.inventory:
		if card.activity_id == &"synthesis":
			card.return_to_hand()
	state.next_card_instance_id = maxi(
		int(payload.get("next_card_instance_id", 1)),
		_next_card_id(state.inventory),
	)
	state.next_task_instance_id = maxi(
		int(payload.get("next_task_instance_id", 1)),
		_next_task_id(state.task_instances),
	)
	if not state.restore_commerce_snapshot(payload.get("commerce", {})):
		return false
	if not _assignments_are_valid(state):
		return false
	state.state_changed.emit()
	return true


func _assignments_are_valid(state: QuestGameState) -> bool:
	var assigned_card_ids: Dictionary = {}
	for instance in state.task_instances:
		var definition := QuestArcCatalog.task_by_id(instance.definition_id)
		if definition == null:
			return false
		for raw_slot_id in instance.assignments:
			var slot_id := StringName(raw_slot_id)
			var card_id := int(instance.assignments[raw_slot_id])
			if assigned_card_ids.has(card_id) or state.card_by_instance_id(card_id) == null:
				return false
			if not definition.slot_rules.any(func(raw_rule: Resource) -> bool:
				return (raw_rule as CardSlotRule).id == slot_id
			):
				return false
			assigned_card_ids[card_id] = true
	return true


func _serialize_arc(arc: ArcTransitionState) -> Dictionary:
	if arc == null:
		return {}
	var entries: Array[Dictionary] = []
	for entry in arc.entries:
		entries.append({
			"entry_kind": String(entry.get("entry_kind", "settlement")),
			"task_instance_id": int(entry.get("task_instance_id", 0)),
			"task_definition_id": String(entry.get("task_definition_id", "")),
			"outcome_id": String(entry.get("outcome_id", "")),
			"result_text_key": String(entry.get("result_text_key", "")),
			"card_instance_ids": _int_array(entry.get("card_instance_ids", [])),
			"item_definition_ids": _string_array(entry.get("item_definition_ids", [])),
			"reward_money": int(entry.get("reward_money", 0)),
			"reward_stats": _string_int_dictionary(entry.get("reward_stats", {})),
			"reward_item_ids": _string_array(entry.get("reward_item_ids", [])),
			"owner_id": String(entry.get("owner_id", "")),
			"store_id": String(entry.get("store_id", "")),
		})
	return {
		"from_day": arc.from_day,
		"entries": entries,
		"effects_applied": arc.effects_applied,
		"applied_entry_count": arc.applied_entry_count,
		"next_entry_index": arc.next_entry_index,
	}


func _restore_arc(data: Dictionary) -> ArcTransitionState:
	if data.is_empty():
		return null
	var entries: Array[Dictionary] = []
	for raw_entry in data.get("entries", []):
		var entry := raw_entry as Dictionary
		entries.append({
			"entry_kind": StringName(entry.get("entry_kind", "settlement")),
			"task_instance_id": int(entry.get("task_instance_id", 0)),
			"task_definition_id": StringName(entry.get("task_definition_id", "")),
			"outcome_id": StringName(entry.get("outcome_id", "")),
			"result_text_key": StringName(entry.get("result_text_key", "")),
			"card_instance_ids": _int_array(entry.get("card_instance_ids", [])),
			"item_definition_ids": _name_array(entry.get("item_definition_ids", [])),
			"reward_money": int(entry.get("reward_money", 0)),
			"reward_stats": _name_int_dictionary(entry.get("reward_stats", {})),
			"reward_item_ids": _name_array(entry.get("reward_item_ids", [])),
			"owner_id": StringName(entry.get("owner_id", "")),
			"store_id": StringName(entry.get("store_id", "")),
		})
	var arc := ArcTransitionState.new(int(data.get("from_day", 1)), entries)
	arc.effects_applied = bool(data.get("effects_applied", false))
	arc.applied_entry_count = clampi(
		int(data.get("applied_entry_count", 0)), 0, arc.entries.size()
	)
	arc.next_entry_index = clampi(
		int(data.get("next_entry_index", 0)), 0, arc.applied_entry_count
	)
	arc.effects_applied = arc.applied_entry_count >= arc.entries.size()
	return arc


func _serialize_expedition(expedition: MallExpeditionState) -> Dictionary:
	if expedition == null:
		return {}
	return {
		"active": expedition.active,
		"from_day": expedition.from_day,
		"rooms_completed": expedition.rooms_completed,
		"entered_room_ids": _string_array(expedition.entered_room_ids.keys()),
		"economy_offer_seen": expedition.economy_offer_seen,
		"current_door_ids": _string_array(expedition.current_door_ids),
		"rng_seed": expedition.rng_seed,
		# RandomNumberGenerator state is a 64-bit value and cannot safely round-trip
		# through JSON's floating-point number representation.
		"rng_state": str(expedition.rng_state),
		"checkpoint_serial": expedition.checkpoint_serial,
		"disease_game_over_id": String(expedition.disease_game_over_id),
		"discovered_room_ids": _string_array(expedition.discovered_room_ids.keys()),
		"first_cleared_challenge_ids": _string_array(
			expedition.first_cleared_challenge_ids.keys()
		),
		"boss_cleared": expedition.boss_cleared,
	}


func _restore_expedition(data: Dictionary) -> MallExpeditionState:
	var expedition := MallExpeditionState.new()
	if data.is_empty():
		return expedition
	expedition.active = bool(data.get("active", false))
	expedition.from_day = maxi(1, int(data.get("from_day", 1)))
	expedition.rooms_completed = clampi(
		int(data.get("rooms_completed", 0)), 0, MallExpeditionState.ROOMS_PER_NIGHT
	)
	expedition.entered_room_ids = _name_set(data.get("entered_room_ids", []))
	expedition.economy_offer_seen = bool(data.get("economy_offer_seen", false))
	expedition.current_door_ids = _name_array(data.get("current_door_ids", []))
	expedition.rng_seed = maxi(1, int(data.get("rng_seed", 1)))
	expedition.rng_state = int(String(data.get("rng_state", "0")))
	expedition.checkpoint_serial = maxi(0, int(data.get("checkpoint_serial", 0)))
	expedition.disease_game_over_id = StringName(data.get("disease_game_over_id", ""))
	expedition.discovered_room_ids = _name_set(data.get("discovered_room_ids", []))
	expedition.first_cleared_challenge_ids = _name_set(
		data.get("first_cleared_challenge_ids", [])
	)
	expedition.boss_cleared = bool(data.get("boss_cleared", false))
	for room_id in (
		expedition.current_door_ids
		+ _name_array(expedition.entered_room_ids.keys())
		+ _name_array(expedition.discovered_room_ids.keys())
		+ _name_array(expedition.first_cleared_challenge_ids.keys())
	):
		if QuestArcCatalog.mall_room_by_id(room_id) == null:
			return null
	if (
		expedition.active
		and expedition.current_door_ids.is_empty()
		and expedition.disease_game_over_id.is_empty()
	):
		return null
	if (
		not expedition.disease_game_over_id.is_empty()
		and expedition.disease_game_over_id not in [
			QuestGameState.EXPEDITION_WHITE_FLOWER_ITEM_ID,
			QuestGameState.EXPEDITION_FAILURE_ITEM_ID,
		]
	):
		return null
	if (
		not expedition.disease_game_over_id.is_empty()
		and (not expedition.active or not expedition.current_door_ids.is_empty())
	):
		return null
	return expedition


func _next_card_id(cards: Array[CardItemState]) -> int:
	var result := 1
	for card in cards:
		result = maxi(result, card.instance_id + 1)
	return result


func _next_task_id(tasks: Array[TaskInstanceState]) -> int:
	var result := 1
	for instance in tasks:
		result = maxi(result, instance.instance_id + 1)
	return result


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result


func _name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result


func _string_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[String(key)] = String(values[key])
	return result


func _string_int_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[String(key)] = int(values[key])
	return result


func _string_float_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[String(key)] = maxf(0.0, float(values[key]))
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


func _name_float_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		result[StringName(key)] = maxf(0.0, float(values[key]))
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
