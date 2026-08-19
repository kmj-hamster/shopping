class_name MallDoorGenerator
extends RefCounted

const BOSS_ROOM_ID := &"scanner"
const BOSS_CHANCE_PER_CLEAR := 0.20
const WORK_OFFER_CHANCE := 0.50
const CHALLENGE_CHANCE := 0.60


static func generate(
	run: MallExpeditionState,
	rooms: Array[Resource],
	rng: RandomNumberGenerator,
) -> Array[StringName]:
	if run == null or rng == null:
		return []
	var boss := _room_by_id(rooms, BOSS_ROOM_ID)
	if (
		boss != null
		and not run.boss_cleared
		and run.first_clear_count() >= 2
		and rng.randf() < minf(1.0, BOSS_CHANCE_PER_CLEAR * run.first_clear_count())
	):
		return [boss.id]

	var result: Array[StringName] = [&"", &""]
	if not run.work_offer_seen and rng.randf() < WORK_OFFER_CHANCE:
		run.work_offer_seen = true
		var work_candidates := _eligible_rooms(
			rooms, MallRoomDefinition.Category.WORK, run, result
		)
		var work := _weighted_pick(work_candidates, rng, false, run)
		if work != null:
			result[rng.randi_range(0, 1)] = work.id

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
			preferred_category == MallRoomDefinition.Category.CHALLENGE,
			run,
		)
		if picked != null:
			result[index] = picked.id
	return result.filter(func(room_id: StringName) -> bool: return not room_id.is_empty())


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
			and not run.has_entered(room.id)
			and room.id not in selected_ids
		):
			result.append(room)
	return result


static func _weighted_pick(
	candidates: Array[MallRoomDefinition],
	rng: RandomNumberGenerator,
	weight_first_clears: bool,
	run: MallExpeditionState,
) -> MallRoomDefinition:
	if candidates.is_empty():
		return null
	var total_weight := 0
	var weights: Array[int] = []
	for room in candidates:
		var weight := room.generation_weight
		if weight_first_clears:
			weight *= 1 if run.is_first_cleared(room.id) else 3
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
