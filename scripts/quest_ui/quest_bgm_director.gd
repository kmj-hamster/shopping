class_name QuestBgmDirector
extends Node

const TRACK_EMPTY := &"empty"
const TRACK_DEBUSSY := &"debussy"
const TRACK_DREAM := &"dream"
const DEFAULT_FADE_SECONDS := 0.30
const PLAYBACK_VOLUME_DB := -8.0
const SILENT_VOLUME_DB := -48.0
const TRACK_STREAMS: Dictionary = {
	TRACK_EMPTY: preload("res://resources/audio/empty.mp3"),
	TRACK_DEBUSSY: preload("res://resources/audio/debussy.mp3"),
	TRACK_DREAM: preload("res://resources/audio/dream.mp3"),
}

var state: QuestGameState
var fade_seconds := DEFAULT_FADE_SECONDS
var players: Array[AudioStreamPlayer] = []
var active_player: AudioStreamPlayer
var active_track_id: StringName
var player_track_ids: Dictionary = {}
var fade_tween: Tween
var transition_revision := 0


func setup(game_state: QuestGameState) -> void:
	state = game_state


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "BgmPlayer%d" % (index + 1)
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = SILENT_VOLUME_DB
		add_child(player)
		players.append(player)


func play_track(track_id: StringName) -> void:
	if not TRACK_STREAMS.has(track_id):
		push_error("Unknown BGM track: %s" % track_id)
		return
	if not is_node_ready():
		call_deferred("play_track", track_id)
		return
	if active_track_id == track_id and active_player != null and active_player.playing:
		return
	_cancel_incomplete_crossfade()
	var outgoing := active_player
	var incoming := _inactive_player(outgoing)
	_capture_and_stop(incoming)
	var stream := (TRACK_STREAMS[track_id] as AudioStreamMP3).duplicate() as AudioStreamMP3
	stream.loop = true
	incoming.stream = stream
	incoming.volume_db = SILENT_VOLUME_DB
	player_track_ids[incoming] = track_id
	incoming.play(_saved_position(track_id, stream))
	active_player = incoming
	active_track_id = track_id
	transition_revision += 1
	var revision := transition_revision
	if fade_seconds <= 0.0:
		incoming.volume_db = PLAYBACK_VOLUME_DB
		_capture_and_stop(outgoing)
		return
	var tween := create_tween().set_parallel(true)
	if outgoing != null and outgoing.playing:
		tween.tween_property(outgoing, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	tween.tween_property(incoming, "volume_db", PLAYBACK_VOLUME_DB, fade_seconds)
	fade_tween = tween
	tween.finished.connect(_on_crossfade_finished.bind(revision, outgoing))


func capture_active_position() -> void:
	if active_player == null or not active_player.playing or active_track_id.is_empty():
		return
	_remember_position(active_track_id, active_player.get_playback_position())


func _inactive_player(outgoing: AudioStreamPlayer) -> AudioStreamPlayer:
	if outgoing == null or outgoing == players[1]:
		return players[0]
	return players[1]


func _cancel_incomplete_crossfade() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = null
	for player in players:
		if player != active_player and player.playing:
			_capture_and_stop(player)


func _on_crossfade_finished(revision: int, outgoing: AudioStreamPlayer) -> void:
	if revision != transition_revision:
		return
	fade_tween = null
	if outgoing != null and outgoing != active_player:
		_capture_and_stop(outgoing)


func _capture_and_stop(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	var track_id := player_track_ids.get(player, &"") as StringName
	if player.playing and not track_id.is_empty():
		_remember_position(track_id, player.get_playback_position())
	player.stop()
	player.stream = null
	player.volume_db = SILENT_VOLUME_DB
	player_track_ids.erase(player)


func _saved_position(track_id: StringName, stream: AudioStreamMP3) -> float:
	var position := state.bgm_playback_position(track_id) if state != null else 0.0
	var length := stream.get_length()
	return fposmod(position, length) if length > 0.0 else 0.0


func _remember_position(track_id: StringName, position: float) -> void:
	if state != null and not track_id.is_empty():
		state.remember_bgm_playback_position(track_id, position)


func _exit_tree() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	for player in players:
		if player.playing:
			var track_id := player_track_ids.get(player, &"") as StringName
			if not track_id.is_empty():
				_remember_position(track_id, player.get_playback_position())
