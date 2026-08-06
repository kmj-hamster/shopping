class_name QuestArcCatalog
extends RefCounted

const MANIFEST_PATH := "res://data/quest_arc/content_manifest.tres"


static func manifest() -> GameContentManifest:
	return load(MANIFEST_PATH) as GameContentManifest


static func item_by_id(item_id: StringName) -> QuestItemDefinition:
	var content := manifest()
	if content == null:
		return null
	for raw_item in content.items:
		var item := raw_item as QuestItemDefinition
		if item != null and item.id == item_id:
			return item
	return null


static func task_by_id(task_id: StringName) -> TaskDefinition:
	var content := manifest()
	if content == null:
		return null
	for raw_task in content.tasks:
		var task := raw_task as TaskDefinition
		if task != null and task.id == task_id:
			return task
	return null


static func store_by_id(store_id: StringName) -> StoreDefinition:
	var content := manifest()
	if content == null:
		return null
	for raw_store in content.stores:
		var store := raw_store as StoreDefinition
		if store != null and store.id == store_id:
			return store
	return null


static func store_unlock_by_id(unlock_id: StringName) -> StoreUnlockDefinition:
	var content := manifest()
	if content == null:
		return null
	for raw_unlock in content.store_unlocks:
		var unlock := raw_unlock as StoreUnlockDefinition
		if unlock != null and unlock.id == unlock_id:
			return unlock
	return null
