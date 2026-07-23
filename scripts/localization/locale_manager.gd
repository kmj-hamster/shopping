extends Node

signal locale_changed(locale: String)

const LOCALE_ZH := "zh_CN"
const LOCALE_EN := "en"
const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES := [LOCALE_ZH, LOCALE_EN]

var current_locale := LOCALE_ZH


func _ready() -> void:
	var preferred := _load_saved_locale()
	if preferred.is_empty():
		preferred = LOCALE_ZH if OS.get_locale().begins_with("zh") else LOCALE_EN
	set_locale(preferred, false)


func set_locale(locale: String, persist: bool = true) -> void:
	if locale not in SUPPORTED_LOCALES:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	if persist:
		_save_locale(locale)
	locale_changed.emit(locale)


func toggle_locale() -> void:
	set_locale(LOCALE_EN if current_locale == LOCALE_ZH else LOCALE_ZH)


func switch_button_text() -> String:
	return "EN" if current_locale == LOCALE_ZH else "中文"


func _load_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return ""
	var saved := str(config.get_value("accessibility", "locale", ""))
	return saved if saved in SUPPORTED_LOCALES else ""


func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("accessibility", "locale", locale)
	config.save(SETTINGS_PATH)
