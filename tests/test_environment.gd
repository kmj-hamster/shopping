extends GutTest


func test_engine_is_godot_4_7() -> void:
	var version := Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 7)


func test_project_name_is_shopping() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "shopping")


func test_map_source_asset_exists() -> void:
	assert_true(FileAccess.file_exists("res://pic/map.png"))
	assert_true(FileAccess.file_exists("res://pic/bag.png"))
	assert_true(FileAccess.file_exists("res://pic/bag-light.png"))


func test_player_facing_shop_scene_is_the_main_scene() -> void:
	assert_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/main/main.tscn"
	)
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	assert_not_null(scene)


func test_mcp_authored_scene_loads() -> void:
	var scene := load("res://tests/fixtures/mcp_smoke.tscn") as PackedScene
	assert_not_null(scene)
	var instance := scene.instantiate()
	autofree(instance)
	assert_eq(instance.get_node("Status").text, "MCP scene authoring is operational")
