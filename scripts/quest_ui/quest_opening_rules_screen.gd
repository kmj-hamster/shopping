class_name QuestOpeningRulesScreen
extends CanvasLayer

signal finished

const ZH_UI_THEME: Theme = preload("res://resources/fonts/shancha_ui_theme.tres")
const EN_UI_THEME: Theme = preload("res://resources/fonts/zpix_ui_theme.tres")
const EN_UI_FONT: FontFile = preload("res://resources/fonts/zpix.woff2")
const ZH_FALLBACK_FONT: FontFile = preload("res://resources/fonts/zpix.woff2")
const ENGLISH_TRACKING_RATIO := 0.03
const SCREEN_LAYER := 450
const INK := Color("f4f6f5")
const WARNING := Color("c93f46")
const ZH_FONT_SIZE := 30
const EN_FONT_SIZE := 25
const FALLBACK_CHARACTER_SECONDS := 0.055
const FALLBACK_WORD_SECONDS := 0.14
const AUDIO_TAIL_SECONDS := 0.12
const PAGE_AUTO_ADVANCE_SECONDS := 2.0
const AUTO_HIDE_HOLD_SECONDS := 0.38
const AUTO_HIDE_FADE_SECONDS := 0.72
const BACKGROUND_ART_ALPHA := 0.12

const PAGE_BACKGROUNDS := {
	1: {
		"texture_path": "res://resources/background/opening/rule-night3.png",
		"portrait": false,
	},
	2: {
		"texture_path": "res://resources/character/bag.png",
		"portrait": true,
	},
	3: {
		"texture_path": "res://resources/background/opening/rule-night1.png",
		"portrait": false,
	},
	5: {
		"texture_path": "res://resources/background/opening/rule-night2.png",
		"portrait": false,
	},
	6: {
		"texture_path": "res://resources/background/map.png",
		"portrait": false,
	},
}

const PAGES := [
	[
		{
			"text_key": &"opening.rules.0.welcome",
			"audio_path": "res://resources/audio/opening/0-1.mp3",
		},
		{
			"text_key": &"opening.rules.0.intro",
			"audio_path": "res://resources/audio/opening/0-2.mp3",
		},
	],
	[
		{
			"text_key": &"opening.rules.1",
			"audio_path": "res://resources/audio/opening/1.mp3",
		},
	],
	[
		{
			"text_key": &"opening.rules.2.1",
			"audio_path": "res://resources/audio/opening/2-1.mp3",
		},
		{
			"text_key": &"opening.rules.2.2",
			"audio_path": "res://resources/audio/opening/2-2.mp3",
		},
	],
	[
		{
			"text_key": &"opening.rules.3.1",
			"audio_path": "res://resources/audio/opening/3-1.mp3",
		},
		{
			"text_key": &"opening.rules.3.2",
			"audio_path": "res://resources/audio/opening/3-2.mp3",
		},
	],
	[
		{
			"text_key": &"opening.rules.4",
			"audio_path": "res://resources/audio/opening/4.mp3",
			"red": true,
		},
	],
	[
		{
			"text_key": &"opening.rules.5.1",
			"audio_path": "res://resources/audio/opening/5-1.mp3",
			"reveal_duration_ratio": 0.58,
		},
		{
			"text_key": &"opening.rules.5.2",
			"audio_path": "res://resources/audio/opening/5-2.mp3",
		},
	],
	[
		{
			"text_key": &"opening.rules.6.1",
			"audio_path": "res://resources/audio/opening/6-1.mp3",
		},
		{
			"text_key": &"opening.rules.6.2",
			"audio_path": "res://resources/audio/opening/6-2.mp3",
		},
		{
			"text_key": &"opening.rules.6.3",
			"audio_path": "res://resources/audio/opening/6-3.mp3",
			"red": true,
			"auto_hide": true,
		},
	],
]

var page_index := 0
var line_index := 0
var typing := false
var character_index := 0
var reveal_unit_index := 0
var reveal_boundaries := PackedInt32Array()
var line_had_pointer_input := false
var current_audio_path := ""
var line_labels: Array[RichTextLabel] = []
var current_label: RichTextLabel
var typewriter_timer: Timer
var page_advance_timer: Timer
var audio_player: AudioStreamPlayer
var auto_hide_tween: Tween
var screen_root: Control
var background_art: TextureRect
var line_host: VBoxContainer
var english_font: FontVariation


func _ready() -> void:
	layer = SCREEN_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	_start_page(0)


func _build_interface() -> void:
	screen_root = Control.new()
	screen_root.name = "OpeningRulesRoot"
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen_root)

	var background := ColorRect.new()
	background.name = "OpeningRulesBlackBackground"
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(background)
	background_art = TextureRect.new()
	background_art.name = "OpeningRulesBackgroundArt"
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_art.self_modulate = Color(1.0, 1.0, 1.0, BACKGROUND_ART_ALPHA)
	background_art.visible = false
	screen_root.add_child(background_art)

	var input_catcher := Control.new()
	input_catcher.name = "OpeningRulesInput"
	input_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	input_catcher.gui_input.connect(_on_gui_input)
	screen_root.add_child(input_catcher)

	var center := CenterContainer.new()
	center.name = "OpeningRulesCenter"
	center.anchor_left = 0.08
	center.anchor_top = 0.18
	center.anchor_right = 0.92
	center.anchor_bottom = 0.82
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(center)

	line_host = VBoxContainer.new()
	line_host.name = "OpeningRulesLines"
	line_host.custom_minimum_size = Vector2(980, 0)
	line_host.alignment = BoxContainer.ALIGNMENT_CENTER
	line_host.add_theme_constant_override("separation", 20)
	line_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(line_host)

	typewriter_timer = Timer.new()
	typewriter_timer.name = "OpeningRulesTypewriterTimer"
	typewriter_timer.one_shot = true
	typewriter_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	typewriter_timer.timeout.connect(_advance_typewriter)
	add_child(typewriter_timer)
	page_advance_timer = Timer.new()
	page_advance_timer.name = "OpeningRulesPageAdvanceTimer"
	page_advance_timer.one_shot = true
	page_advance_timer.wait_time = PAGE_AUTO_ADVANCE_SECONDS
	page_advance_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	page_advance_timer.timeout.connect(_on_page_advance_timeout)
	add_child(page_advance_timer)

	audio_player = AudioStreamPlayer.new()
	audio_player.name = "OpeningRulesVoice"
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_player.finished.connect(_on_audio_finished)
	add_child(audio_player)
	_apply_locale_style()


func advance(pointer_input: bool = true) -> void:
	if pointer_input:
		line_had_pointer_input = true
	if typing:
		_finish_current_sentence()
		return
	_advance_to_next_line()


func _advance_to_next_line() -> void:
	_cancel_page_advance()
	_stop_audio()
	_cancel_auto_hide()
	var page := PAGES[page_index] as Array
	if line_index + 1 < page.size():
		_start_line(line_index + 1)
		return
	if page_index + 1 < PAGES.size():
		_start_page(page_index + 1)
		return
	finished.emit()


func _start_page(next_page_index: int) -> void:
	_cancel_page_advance()
	_stop_audio()
	_cancel_auto_hide()
	page_index = clampi(next_page_index, 0, PAGES.size() - 1)
	line_index = 0
	character_index = 0
	reveal_unit_index = 0
	reveal_boundaries.clear()
	typing = false
	current_label = null
	for child in line_host.get_children():
		child.queue_free()
	line_labels.clear()
	_apply_page_background()
	_start_line(0)


func _apply_page_background() -> void:
	if background_art == null:
		return
	if not PAGE_BACKGROUNDS.has(page_index):
		background_art.visible = false
		background_art.texture = null
		return
	var definition := PAGE_BACKGROUNDS[page_index] as Dictionary
	background_art.texture = load(str(definition.get("texture_path", ""))) as Texture2D
	background_art.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if bool(definition.get("portrait", false))
		else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	background_art.visible = background_art.texture != null


func _start_line(next_line_index: int) -> void:
	_cancel_page_advance()
	_stop_audio()
	_cancel_auto_hide()
	line_index = next_line_index
	var definition := current_line_definition()
	current_label = _create_line_label(definition)
	line_labels.append(current_label)
	line_host.add_child(current_label)
	character_index = 0
	reveal_unit_index = 0
	reveal_boundaries = _build_reveal_boundaries(current_localized_text())
	line_had_pointer_input = false
	current_label.visible_characters = 0
	typing = true
	current_audio_path = str(definition.get("audio_path", ""))
	_play_current_audio()
	_refresh_typewriter_interval()
	_advance_typewriter()


func _create_line_label(definition: Dictionary) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = "RuleLine%d" % line_index
	label.custom_minimum_size = Vector2(980, 1)
	label.fit_content = true
	label.scroll_active = false
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _localized_line_bbcode(definition)
	_apply_label_style(label)
	return label


func _localized_line_bbcode(definition: Dictionary) -> String:
	var color := WARNING if bool(definition.get("red", false)) else INK
	return "[center][color=#%s]%s[/color][/center]" % [
		color.to_html(false),
		TranslationServer.translate(definition.get("text_key", &"")),
	]


func current_line_definition() -> Dictionary:
	return (PAGES[page_index] as Array)[line_index] as Dictionary


func current_localized_text() -> String:
	return TranslationServer.translate(current_line_definition().get("text_key", &""))


func _play_current_audio() -> void:
	if current_audio_path.is_empty():
		return
	var stream := load(current_audio_path) as AudioStream
	if stream == null:
		push_warning("Opening rule audio is missing: %s" % current_audio_path)
		return
	audio_player.stream = stream
	audio_player.play()


func _refresh_typewriter_interval() -> void:
	if current_label == null or typewriter_timer == null:
		return
	var remaining_units := maxi(1, reveal_boundaries.size() - reveal_unit_index)
	var remaining_audio_seconds := 0.0
	if audio_player.stream != null:
		var reveal_duration_ratio := float(
			current_line_definition().get("reveal_duration_ratio", 1.0)
		)
		remaining_audio_seconds = maxf(
			0.0,
			audio_player.stream.get_length() * reveal_duration_ratio
				- audio_player.get_playback_position()
				- AUDIO_TAIL_SECONDS,
		)
	typewriter_timer.wait_time = (
		remaining_audio_seconds / float(remaining_units)
		if remaining_audio_seconds > 0.0
		else (
			FALLBACK_WORD_SECONDS
			if LocaleManager.current_locale == LocaleManager.LOCALE_EN
			else FALLBACK_CHARACTER_SECONDS
		)
	)
	typewriter_timer.wait_time = maxf(typewriter_timer.wait_time, 0.01)


func _advance_typewriter() -> void:
	if not typing or current_label == null:
		return
	if reveal_boundaries.is_empty():
		_finish_current_sentence()
		return
	reveal_unit_index = mini(reveal_unit_index + 1, reveal_boundaries.size())
	character_index = reveal_boundaries[reveal_unit_index - 1]
	current_label.visible_characters = character_index
	if reveal_unit_index >= reveal_boundaries.size():
		_finish_current_sentence()
	else:
		typewriter_timer.start()


func _finish_current_sentence(start_auto_hide: bool = true) -> void:
	if current_label == null:
		return
	typewriter_timer.stop()
	current_label.visible_characters = -1
	character_index = current_label.get_total_character_count()
	reveal_unit_index = reveal_boundaries.size()
	typing = false
	if start_auto_hide:
		_try_start_auto_hide()


func _try_start_auto_hide(auto_advance_when_hidden: bool = false) -> void:
	if typing or current_label == null or audio_player.playing:
		return
	if not bool(current_line_definition().get("auto_hide", false)):
		return
	if auto_hide_tween != null and auto_hide_tween.is_valid():
		return
	auto_hide_tween = create_tween()
	auto_hide_tween.tween_interval(AUTO_HIDE_HOLD_SECONDS)
	auto_hide_tween.tween_property(
		current_label,
		"modulate:a",
		0.0,
		AUTO_HIDE_FADE_SECONDS,
	)
	auto_hide_tween.finished.connect(
		_on_auto_hide_finished.bind(auto_advance_when_hidden)
	)


func _on_audio_finished() -> void:
	var should_auto_advance := not line_had_pointer_input
	if typing:
		_finish_current_sentence(false)
	if bool(current_line_definition().get("auto_hide", false)):
		_try_start_auto_hide(should_auto_advance)
	elif should_auto_advance:
		_auto_advance_after_line()


func _on_auto_hide_finished(should_auto_advance: bool) -> void:
	auto_hide_tween = null
	if should_auto_advance and not line_had_pointer_input:
		_auto_advance_after_line()


func _auto_advance_after_line() -> void:
	var page := PAGES[page_index] as Array
	var changes_page := line_index + 1 >= page.size() and page_index + 1 < PAGES.size()
	if not changes_page:
		_advance_to_next_line()
		return
	_cancel_page_advance()
	page_advance_timer.start(PAGE_AUTO_ADVANCE_SECONDS)


func _on_page_advance_timeout() -> void:
	page_advance_timer.stop()
	if line_had_pointer_input:
		return
	_advance_to_next_line()


func _stop_audio() -> void:
	if audio_player != null:
		audio_player.stop()
		audio_player.stream = null
	current_audio_path = ""


func _cancel_auto_hide() -> void:
	if auto_hide_tween != null and auto_hide_tween.is_valid():
		auto_hide_tween.kill()
	auto_hide_tween = null


func _cancel_page_advance() -> void:
	if page_advance_timer != null:
		page_advance_timer.stop()


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		advance(true)
		(screen_root.get_node("OpeningRulesInput") as Control).accept_event()


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_style()
	for displayed_line_index in line_labels.size():
		var label := line_labels[displayed_line_index]
		var definition := (PAGES[page_index] as Array)[displayed_line_index] as Dictionary
		var was_current := displayed_line_index == line_index
		var visible_ratio := 1.0
		if was_current and typing:
			visible_ratio = float(character_index) / maxf(
				1.0,
				float(label.get_total_character_count()),
			)
		label.text = _localized_line_bbcode(definition)
		_apply_label_style(label)
		if was_current and typing:
			reveal_boundaries = _build_reveal_boundaries(current_localized_text())
			reveal_unit_index = clampi(
				roundi(reveal_boundaries.size() * visible_ratio),
				0,
				reveal_boundaries.size(),
			)
			character_index = (
				reveal_boundaries[reveal_unit_index - 1]
				if reveal_unit_index > 0
				else 0
			)
			label.visible_characters = character_index
			_refresh_typewriter_interval()
		else:
			label.visible_characters = -1


func _build_reveal_boundaries(text: String) -> PackedInt32Array:
	if LocaleManager.current_locale != LocaleManager.LOCALE_EN:
		var character_boundaries := PackedInt32Array()
		for index in text.length():
			character_boundaries.append(index + 1)
		return character_boundaries
	var word_boundaries := PackedInt32Array()
	var cursor := 0
	while cursor < text.length():
		while cursor < text.length() and _is_word_separator(text.substr(cursor, 1)):
			cursor += 1
		while cursor < text.length() and not _is_word_separator(text.substr(cursor, 1)):
			cursor += 1
		while cursor < text.length() and _is_word_separator(text.substr(cursor, 1)):
			cursor += 1
		if word_boundaries.is_empty() or word_boundaries[-1] != cursor:
			word_boundaries.append(cursor)
	return word_boundaries


func _is_word_separator(character: String) -> bool:
	return character in [" ", "\t", "\n", "\r"]


func _apply_locale_style() -> void:
	if screen_root == null:
		return
	screen_root.theme = (
		EN_UI_THEME if LocaleManager.current_locale == LocaleManager.LOCALE_EN else ZH_UI_THEME
	)
	if LocaleManager.current_locale == LocaleManager.LOCALE_EN:
		english_font = FontVariation.new()
		english_font.base_font = EN_UI_FONT
		var fallbacks: Array[Font] = [ZH_FALLBACK_FONT]
		english_font.fallbacks = fallbacks
		english_font.spacing_glyph = maxi(0, roundi(EN_FONT_SIZE * ENGLISH_TRACKING_RATIO))
	for label in line_labels:
		_apply_label_style(label)


func _apply_label_style(label: RichTextLabel) -> void:
	var font_size := (
		EN_FONT_SIZE if LocaleManager.current_locale == LocaleManager.LOCALE_EN else ZH_FONT_SIZE
	)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", INK)
	if LocaleManager.current_locale == LocaleManager.LOCALE_EN and english_font != null:
		label.add_theme_font_override("normal_font", english_font)
	else:
		label.remove_theme_font_override("normal_font")


func _exit_tree() -> void:
	_stop_audio()
	_cancel_auto_hide()
	_cancel_page_advance()
