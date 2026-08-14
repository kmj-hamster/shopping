extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func test_each_track_loops_and_resumes_its_own_saved_position() -> void:
	var state := QuestGameState.new()
	var director := QuestBgmDirector.new()
	director.fade_seconds = 0.0
	director.setup(state)
	add_child_autoqfree(director)
	await get_tree().process_frame

	director.play_track(QuestBgmDirector.TRACK_EMPTY)
	assert_eq(director.active_track_id, QuestBgmDirector.TRACK_EMPTY)
	assert_true((director.active_player.stream as AudioStreamMP3).loop)
	director.active_player.seek(12.0)
	director.play_track(QuestBgmDirector.TRACK_DEBUSSY)
	assert_almost_eq(
		state.bgm_playback_position(QuestBgmDirector.TRACK_EMPTY),
		12.0,
		0.15,
	)
	assert_eq(director.active_track_id, QuestBgmDirector.TRACK_DEBUSSY)
	assert_true((director.active_player.stream as AudioStreamMP3).loop)
	director.active_player.seek(21.0)
	director.play_track(QuestBgmDirector.TRACK_DREAM)
	assert_almost_eq(
		state.bgm_playback_position(QuestBgmDirector.TRACK_DEBUSSY),
		21.0,
		0.15,
	)
	assert_true((director.active_player.stream as AudioStreamMP3).loop)
	director.play_track(QuestBgmDirector.TRACK_EMPTY)
	assert_almost_eq(director.active_player.get_playback_position(), 12.0, 0.15)


func test_requesting_the_current_track_does_not_restart_it() -> void:
	var state := QuestGameState.new()
	var director := QuestBgmDirector.new()
	director.fade_seconds = 0.0
	director.setup(state)
	add_child_autoqfree(director)
	await get_tree().process_frame
	director.play_track(QuestBgmDirector.TRACK_EMPTY)
	var player := director.active_player
	player.seek(8.0)
	director.play_track(QuestBgmDirector.TRACK_EMPTY)
	assert_same(director.active_player, player)
	assert_almost_eq(director.active_player.get_playback_position(), 8.0, 0.15)


func test_switching_tracks_crossfades_then_stops_the_outgoing_player() -> void:
	var state := QuestGameState.new()
	var director := QuestBgmDirector.new()
	director.fade_seconds = 0.04
	director.setup(state)
	add_child_autoqfree(director)
	await get_tree().process_frame
	director.play_track(QuestBgmDirector.TRACK_EMPTY)
	await get_tree().create_timer(0.06).timeout
	var outgoing := director.active_player
	outgoing.seek(3.0)
	director.play_track(QuestBgmDirector.TRACK_DEBUSSY)
	assert_true(outgoing.playing)
	assert_true(director.active_player.playing)
	assert_ne(director.active_player, outgoing)
	await get_tree().create_timer(0.06).timeout
	assert_false(outgoing.playing)
	assert_true(director.active_player.playing)
	assert_almost_eq(
		director.active_player.volume_db,
		QuestBgmDirector.PLAYBACK_VOLUME_DB,
		0.1,
	)
	assert_gte(state.bgm_playback_position(QuestBgmDirector.TRACK_EMPTY), 3.0)
