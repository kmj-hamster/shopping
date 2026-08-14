extends GutTest

const RUNTIME_UI_KEYS: Array[StringName] = [
	&"slot.item_detail.close",
	&"demo.ui.money",
	&"demo.ui.night",
	&"demo.ui.next_day",
	&"demo.ui.next_day.question",
	&"demo.ui.confirm",
	&"demo.ui.cancel",
	&"demo.ui.clear_save",
	&"demo.ui.clear_save.tooltip",
	&"demo.ui.or",
	&"demo.ui.price",
	&"demo.ui.rule.title",
	&"demo.ui.rule.must",
	&"demo.ui.rule.bonus",
	&"demo.ui.rule.recently_used",
	&"demo.ui.rule.extra_money",
	&"demo.ui.arc.money_reward",
	&"demo.ui.arc.stat_reward",
	&"demo.ui.arc.new_day.body",
	&"quest.ui.hand.items",
	&"quest.ui.hand.masks",
	&"quest.ui.hand.title",
	&"quest.ui.arc.empty",
	&"quest.ui.arc.new_day",
	&"quest.ui.arc.night",
	&"quest.ui.synthesis.open",
	&"quest.ui.back",
	&"quest.ui.owner.talk",
	&"quest.ui.shop.checkout",
	&"quest.ui.shop.page_locked",
	&"quest.ui.shop.shelf",
	&"quest.ui.shop.sold",
	&"demo.ui.synthesis.candidates",
	&"demo.ui.synthesis.drag_result",
	&"demo.ui.synthesis.flip_result",
	&"demo.ui.synthesis.no_candidates",
	&"demo.ui.synthesis.totals",
	&"demo.ui.synthesis.unknown_candidate",
	&"quest.ui.synthesis.action",
	&"quest.ui.synthesis.title",
	&"quest.ui.task.gift",
	&"quest.ui.task.not_ready",
	&"opening.ui.shop.restock",
	&"opening.ui.shop.not_open",
	&"opening.ui.next_day.self_care_required",
	&"opening.ui.persona.reveal",
	&"opening.ui.persona.flip",
	&"opening.ui.persona.continue",
]

var original_locale: String


func before_each() -> void:
	original_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(original_locale)


func test_all_quest_arc_content_keys_exist_in_chinese_and_english() -> void:
	var keys: Array[StringName] = []
	var manifest := QuestArcCatalog.manifest()
	for raw_property in manifest.properties:
		var property := raw_property as PropertyDefinition
		keys.append(property.display_name_key)
		keys.append(property.description_key)
	for raw_item in manifest.items:
		var item := raw_item as QuestItemDefinition
		keys.append(item.display_name_key)
		keys.append(item.description_key)
	for raw_task in manifest.tasks:
		var task := raw_task as TaskDefinition
		keys.append(task.display_name_key)
		keys.append(task.body_text_key)
		if not task.footer_text_key.is_empty():
			keys.append(task.footer_text_key)
		for raw_rule in task.slot_rules:
			keys.append((raw_rule as CardSlotRule).display_name_key)
		for raw_outcome in task.outcomes:
			keys.append((raw_outcome as TaskOutcomeDefinition).result_text_key)
	for raw_recipe in manifest.recipes:
		var recipe := raw_recipe as SynthesisRecipeDefinition
		keys.append(recipe.display_name_key)
		keys.append(recipe.base_rule.display_name_key)
		for process_text_key in recipe.process_text_keys:
			keys.append(process_text_key)
	for persona_id in PersonaMaskCatalog.MASK_PERSONAS:
		var mask := PersonaMaskCatalog.definition_for_persona(persona_id, 1)
		keys.append(mask.display_name_key)
		keys.append(mask.description_key)
	for role_id in [&"base", &"fuel", &"mask"]:
		keys.append(StringName("demo.ui.synthesis.%s" % role_id))
		keys.append(StringName("demo.ui.synthesis.%s.description" % role_id))
	keys.append_array(RUNTIME_UI_KEYS)
	for raw_store in manifest.stores:
		keys.append((raw_store as StoreDefinition).display_name_key)
	for raw_unlock in manifest.store_unlocks:
		var unlock := raw_unlock as StoreUnlockDefinition
		keys.append(unlock.slot_rule.display_name_key)
		keys.append(unlock.prompt_text_key)
		keys.append(unlock.result_text_key)
	for raw_owner in manifest.owners:
		var owner := raw_owner as OwnerDefinition
		keys.append(owner.display_name_key)
		keys.append(owner.idle_dialogue_key)
		keys.append(owner.item_comment_key)
		if not owner.request_task_id.is_empty():
			keys.append(owner.request_dialogue_key)
			keys.append(owner.reminder_dialogue_key)
			for raw_key in owner.state_dialogue_keys.values():
				keys.append(StringName(raw_key))

	for locale in [&"zh_CN", &"en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_false(key.is_empty())
			assert_ne(TranslationServer.translate(key), String(key), "%s missing in %s" % [key, locale])


func test_night_form_descriptions_match_each_sleepless_role() -> void:
	var expected_descriptions := {
		&"zh_CN": {
			&"lamp": "交流电，明亮的街角，飞蛾噼啪作响。夜晚使我的头脑更加清醒。[夜之形，理性、好奇，致所有夜行者。]",
			&"gauze": "远古鱼游过卧室的墙，湿漉漉的水泥枝条开满白花，夜晚使我的灵感无所遁形。[夜之形，幻觉、随想，致所有梦游者。]",
			&"mirror": "看见我，你就看到了另一个自己。握住我，你就握住了自己的另一只手。夜晚使我想起忧伤之事。[夜之形，共情、怀旧，致所有悼念者。]",
			&"pillow": "凉爽的鹅绒被，床头的薰衣草，天明前的片刻慰藉。祝你今夜好眠，今夜。[夜之形，享受、安歇，致所有倦归者。]",
		},
		&"en": {
			&"lamp": "Alternating current, a brightly lit street corner, moths crackling in the light. Night makes my mind clearer. [A form of the night: reason and curiosity, for all Nightwalkers.]",
			&"gauze": "Ancient fish swim across the bedroom wall; damp concrete branches bloom with white flowers. Night leaves my inspiration nowhere to hide. [A form of the night: hallucination and reverie, for all Dreamwalkers.]",
			&"mirror": "See me, and you see another you. Hold me, and you hold your own other hand. Night makes me remember sorrowful things. [A form of the night: empathy and nostalgia, for all Mourners.]",
			&"pillow": "A cool goose-down duvet, lavender at the bedside, a moment of comfort before dawn. Sleep well tonight, tonight. [A form of the night: pleasure and repose, for all Homecomers.]",
		},
	}
	for locale in expected_descriptions:
		TranslationServer.set_locale(locale)
		for aspect_id in expected_descriptions[locale]:
			var property := QuestArcCatalog.property_by_id(aspect_id)
			assert_eq(
				TranslationServer.translate(property.description_key),
				expected_descriptions[locale][aspect_id],
				"%s description should match in %s" % [aspect_id, locale],
			)
