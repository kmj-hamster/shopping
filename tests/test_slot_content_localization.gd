extends GutTest

var original_locale: String


func before_each() -> void:
	original_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(original_locale)


func test_every_slot_demo_content_key_exists_in_both_locales() -> void:
	var keys: Array[StringName] = []
	keys.append_array([
		&"game.title",
		&"map.day_week_money",
		&"map.open",
		&"map.closed_until",
		&"map.schedule",
		&"map.schedule.title",
		&"map.next_day",
		&"map.next_day.ready",
		&"map.notice.store_closed",
		&"demo.complete.title",
		&"demo.complete.body",
		&"demo.complete.continue",
		&"ui.language.tooltip",
		&"shop.leave",
		&"store.book",
		&"store.toy",
		&"store.flower",
		&"store.record",
		&"store.fast_food",
		&"store.recycling",
		&"weekday.mon",
		&"weekday.tue",
		&"weekday.wed",
		&"weekday.thu",
		&"weekday.fri",
		&"weekday.sat",
		&"weekday.sun",
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
		&"slot.map.next_day.synthesis_active",
		&"slot.synthesis.start",
		&"slot.synthesis.in_progress",
		&"slot.synthesis.complete",
		&"slot.synthesis.other_active",
		&"slot.synthesis.daily_risk",
		&"slot.synthesis.unavailable",
		&"slot.transition.night",
		&"slot.transition.new_day",
		&"slot.transition.income",
		&"slot.shop.feedback.daily_risk",
		&"slot.recycle.feedback.daily_risk",
		&"slot.owner.balloon.name",
		&"slot.owner.sunflower.name",
		&"slot.owner.gramophone.name",
		&"slot.owner.magical_girl.name",
		&"slot.owner.mouse.name",
		&"slot.owner.level.stranger",
		&"slot.owner.level.familiar",
		&"slot.owner.level.wish",
		&"slot.owner.level.friend",
		&"slot.owner.relation",
		&"slot.owner.talk",
		&"slot.owner.talk.done",
		&"slot.owner.talk.unavailable",
		&"slot.owner.placeholder.talk",
		&"slot.owner.placeholder.repeat",
		&"slot.owner.balloon.talk.day1",
		&"slot.owner.balloon.talk.day2",
		&"slot.owner.balloon.talk.day3",
		&"slot.owner.balloon.talk.repeat",
		&"slot.owner.balloon.level_up.1",
		&"slot.owner.balloon.level_up.2",
		&"slot.owner.balloon.level_up.3",
		&"slot.request.deliver",
		&"slot.request.delivered",
		&"slot.request.completed",
		&"slot.request.daily_risk",
		&"slot.request.unavailable",
		&"demo.complete.body.balloon_memory",
		&"demo.complete.body.balloon_comfort",
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
	for owner in SlotDemoCatalog.owners():
		keys.append(owner.display_name_key)
		keys.append_array(owner.level_name_keys)
		keys.append_array(owner.daily_dialogue_keys)
		keys.append(owner.repeat_dialogue_key)
		for level_up_key in owner.level_up_text_keys.values():
			keys.append(StringName(level_up_key))
	for request in SlotDemoCatalog.requests():
		keys.append(request.display_name_key)
		keys.append(request.slot_rule.display_name_key)
		for result_key in request.result_text_by_item.values():
			keys.append(StringName(result_key))

	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_false(key.is_empty())
			assert_ne(TranslationServer.translate(key), String(key), "%s missing in %s" % [key, locale])
