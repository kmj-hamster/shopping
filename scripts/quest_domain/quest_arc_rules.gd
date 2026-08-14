class_name QuestArcRules
extends RefCounted


static func dominant_persona(
	items: Array[CardItemDefinition],
	personas: Array[StringName],
	tie_priority: Array[StringName] = [],
) -> StringName:
	if personas.is_empty():
		return &""
	var totals: Dictionary = {}
	var highest := -1
	for persona_id in personas:
		totals[persona_id] = 0
	for item in items:
		if item == null:
			continue
		for persona_id in personas:
			totals[persona_id] = (
				int(totals[persona_id]) + item.property_value(persona_id)
			)
			highest = maxi(highest, int(totals[persona_id]))
	var tied: Array[StringName] = []
	for persona_id in personas:
		if int(totals[persona_id]) == highest:
			tied.append(persona_id)
	for persona_id in tie_priority:
		if persona_id in tied:
			return persona_id
	return tied[0] if not tied.is_empty() else &""


static func outcome_for(
	task: TaskDefinition,
	items: Array[CardItemDefinition],
	day: int = 1,
	story_flags: Dictionary = {},
	completed_tasks: Dictionary = {},
) -> TaskOutcomeDefinition:
	if task == null:
		return null
	var sorted_outcomes: Array[TaskOutcomeDefinition] = []
	var fallback: TaskOutcomeDefinition
	for raw_outcome in task.outcomes:
		var outcome := raw_outcome as TaskOutcomeDefinition
		if outcome == null:
			continue
		if outcome.is_fallback:
			fallback = outcome
		else:
			sorted_outcomes.append(outcome)
	sorted_outcomes.sort_custom(func(a: TaskOutcomeDefinition, b: TaskOutcomeDefinition) -> bool:
		return a.priority > b.priority
	)
	var context := {
		"items": items,
		"day": day,
		"story_flags": story_flags,
		"completed_tasks": completed_tasks,
		"dominant_persona": dominant_persona(
			items,
			task.persona_tie_priority,
			task.persona_tie_priority,
		),
	}
	for outcome in sorted_outcomes:
		if _conditions_match(outcome.conditions, context):
			return outcome
	return fallback


static func store_unlock_accepts(
	definition: StoreUnlockDefinition,
	item: CardItemDefinition,
) -> bool:
	return (
		definition != null
		and CardRuleEvaluator.can_execute(definition.slot_rule, item)
	)


static func _conditions_match(raw_conditions: Array[Resource], context: Dictionary) -> bool:
	for raw_condition in raw_conditions:
		var condition := raw_condition as StoryCondition
		if condition == null or not _condition_matches(condition, context):
			return false
	return true


static func _condition_matches(condition: StoryCondition, context: Dictionary) -> bool:
	var items: Array[CardItemDefinition] = context.items
	match condition.kind:
		StoryCondition.Kind.ALWAYS:
			return true
		StoryCondition.Kind.DAY_AT_LEAST:
			return int(context.day) >= condition.minimum
		StoryCondition.Kind.FLAG_EQUALS:
			return StringName(context.story_flags.get(condition.key, &"")) == condition.text_value
		StoryCondition.Kind.TASK_COMPLETED:
			return context.completed_tasks.has(condition.key)
		StoryCondition.Kind.ITEM_ID_IN:
			return items.any(func(item: CardItemDefinition) -> bool:
				return item != null and item.id in condition.item_ids
			)
		StoryCondition.Kind.ITEM_HAS_PROPERTY:
			return items.any(func(item: CardItemDefinition) -> bool:
				return item != null and item.has_property(condition.key)
			)
		StoryCondition.Kind.DOMINANT_PERSONA:
			return StringName(context.dominant_persona) == condition.key
	return false
