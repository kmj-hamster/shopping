class_name MallDoorGenerator
extends RefCounted

const BOSS_ROOM_ID := &"scanner"
const BOSS_SELECTION_INDEX := 1
const BOSS_CLEAR_TARGET := 3
const ECONOMY_OFFER_CHANCE := 0.50
const CHALLENGE_CHANCE := 0.60


static func generate(
	run: MallExpeditionState,
	rooms: Array[Resource],
	rng: RandomNumberGenerator,
) -> Array[StringName]:
	if run == null or rng == null:
		return []
	var boss := _room_by_id(rooms, BOSS_ROOM_ID)
	var boss_probability := boss_chance(run.first_clear_count())
	if (
		boss != null
		and not run.boss_cleared
		and run.rooms_completed == BOSS_SELECTION_INDEX
		and boss_probability > 0.0
		and rng.randf() < boss_probability
	):
		return [boss.id]

	var result: Array[StringName] = [&"", &""]
	if not run.economy_offer_seen and rng.randf() < ECONOMY_OFFER_CHANCE:
		var economy_candidates := _eligible_economy_rooms(rooms, run, result)
		var economy_room := _weighted_pick(economy_candidates, rng)
		if economy_room != null:
			run.economy_offer_seen = true
			result[rng.randi_range(0, 1)] = economy_room.id

	for index in result.size():
		if not result[index].is_empty():
			continue
		var preferred_category := (
			MallRoomDefinition.Category.CHALLENGE
			if rng.randf() < CHALLENGE_CHANCE
			else MallRoomDefinition.Category.REST
		)
		var candidates := _eligible_rooms(rooms, preferred_category, run, result)
		if candidates.is_empty():
			var fallback_category := (
				MallRoomDefinition.Category.REST
				if preferred_category == MallRoomDefinition.Category.CHALLENGE
				else MallRoomDefinition.Category.CHALLENGE
			)
			candidates = _eligible_rooms(rooms, fallback_category, run, result)
		var picked := _weighted_pick(
			candidates,
			rng,
		)
		if picked != null:
			result[index] = picked.id
	return result.filter(func(room_id: StringName) -> bool: return not room_id.is_empty())


static func boss_chance(first_clear_count: int) -> float:
	return clampf(float(first_clear_count) / float(BOSS_CLEAR_TARGET), 0.0, 1.0)


static func _eligible_rooms(
	rooms: Array[Resource],
	category: MallRoomDefinition.Category,
	run: MallExpeditionState,
	selected_ids: Array[StringName],
) -> Array[MallRoomDefinition]:
	var result: Array[MallRoomDefinition] = []
	for raw_room in rooms:
		var room := raw_room as MallRoomDefinition
		if (
			room != null
			and room.category == category
			and room.generation_pool == MallRoomDefinition.GenerationPool.DEFAULT
			and not run.has_entered(room.id)
			and room.id not in selected_ids
			and not (
				category == MallRoomDefinition.Category.CHALLENGE
				and run.is_first_cleared(room.id)
			)
		):
			result.append(room)
	return result


static func _eligible_economy_rooms(
	rooms: Array[Resource],
	run: MallExpeditionState,
	selected_ids: Array[StringName],
) -> Array[MallRoomDefinition]:
	var result: Array[MallRoomDefinition] = []
	for raw_room in rooms:
		var room := raw_room as MallRoomDefinition
		if (
			room != null
			and room.generation_pool == MallRoomDefinition.GenerationPool.ECONOMY
			and not run.has_entered(room.id)
			and room.id not in selected_ids
		):
			result.append(room)
	return result


static func _weighted_pick(
	candidates: Array[MallRoomDefinition],
	rng: RandomNumberGenerator,
) -> MallRoomDefinition:
	if candidates.is_empty():
		return null
	var total_weight := 0
	var weights: Array[int] = []
	for room in candidates:
		var weight := room.generation_weight
		weights.append(maxi(1, weight))
		total_weight += weights[-1]
	var roll := rng.randi_range(1, total_weight)
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0:
			return candidates[index]
	return candidates[-1]


static func _room_by_id(
	rooms: Array[Resource],
	room_id: StringName,
) -> MallRoomDefinition:
	for raw_room in rooms:
		var room := raw_room as MallRoomDefinition
		if room != null and room.id == room_id:
			return room
	return null
