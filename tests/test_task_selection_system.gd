extends GutTest


func before_all() -> void:
	assert_true(QuestArcCatalog.use_manifest_for_tests(QuestArcCatalog.MANIFEST_PATH))


func after_all() -> void:
	QuestArcCatalog.clear_manifest_test_override()


func test_removed_daily_and_self_care_pools_cannot_generate_offers() -> void:
	var state := QuestGameState.new()
	assert_eq(QuestArcCatalog.manifest().tasks.size(), 0)
	assert_true(state.task_instances.is_empty())
	assert_true(state.prepare_task_offers_for_day().is_empty())
	assert_false(state.has_pending_task_offers())


func test_formal_main_does_not_instantiate_the_removed_offer_overlay() -> void:
	GameState.reset_game()
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate() as QuestMain
	add_child_autoqfree(main)
	await get_tree().process_frame
	assert_null(main.task_offer_overlay)
