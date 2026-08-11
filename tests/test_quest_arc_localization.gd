extends GutTest

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
	keys.append(&"quest.ui.hand.items")
	keys.append(&"quest.ui.hand.masks")
	keys.append(&"demo.ui.synthesis.drag_result")
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
