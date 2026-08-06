class_name GameContentManifest
extends Resource

@export_range(0, 20, 1) var initial_money := 10
@export_range(1, 20, 1) var maximum_item_price := 20
@export_range(1, 8, 1) var maximum_properties_per_item := 4
@export_range(1, 4, 1) var maximum_aspects_per_item := 2
@export var properties: Array[Resource] = []
@export var items: Array[Resource] = []
@export var tasks: Array[Resource] = []
@export var recipes: Array[Resource] = []
@export var stores: Array[Resource] = []
@export var store_unlocks: Array[Resource] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var properties_by_id := _resources_by_id(properties, "property", errors)
	var items_by_id := _resources_by_id(items, "item", errors)
	_resources_by_id(tasks, "task", errors)
	_resources_by_id(recipes, "recipe", errors)
	var stores_by_id := _resources_by_id(stores, "store", errors)
	var unlocks_by_id := _resources_by_id(store_unlocks, "store unlock", errors)
	_validate_resources(properties, errors)
	_validate_resources(items, errors)
	_validate_resources(tasks, errors)
	_validate_resources(recipes, errors)
	_validate_resources(stores, errors)
	_validate_resources(store_unlocks, errors)
	for raw_item in items:
		var item := raw_item as QuestItemDefinition
		if item == null:
			errors.append("Manifest contains a non-quest item resource.")
			continue
		_validate_item_properties(item, properties_by_id, errors)
		if item.base_price > maximum_item_price:
			errors.append("Item %s exceeds manifest price limit." % item.id)
		if item.property_set.property_count() > maximum_properties_per_item:
			errors.append("Item %s exceeds manifest property limit." % item.id)
		if item.property_set.present_aspects().size() > maximum_aspects_per_item:
			errors.append("Item %s exceeds manifest aspect limit." % item.id)
	for raw_task in tasks:
		var task := raw_task as TaskDefinition
		if task != null:
			_validate_slot_rules(task.slot_rules, properties_by_id, items_by_id, errors)
	for raw_recipe in recipes:
		var recipe := raw_recipe as SynthesisRecipeDefinition
		if recipe != null:
			_validate_slot_rules(recipe.slot_rules, properties_by_id, items_by_id, errors)
	for raw_unlock in store_unlocks:
		var unlock := raw_unlock as StoreUnlockDefinition
		if unlock == null:
			continue
		if not stores_by_id.has(unlock.store_id):
			errors.append("Store unlock %s references missing store %s." % [unlock.id, unlock.store_id])
		_validate_slot_rules([unlock.slot_rule], properties_by_id, items_by_id, errors)
	for raw_store in stores:
		var store := raw_store as StoreDefinition
		if store == null:
			continue
		if not store.unlock_definition_id.is_empty() and not unlocks_by_id.has(store.unlock_definition_id):
			errors.append("Store %s references missing unlock %s." % [store.id, store.unlock_definition_id])
		for item_id in store.initial_shelf_item_ids:
			var item := items_by_id.get(item_id) as QuestItemDefinition
			if item == null or item.store_id != store.id:
				errors.append("Store %s has invalid initial item %s." % [store.id, item_id])
	return errors


func _validate_item_properties(
	item: QuestItemDefinition,
	properties_by_id: Dictionary,
	errors: PackedStringArray,
) -> void:
	if item.property_set == null:
		return
	for tag in item.property_set.tags:
		var definition := properties_by_id.get(tag) as PropertyDefinition
		if definition == null:
			errors.append("Item %s uses unknown tag %s." % [item.id, tag])
		elif definition.value_kind != PropertyDefinition.ValueKind.TAG:
			errors.append("Item %s stores scaled property %s as a tag." % [item.id, tag])
	for raw_tag in item.property_set.values:
		var tag := StringName(raw_tag)
		var definition := properties_by_id.get(tag) as PropertyDefinition
		if definition == null:
			errors.append("Item %s uses unknown scaled property %s." % [item.id, tag])
		elif definition.value_kind != PropertyDefinition.ValueKind.SCALED:
			errors.append("Item %s assigns a number to tag property %s." % [item.id, tag])


func _validate_slot_rules(
	raw_rules: Array,
	properties_by_id: Dictionary,
	items_by_id: Dictionary,
	errors: PackedStringArray,
) -> void:
	for raw_rule in raw_rules:
		var rule := raw_rule as CardSlotRule
		if rule == null:
			continue
		for property_id in rule.required_all + rule.allowed_any + rule.forbidden_any:
			if not properties_by_id.has(property_id):
				errors.append("Slot %s references unknown property %s." % [rule.id, property_id])
		for item_id in rule.accepted_item_ids:
			if not items_by_id.has(item_id):
				errors.append("Slot %s accepts unknown item %s." % [rule.id, item_id])
		for raw_requirement in rule.value_requirements:
			var requirement := raw_requirement as SlotValueRequirement
			if requirement == null:
				continue
			for property_id in requirement.tags:
				var definition := properties_by_id.get(property_id) as PropertyDefinition
				if definition == null:
					errors.append("Slot %s requires unknown value %s." % [rule.id, property_id])
				elif definition.value_kind != PropertyDefinition.ValueKind.SCALED:
					errors.append("Slot %s cannot assign a numeric threshold to tag %s." % [rule.id, property_id])


func _validate_resources(raw_resources: Array, errors: PackedStringArray) -> void:
	for resource in raw_resources:
		if resource != null and resource.has_method("validation_errors"):
			errors.append_array(resource.validation_errors())


func _resources_by_id(
	raw_resources: Array,
	kind: String,
	errors: PackedStringArray,
) -> Dictionary:
	var result: Dictionary = {}
	for resource in raw_resources:
		if resource == null:
			errors.append("Manifest contains a null %s resource." % kind)
			continue
		var resource_id: StringName = resource.get("id")
		if resource_id.is_empty():
			continue
		if result.has(resource_id):
			errors.append("Duplicate %s id: %s." % [kind, resource_id])
		else:
			result[resource_id] = resource
	return result
