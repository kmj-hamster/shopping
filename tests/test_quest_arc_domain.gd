extends GutTest


func test_tag_properties_have_presence_without_fake_numeric_strength() -> void:
	var properties := CardPropertySet.new()
	properties.tags = [&"food", &"drink"]
	properties.values = {&"relaxing": 3, &"homecomer": 4}
	assert_true(properties.has(&"food"))
	assert_eq(properties.value(&"food"), 0)
	assert_eq(properties.value(&"relaxing"), 3)
	assert_eq(properties.property_count(), 4)
	assert_true(properties.validation_errors().is_empty())


func test_quest_item_rejects_more_than_four_properties_or_two_aspects() -> void:
	var too_many := _item(&"too_many", [&"food", &"drink"], {
		&"soft": 2, &"nightwalker": 1, &"mourner": 1,
	})
	assert_true(_contains(too_many.validation_errors(), "more than four"))

	var too_many_aspects := _item(&"too_many_aspects", [&"food"], {
		&"nightwalker": 1, &"mourner": 1, &"dreamwalker": 1,
	})
	assert_true(_contains(too_many_aspects.validation_errors(), "more than two"))


func test_tag_presence_and_scaled_threshold_are_evaluated_separately() -> void:
	var item := _item(&"warm_milk", [&"food", &"drink"], {
		&"relaxing": 3, &"homecomer": 4,
	})
	var requirement := SlotValueRequirement.new()
	requirement.tags = [&"relaxing"]
	requirement.minimum = 4
	var rule := CardSlotRule.new()
	rule.id = &"hunger"
	rule.required_all = [&"food"]
	rule.value_requirements = [requirement]
	var result := CardRuleEvaluator.evaluate(rule, item)
	assert_true(result.can_place)
	assert_false(result.value_satisfied)
	assert_false(result.can_execute)
	assert_true(CardRuleEvaluator.can_place(rule, item))
	assert_false(CardRuleEvaluator.can_execute(rule, item))
	requirement.minimum = 3
	assert_true(CardRuleEvaluator.can_execute(rule, item))
	assert_eq(
		CardRuleEvaluator.can_execute(rule, item),
		bool(CardRuleEvaluator.evaluate(rule, item).can_execute),
	)


func test_exact_item_rule_is_suitable_for_map_unlocks() -> void:
	var rule := CardSlotRule.new()
	rule.id = &"record_door"
	rule.accepted_item_ids = [&"windup_moth"]
	var unlock := StoreUnlockDefinition.new()
	unlock.id = &"unlock_record"
	unlock.store_id = &"record"
	unlock.prompt_text_key = &"unlock.record.prompt"
	unlock.result_text_key = &"unlock.record.result"
	unlock.slot_rule = rule
	assert_true(QuestArcRules.store_unlock_accepts(unlock, _item(&"windup_moth")))
	assert_false(QuestArcRules.store_unlock_accepts(unlock, _item(&"jasmine")))


func test_task_outcome_uses_dominant_persona_and_declared_tie_priority() -> void:
	var gauze_condition := StoryCondition.new()
	gauze_condition.kind = StoryCondition.Kind.DOMINANT_PERSONA
	gauze_condition.key = &"dreamwalker"
	var gauze_outcome := _outcome(&"tide", false, [gauze_condition])
	var fallback := _outcome(&"plain", true)
	var task := TaskDefinition.new()
	task.id = &"radio_order"
	task.display_name_key = &"task.radio.name"
	task.body_text_key = &"task.radio.body"
	task.slot_rules = [_simple_rule(&"sound")]
	task.outcomes = [gauze_outcome, fallback]
	task.persona_tie_priority = [&"dreamwalker", &"mourner", &"homecomer", &"nightwalker"]
	var tied_item := _item(&"rain_tape", [&"music"], {&"dreamwalker": 3, &"homecomer": 3})
	assert_eq(QuestArcRules.outcome_for(task, [tied_item]).id, &"tide")


func test_manifest_rejects_numeric_threshold_for_tag_property() -> void:
	var food_property := _property(&"food", PropertyDefinition.ValueKind.TAG)
	var relaxing_property := _property(&"relaxing", PropertyDefinition.ValueKind.SCALED)
	var requirement := SlotValueRequirement.new()
	requirement.tags = [&"food"]
	requirement.minimum = 2
	var rule := _simple_rule(&"meal")
	rule.required_all = [&"food"]
	rule.value_requirements = [requirement]
	var task := TaskDefinition.new()
	task.id = &"meal"
	task.display_name_key = &"task.meal.name"
	task.body_text_key = &"task.meal.body"
	task.slot_rules = [rule]
	task.outcomes = [_outcome(&"plain", true)]
	var item := _item(&"meal_item", [&"food"], {&"relaxing": 2})
	var manifest := GameContentManifest.new()
	manifest.properties = [food_property, relaxing_property]
	manifest.items = [item]
	manifest.tasks = [task]
	assert_true(_contains(manifest.validation_errors(), "numeric threshold to tag food"))


func _property(id: StringName, kind: PropertyDefinition.ValueKind) -> PropertyDefinition:
	var result := PropertyDefinition.new()
	result.id = id
	result.display_name_key = StringName("property.%s.name" % id)
	result.description_key = StringName("property.%s.description" % id)
	result.value_kind = kind
	return result


func _item(
	id: StringName,
	tags: Array[StringName] = [],
	values: Dictionary = {},
) -> QuestItemDefinition:
	var result := QuestItemDefinition.new()
	result.id = id
	result.display_name_key = StringName("item.%s.name" % id)
	result.description_key = StringName("item.%s.description" % id)
	result.store_id = &"test_store"
	result.base_price = 2
	result.restock_weight = 1
	result.property_set = CardPropertySet.new()
	result.property_set.tags = tags
	result.property_set.values = values
	return result


func _simple_rule(id: StringName) -> CardSlotRule:
	var result := CardSlotRule.new()
	result.id = id
	return result


func _outcome(
	id: StringName,
	is_fallback: bool,
	conditions: Array[Resource] = [],
) -> TaskOutcomeDefinition:
	var result := TaskOutcomeDefinition.new()
	result.id = id
	result.result_text_key = StringName("outcome.%s" % id)
	result.is_fallback = is_fallback
	result.conditions = conditions
	return result


func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false
