class_name GameContentManifest
extends Resource

@export_range(0, 20, 1) var initial_money := 0
@export_range(1, 999, 1) var maximum_item_price := 20
@export_range(1, 8, 1) var maximum_properties_per_item := 4
@export_range(1, 4, 1) var maximum_shapes_per_item := 2
@export var initial_shape_levels: Dictionary = {}
@export var starting_item_ids: Array[StringName] = []
@export var properties: Array[Resource] = []
@export var items: Array[Resource] = []
@export var tasks: Array[Resource] = []
@export var recipes: Array[Resource] = []
@export var stores: Array[Resource] = []
@export var store_unlocks: Array[Resource] = []
@export var owners: Array[Resource] = []
@export var expedition_rooms: Array[Resource] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var properties_by_id := _resources_by_id(properties, "property", errors)
	var items_by_id := _resources_by_id(items, "item", errors)
	var tasks_by_id := _resources_by_id(tasks, "task", errors)
	var recipes_by_id := _resources_by_id(recipes, "recipe", errors)
	var stores_by_id := _resources_by_id(stores, "store", errors)
	var unlocks_by_id := _resources_by_id(store_unlocks, "store unlock", errors)
	_resources_by_id(expedition_rooms, "mall room", errors)
	for item_id in starting_item_ids:
		if not items_by_id.has(item_id):
			errors.append("Starting inventory references missing item %s." % item_id)
	for stat_id in CardPropertySet.SHAPES:
		var amount := int(initial_shape_levels.get(stat_id, 0))
		if amount < 0 or amount > 20:
			errors.append("Initial protagonist stat %s must be between 0 and 20." % stat_id)
	var owners_by_id := _resources_by_id(owners, "owner", errors)
	_validate_resources(properties, errors)
	_validate_resources(items, errors)
	_validate_resources(tasks, errors)
	_validate_resources(recipes, errors)
	_validate_resources(stores, errors)
	_validate_resources(store_unlocks, errors)
	_validate_resources(owners, errors)
	_validate_resources(expedition_rooms, errors)
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
		var shape_limit := (
			CardPropertySet.SHAPES.size()
			if item.allows_all_shapes
			else maximum_shapes_per_item
		)
		if item.property_set.present_shapes().size() > shape_limit:
			errors.append("Item %s exceeds manifest shape limit." % item.id)
	for raw_task in tasks:
		var task := raw_task as TaskDefinition
		if task != null:
			_validate_slot_rules(task.slot_rules, properties_by_id, items_by_id, errors)
			if (
				task.category == TaskDefinition.Category.GIFT
				and not task.gift_item_id.is_empty()
				and not items_by_id.has(task.gift_item_id)
			):
					errors.append(
						"Gift task %s references missing item %s." % [task.id, task.gift_item_id]
					)
			if not task.activation_store_id.is_empty() and not stores_by_id.has(task.activation_store_id):
				errors.append(
					"Task %s references missing activation store %s."
					% [task.id, task.activation_store_id]
				)
	for raw_recipe in recipes:
		var recipe := raw_recipe as SynthesisRecipeDefinition
		if recipe != null:
			_validate_slot_rules([recipe.base_rule], properties_by_id, items_by_id, errors)
			if not recipe.output_id.is_empty() and not items_by_id.has(recipe.output_id):
				errors.append("Recipe %s references missing output %s." % [recipe.id, recipe.output_id])
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
		if not store.owner_id.is_empty() and not owners_by_id.has(store.owner_id):
			errors.append("Store %s references missing owner %s." % [store.id, store.owner_id])
		for prerequisite_store_id in store.visible_after_store_ids:
			if not stores_by_id.has(prerequisite_store_id):
				errors.append(
					"Store %s references missing visibility prerequisite %s."
					% [store.id, prerequisite_store_id]
				)
		for item_id in store.initial_shelf_item_ids:
			var item := items_by_id.get(item_id) as QuestItemDefinition
			if item == null or item.store_id != store.id:
				errors.append("Store %s has invalid initial item %s." % [store.id, item_id])
		for item_id in store.unlockable_shelf_item_ids:
			var item := items_by_id.get(item_id) as QuestItemDefinition
			if item == null or item.store_id != store.id:
				errors.append("Store %s has invalid unlockable item %s." % [store.id, item_id])
	for raw_owner in owners:
		var owner := raw_owner as OwnerDefinition
		if owner == null:
			errors.append("Manifest contains a non-owner resource.")
			continue
		var owner_store := stores_by_id.get(owner.store_id) as StoreDefinition
		if owner_store == null or owner_store.owner_id != owner.id:
			errors.append("Owner %s is not assigned to store %s." % [owner.id, owner.store_id])
		if not owner.request_task_id.is_empty():
			if not tasks_by_id.has(owner.request_task_id):
				errors.append("Owner %s references missing task %s." % [owner.id, owner.request_task_id])
			if (
				not owner.request_recipe_id.is_empty()
				and not recipes_by_id.has(owner.request_recipe_id)
			):
				errors.append("Owner %s references missing recipe %s." % [owner.id, owner.request_recipe_id])
			if not owner.event_item_id.is_empty():
				var event_item := items_by_id.get(owner.event_item_id) as QuestItemDefinition
				if event_item == null or event_item.store_id != owner.event_item_store_id:
					errors.append("Owner %s references invalid event item %s." % [owner.id, owner.event_item_id])
			if (
				not owner.request_required_room_id.is_empty()
				and not _resource_id_exists(expedition_rooms, owner.request_required_room_id)
			):
				errors.append(
					"Owner %s requires missing room %s."
					% [owner.id, owner.request_required_room_id]
				)
			if (
				not owner.request_required_purchased_item_id.is_empty()
				and not items_by_id.has(owner.request_required_purchased_item_id)
			):
				errors.append(
					"Owner %s requires missing purchase %s."
					% [owner.id, owner.request_required_purchased_item_id]
				)
	return errors


func _resource_id_exists(resources: Array[Resource], id: StringName) -> bool:
	return resources.any(func(resource: Resource) -> bool:
		return resource != null and resource.get("id") == id
	)


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
