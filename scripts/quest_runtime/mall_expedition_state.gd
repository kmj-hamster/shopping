class_name MallExpeditionState
extends RefCounted

const ROOMS_PER_NIGHT := 3

var active := false
var from_day := 1
var rooms_completed := 0
var entered_room_ids: Dictionary = {}
var work_offer_seen := false
var current_door_ids: Array[StringName] = []
var rng_seed := 1
var rng_state := 0
var checkpoint_serial := 0
var disease_game_over_id: StringName

var discovered_room_ids: Dictionary = {}
var first_cleared_challenge_ids: Dictionary = {}
var boss_cleared := false


func begin_night(day: int, seed_value: int) -> void:
	active = true
	from_day = maxi(1, day)
	rooms_completed = 0
	entered_room_ids.clear()
	work_offer_seen = false
	current_door_ids.clear()
	rng_seed = maxi(1, seed_value)
	rng_state = 0
	checkpoint_serial = 0
	disease_game_over_id = &""


func begin_disease_end(day: int, disease_id: StringName) -> void:
	active = true
	from_day = maxi(1, day)
	rooms_completed = 0
	entered_room_ids.clear()
	work_offer_seen = false
	current_door_ids.clear()
	rng_seed = 1
	rng_state = 0
	checkpoint_serial = 0
	disease_game_over_id = disease_id


func end_night() -> void:
	active = false
	rooms_completed = 0
	entered_room_ids.clear()
	work_offer_seen = false
	current_door_ids.clear()
	rng_state = 0
	checkpoint_serial = 0
	disease_game_over_id = &""


func has_entered(room_id: StringName) -> bool:
	return entered_room_ids.has(room_id)


func is_discovered(room_id: StringName) -> bool:
	return discovered_room_ids.has(room_id)


func is_first_cleared(room_id: StringName) -> bool:
	return first_cleared_challenge_ids.has(room_id)


func first_clear_count() -> int:
	return first_cleared_challenge_ids.size()


func has_current_door(room_id: StringName) -> bool:
	return room_id in current_door_ids


func reached_night_limit() -> bool:
	return rooms_completed >= ROOMS_PER_NIGHT
