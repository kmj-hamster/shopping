class_name QuestArcRules
extends RefCounted


static func dominant_aspect(
	items: Array[CardItemDefinition],
	aspects: Array[StringName],
	tie_priority: Array[StringName] = [],
) -> StringName:
	if aspects.is_empty():
		return &""
	var totals: Dictionary = {}
	var highest := -1
	for aspect in aspects:
		totals[aspect] = 0
	for item in items:
		if item == null:
			continue
		for aspect in aspects:
			totals[aspect] = int(totals[aspect]) + item.property_value(aspect)
			highest = maxi(highest, int(totals[aspect]))
	var tied: Array[StringName] = []
	for aspect in aspects:
		if int(totals[aspect]) == highest:
			tied.append(aspect)
	for aspect in tie_priority:
		if aspect in tied:
			return aspect
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
		"dominant_aspect": dominant_aspect(items, task.tie_priority, task.tie_priority),
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
		and CardRuleEvaluator.evaluate(definition.slot_rule, item).can_execute
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
		StoryCondition.Kind.DOMINANT_ASPECT:
			return StringName(context.dominant_aspect) == condition.key
	return false
