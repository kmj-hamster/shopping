extends GutTest

var screen: QuestTitleScreen


func before_each() -> void:
	LocaleManager.set_locale(LocaleManager.LOCALE_ZH, false)
	var packed := load("res://scenes/title/title.tscn") as PackedScene
	screen = packed.instantiate() as QuestTitleScreen
	add_child_autofree(screen)
	await get_tree().process_frame


func test_title_uses_reference_composition_without_todo_or_settings() -> void:
	assert_eq(
		screen.background.texture.resource_path,
		"res://resources/ui/title/title-background.png",
	)
	assert_eq(
		screen.frame.texture.resource_path,
		"res://resources/ui/frames/frame-map.png",
	)
	assert_eq(screen.title_logo.position, QuestTitleScreen.TITLE_RECT.position)
	assert_eq(screen.title_logo.size, QuestTitleScreen.TITLE_RECT.size)
	assert_eq(screen.protagonist_portrait.position, QuestTitleScreen.PORTRAIT_RECT.position)
	assert_eq(screen.protagonist_portrait.size, QuestTitleScreen.PORTRAIT_RECT.size)
	assert_eq(screen.background.size, Vector2(1280, 720))
	assert_eq(screen.frame.size, Vector2(1280, 720))
	assert_eq(screen.global_shadow.size, Vector2(1280, 720))
	assert_eq(
		screen.protagonist_portrait.texture.resource_path,
		"res://resources/character/bag.png",
	)
	assert_null(screen.find_child("QuestTaskDock", true, false))
	assert_null(screen.find_child("SettingsButton", true, false))
	assert_null(screen.find_child("LanguageButton", true, false))


func test_start_is_localized_text_without_a_button_panel_and_has_hover_color() -> void:
	assert_true(screen.start_button.flat)
	assert_eq(screen.start_button.text, "开始游戏")
	assert_eq(screen.start_button.tooltip_text, "")
	assert_ne(
		screen.start_button.get_theme_color("font_color"),
		screen.start_button.get_theme_color("font_hover_color"),
	)
	LocaleManager.set_locale(LocaleManager.LOCALE_EN, false)
	await get_tree().process_frame
	assert_eq(screen.start_button.text, "Start Game")


func test_exit_uses_the_red_cross_and_both_actions_are_wired() -> void:
	assert_eq(
		screen.exit_button.texture_normal.resource_path,
		"res://resources/ui/title/title-exit.png",
	)
	assert_eq(screen.exit_button.position, QuestTitleScreen.EXIT_RECT.position)
	assert_true(screen.start_button.pressed.is_connected(screen._on_start_pressed))
	assert_true(screen.exit_button.pressed.is_connected(screen._on_exit_pressed))
