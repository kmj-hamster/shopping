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
		&"slot.property.reading",
		&"slot.property.memory",
		&"slot.property.relaxing",
		&"slot.property.dreamlike",
		&"slot.property.music",
		&"slot.property.sleep_aid",
		&"slot.property.stimulating",
		&"slot.property.electric",
		&"slot.property.plant",
		&"slot.property.warm",
		&"slot.property.soft",
		&"slot.property.toy",
		&"slot.property.fragile",
		&"slot.property.food",
		&"slot.property.drink",
		&"slot.property.sweet",
		&"slot.property.crispy",
		&"slot.property.teddy",
		&"slot.property.alcohol",
		&"slot.rule.required",
		&"slot.rule.allowed",
		&"slot.rule.forbidden",
		&"slot.rule.minimum",
		&"slot.task.window.title",
		&"slot.task.tab.daily",
		&"slot.task.tab.recipes",
		&"slot.task.tab.requests",
		&"slot.task.single_slot",
		&"slot.task.none",
		&"slot.task.slot.empty",
		&"slot.task.slot.ready",
		&"slot.task.slot.blocked",
		&"slot.task.slot.insufficient",
		&"slot.task.ready",
		&"slot.task.waiting",
		&"slot.task.drop.rejected",
		&"slot.task.open",
		&"slot.task.confirm",
		&"slot.task.cancel_confirm",
		&"slot.task.confirmed",
		&"slot.map.next_day.incomplete",
		&"slot.transition.night",
		&"slot.transition.new_day",
		&"slot.transition.income",
		&"slot.shop.feedback.daily_risk",
		&"slot.recycle.feedback.daily_risk",
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
