class_name QuestTitleScreen
extends Control

signal start_requested
signal exit_requested

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const BACKGROUND_TEXTURE := preload("res://resources/ui/title/title-background.png")
const FRAME_TEXTURE := preload("res://resources/ui/frames/frame-map.png")
const TITLE_TEXTURE := preload("res://resources/ui/title/title-logo.png")
const PORTRAIT_TEXTURE := preload("res://resources/character/bag.png")
const EXIT_TEXTURE := preload("res://resources/ui/title/title-exit.png")
const SHADOW_TEXTURE := preload("res://resources/ui/shell/shadow-global.png")
const ZH_UI_THEME := preload("res://resources/fonts/shancha_ui_theme.tres")
const EN_UI_THEME := preload("res://resources/fonts/zpix_ui_theme.tres")

const TITLE_RECT := Rect2(493, 61, 294, 204)
const PORTRAIT_RECT := Rect2(538, 386, 204, 468)
const START_RECT := Rect2(466, 614, 348, 68)
const EXIT_RECT := Rect2(1127, 40, 49, 52)
const LEFT_LINE_RECT := Rect2(474, 647, 69, 2)
const RIGHT_LINE_RECT := Rect2(737, 647, 69, 2)
const LEFT_LINE_GLOW_RECT := Rect2(469, 643, 79, 10)
const RIGHT_LINE_GLOW_RECT := Rect2(732, 643, 79, 10)
const START_FONT_SIZE := 35
const START_COLOR := Color("dce8ea")
const START_HOVER_COLOR := Color("72c8ee")
const START_OUTLINE_COLOR := Color("297fa5", 0.9)
const LINE_COLOR := Color("b9efff", 0.9)
const LINE_GLOW_COLOR := Color("3abcf1", 0.14)

var background: TextureRect
var frame: TextureRect
var title_logo: TextureRect
var protagonist_portrait: TextureRect
var start_button: Button
var exit_button: TextureButton
var global_shadow: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_artwork()
	_build_start_button()
	_build_exit_button()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_refresh_locale()


func _build_artwork() -> void:
	var night_fill := ColorRect.new()
	night_fill.name = "TitleNightFill"
	night_fill.color = Color("071923")
	night_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_fill)

	background = _make_texture_rect(
		"TitleBackground",
		BACKGROUND_TEXTURE,
		Rect2(Vector2.ZERO, Vector2(1280, 720)),
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	add_child(background)

	frame = _make_texture_rect(
		"TitleFrame",
		FRAME_TEXTURE,
		Rect2(Vector2.ZERO, Vector2(1280, 720)),
		TextureRect.STRETCH_SCALE
	)
	frame.z_index = 10
	add_child(frame)

	title_logo = _make_texture_rect(
		"TitleLogo",
		TITLE_TEXTURE,
		TITLE_RECT,
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	title_logo.z_index = 20
	add_child(title_logo)

	protagonist_portrait = _make_texture_rect(
		"TitleProtagonist",
		PORTRAIT_TEXTURE,
		PORTRAIT_RECT,
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	protagonist_portrait.z_index = 20
	add_child(protagonist_portrait)

	global_shadow = _make_texture_rect(
		"TitleGlobalShadow",
		SHADOW_TEXTURE,
		Rect2(Vector2.ZERO, Vector2(1280, 720)),
		TextureRect.STRETCH_SCALE
	)
	global_shadow.z_index = 60
	add_child(global_shadow)


func _build_start_button() -> void:
	_add_start_line("StartLeftGlow", LEFT_LINE_GLOW_RECT, LINE_GLOW_COLOR)
	_add_start_line("StartRightGlow", RIGHT_LINE_GLOW_RECT, LINE_GLOW_COLOR)
	_add_start_line("StartLeftLine", LEFT_LINE_RECT, LINE_COLOR)
	_add_start_line("StartRightLine", RIGHT_LINE_RECT, LINE_COLOR)

	start_button = Button.new()
	start_button.name = "StartGameButton"
	start_button.position = START_RECT.position
	start_button.size = START_RECT.size
	start_button.flat = true
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start_button.tooltip_text = ""
	start_button.add_theme_font_size_override("font_size", START_FONT_SIZE)
	start_button.add_theme_color_override("font_color", START_COLOR)
	start_button.add_theme_color_override("font_hover_color", START_HOVER_COLOR)
	start_button.add_theme_color_override("font_pressed_color", START_HOVER_COLOR)
	start_button.add_theme_color_override("font_hover_pressed_color", START_HOVER_COLOR)
	start_button.add_theme_color_override("font_focus_color", START_HOVER_COLOR)
	start_button.add_theme_color_override("font_outline_color", START_OUTLINE_COLOR)
	start_button.add_theme_constant_override("outline_size", 2)
	start_button.pressed.connect(_on_start_pressed)
	start_button.z_index = 30
	add_child(start_button)


func _build_exit_button() -> void:
	exit_button = TextureButton.new()
	exit_button.name = "ExitGameButton"
	exit_button.texture_normal = EXIT_TEXTURE
	exit_button.texture_hover = EXIT_TEXTURE
	exit_button.texture_pressed = EXIT_TEXTURE
	exit_button.ignore_texture_size = true
	exit_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	exit_button.position = EXIT_RECT.position
	exit_button.size = EXIT_RECT.size
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exit_button.tooltip_text = ""
	exit_button.pressed.connect(_on_exit_pressed)
	exit_button.z_index = 70
	add_child(exit_button)


func _make_texture_rect(
	node_name: String,
	texture: Texture2D,
	rect: Rect2,
	stretch: TextureRect.StretchMode
) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = node_name
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = stretch
	texture_rect.position = rect.position
	texture_rect.size = rect.size
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_rect


func _add_start_line(node_name: String, rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	line.name = node_name
	line.position = rect.position
	line.size = rect.size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.z_index = 25
	add_child(line)


func _refresh_locale() -> void:
	theme = EN_UI_THEME if LocaleManager.current_locale == LocaleManager.LOCALE_EN else ZH_UI_THEME
	if start_button != null:
		start_button.text = TranslationServer.translate(&"title.ui.start_game")


func _on_locale_changed(_locale: String) -> void:
	_refresh_locale()


func _on_start_pressed() -> void:
	start_requested.emit()
	start_button.disabled = true
	var error := get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if error != OK:
		start_button.disabled = false
		push_error("Unable to enter the shopping flow: %s" % error_string(error))


func _on_exit_pressed() -> void:
	exit_requested.emit()
	get_tree().quit()
