extends GutTest

var original_locale: String


func before_each() -> void:
	original_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(original_locale)


func test_title_and_attributes_are_translated_in_both_locales() -> void:
	TranslationServer.set_locale("zh_CN")
	assert_eq(TranslationServer.translate(&"app.title"), "千禧年购物指南 · 拼图实验室")
	assert_eq(TranslationServer.translate(&"attribute.mirror"), "镜")

	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate(&"app.title"), "Millennium Shopping Guide · Puzzle Lab")
	assert_eq(TranslationServer.translate(&"attribute.mirror"), "Mirror")


func test_every_catalog_item_has_chinese_and_english_names() -> void:
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for item in DemoCatalog.all_items():
			assert_ne(item.localized_name(), String(item.display_name_key), "%s missing in %s" % [item.id, locale])


func test_every_task_has_chinese_and_english_copy() -> void:
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for task in DemoCatalog.all_tasks():
			assert_ne(task.localized_name(), String(task.display_name_key), "%s title missing in %s" % [task.id, locale])
			assert_ne(task.localized_description(), String(task.description_key), "%s description missing in %s" % [task.id, locale])


func test_locale_manager_exposes_only_supported_locales() -> void:
	assert_eq(LocaleManager.SUPPORTED_LOCALES, ["zh_CN", "en"])
	assert_true(LocaleManager.current_locale in LocaleManager.SUPPORTED_LOCALES)

