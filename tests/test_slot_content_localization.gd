extends GutTest

var original_locale: String


func before_each() -> void:
	original_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(original_locale)


func test_every_slot_demo_content_key_exists_in_both_locales() -> void:
	var keys: Array[StringName] = []
	keys.append_array([
		&"slot.aspect.lamp",
		&"slot.aspect.mirror",
		&"slot.aspect.candle",
		&"slot.aspect.pillow",
		&"slot.hand.title",
		&"slot.hand.empty",
		&"slot.shop.empty_shelf",
		&"slot.shop.cart",
		&"slot.shop.cancel",
		&"slot.shop.checkout",
		&"slot.shop.feedback.ready",
		&"slot.shop.feedback.selected",
		&"slot.shop.feedback.paid",
		&"slot.shop.feedback.cancelled",
		&"slot.shop.feedback.no_money",
		&"slot.shop.feedback.empty",
		&"slot.recycle.title",
		&"slot.recycle.hint",
		&"slot.recycle.cart",
		&"slot.recycle.cancel",
		&"slot.recycle.checkout",
		&"slot.recycle.feedback.staged",
		&"slot.recycle.feedback.returned",
		&"slot.recycle.feedback.paid",
		&"slot.recycle.feedback.invalid",
	])
	for item in SlotDemoCatalog.all_items():
		keys.append(item.display_name_key)
	for wish in SlotDemoCatalog.wishes():
		keys.append(wish.display_name_key)
		for result_key in wish.result_text_keys.values():
			keys.append(StringName(result_key))
	for recipe in SlotDemoCatalog.recipes():
		keys.append(recipe.display_name_key)
		for raw_rule in recipe.slot_rules:
			var rule := raw_rule as CardSlotRule
			keys.append(rule.display_name_key)
		for preview_key in recipe.preview_text_by_output.values():
			keys.append(StringName(preview_key))

	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_false(key.is_empty())
			assert_ne(TranslationServer.translate(key), String(key), "%s missing in %s" % [key, locale])
