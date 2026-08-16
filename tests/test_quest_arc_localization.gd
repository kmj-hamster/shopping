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
	&"quest.ui.arc.task_source",
	&"quest.ui.synthesis.open",
	&"debug.ui.synthesis_background.blue",
	&"debug.ui.synthesis_background.bag",
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
	&"quest.ui.synthesis.material",
	&"quest.ui.synthesis.material.description",
	&"quest.ui.synthesis.borrow_self",
	&"quest.ui.synthesis.borrow_self.description",
	&"quest.ui.synthesis.borrow_item",
	&"quest.ui.synthesis.borrow_item.description",
	&"quest.ui.synthesis.possibility.title",
	&"quest.ui.synthesis.possibility.default",
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
		keys.append(recipe.possibility_hint_key)
		for process_text_key in recipe.process_text_keys:
			keys.append(process_text_key)
	for persona_id in PersonaMaskCatalog.MASK_PERSONAS:
		var mask := PersonaMaskCatalog.definition_for_persona(persona_id, 1)
		keys.append(mask.display_name_key)
		keys.append(mask.description_key)
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


func test_persona_descriptions_match_each_confirmed_role() -> void:
	var expected_descriptions := {
		&"zh_CN": {
			&"nightwalker": "交流电，明亮的街角，飞蛾噼啪作响。夜晚使我的头脑更加清醒。[夜之面相，理性、好奇]",
			&"mourner": "看见我，你就看到了另一个自己。握住我，你就握住了自己的另一只手。夜晚使我想起忧伤之事。[夜之面相，共情、怀旧]",
			&"dreamwalker": "远古鱼游过卧室的墙，湿漉漉的水泥枝条开满白花，夜晚使我的灵感无所遁形。[夜之面相，幻觉、随想]",
			&"homecomer": "凉爽的鹅绒被，床头的薰衣草，天明前的片刻慰藉。祝我今夜好眠，今夜。[夜之面相，享受、安歇]",
		},
		&"en": {
			&"nightwalker": "Alternating current, a brightly lit street corner, moths crackling. Night makes my mind clearer. [Persona of the night: reason, curiosity]",
			&"mourner": "See me, and you see another self. Hold me, and you hold your own other hand. Night makes me remember sorrowful things. [Persona of the night: empathy, nostalgia]",
			&"dreamwalker": "Ancient fish swim across the bedroom wall; wet concrete branches bloom with white flowers. Night leaves my inspiration nowhere to hide. [Persona of the night: hallucination, reverie]",
			&"homecomer": "A cool goose-down quilt, lavender at the bedside, a moment of solace before dawn. May I sleep well tonight, tonight. [Persona of the night: pleasure, rest]",
		},
	}
	for locale in expected_descriptions:
		TranslationServer.set_locale(locale)
		for persona_id in expected_descriptions[locale]:
			var property := QuestArcCatalog.property_by_id(persona_id)
			assert_eq(
				TranslationServer.translate(property.description_key),
				expected_descriptions[locale][persona_id],
				"%s description should match in %s" % [persona_id, locale],
			)


func test_store_and_owner_names_match_confirmed_copy() -> void:
	var expected_names := {
		&"zh_CN": {
			&"opening.store.toy.name": "欣欣玩具店",
			&"opening.store.fast_food.name": "老鼠厨房",
			&"opening.store.flower.name": "花店",
			&"opening.store.record.name": "夜曲",
			&"opening.store.bookstore.name": "日月光书店",
			&"demo.store.flower.name": "花店",
			&"demo.store.record.name": "夜曲",
			&"opening.owner.toy.name": "气球叔叔",
			&"opening.owner.fast_food.name": "大老鼠",
			&"opening.owner.flower.name": "向日葵先生",
			&"quest.owner.balloon.name": "气球叔叔",
			&"quest.owner.mouse.name": "大老鼠",
			&"quest.owner.sunflower.name": "向日葵先生",
			&"quest.owner.gramophone.name": "留声机女士",
			&"quest.owner.magical_girl.name": "千花",
			&"demo.owner.flower.name": "向日葵先生",
			&"demo.owner.record.name": "留声机女士",
		},
		&"en": {
			&"opening.store.toy.name": "Joy Joy Toys",
			&"opening.store.fast_food.name": "Ratty’s Kitchen",
			&"opening.store.flower.name": "Flower Shop",
			&"opening.store.record.name": "Nocturne",
			&"opening.store.bookstore.name": "Sun & Moon Books",
			&"demo.store.flower.name": "Flower Shop",
			&"demo.store.record.name": "Nocturne",
			&"opening.owner.toy.name": "Uncle Balloon",
			&"opening.owner.fast_food.name": "Ratty",
			&"opening.owner.flower.name": "Mr. Sunflower",
			&"quest.owner.balloon.name": "Uncle Balloon",
			&"quest.owner.mouse.name": "Ratty",
			&"quest.owner.sunflower.name": "Mr. Sunflower",
			&"quest.owner.gramophone.name": "Miss Gramophone",
			&"quest.owner.magical_girl.name": "Chika",
			&"demo.owner.flower.name": "Mr. Sunflower",
			&"demo.owner.record.name": "Miss Gramophone",
		},
	}
	for locale in expected_names:
		TranslationServer.set_locale(locale)
		for key in expected_names[locale]:
			assert_eq(
				TranslationServer.translate(key),
				expected_names[locale][key],
				"%s should match in %s" % [key, locale],
			)


func test_shop_owner_copy_is_spoken_dialogue_in_both_locales() -> void:
	var expected_dialogue := {
		&"zh_CN": {
			&"opening.owner.toy.idle": "欢迎光临。今晚的玩具都在货架上，发条和轮子暂时还算听话。",
			&"opening.owner.fast_food.idle": "炸锅正热着。想吃什么就说，别让它们等凉了。",
			&"opening.owner.flower.idle": "嘘……花已经睡了。挑选的时候轻一点。",
			&"demo.owner.flower.reminder": "再看看我的茎……那些小白花还在。",
			&"demo.owner.flower.state.trimmed": "轻多了……那些小白花已经不见了。",
			&"demo.owner.flower.state.blooming": "就让它们继续开吧……水已经喝饱了。",
		},
		&"en": {
			&"opening.owner.toy.idle": "Welcome. Tonight's toys are all on the shelf, and their springs and wheels are behaving—for now.",
			&"opening.owner.fast_food.idle": "The fryer is hot. Tell me what you want before it gets cold.",
			&"opening.owner.flower.idle": "Shh... The flowers are asleep. Choose gently.",
			&"demo.owner.flower.reminder": "Look at my stem again... Those tiny white flowers are still there.",
			&"demo.owner.flower.state.trimmed": "I feel lighter... Those tiny white flowers are gone.",
			&"demo.owner.flower.state.blooming": "Let them keep blooming... They have had plenty to drink.",
		},
	}
	for locale in expected_dialogue:
		TranslationServer.set_locale(locale)
		for key in expected_dialogue[locale]:
			assert_eq(
				TranslationServer.translate(key),
				expected_dialogue[locale][key],
				"%s should be direct dialogue in %s" % [key, locale],
			)
