extends GutTest


func test_engine_is_godot_4_7() -> void:
	var version := Engine.get_version_info()
	assert_eq(version.major, 4)
	assert_eq(version.minor, 7)


func test_project_is_named() -> void:
	var project_name := str(ProjectSettings.get_setting("application/config/name", ""))
	assert_false(project_name.is_empty())


func test_workflow_addons_exist() -> void:
	assert_true(FileAccess.file_exists("res://addons/godot_ai/plugin.cfg"))
	assert_true(FileAccess.file_exists("res://addons/gut/plugin.cfg"))


func test_mcp_game_helper_is_configured() -> void:
	assert_true(ProjectSettings.has_setting("autoload/_mcp_game_helper"))
