class_name QuestArcCatalog
extends RefCounted

const MANIFEST_PATH := "res://data/quest_arc/content_manifest.tres"
const LEGACY_MANIFEST_PATH := "res://data/quest_arc/legacy_content_manifest.tres"
const LEGACY_DEMO_ARGUMENT := "--legacy-demo"

static var _cached_manifest: GameContentManifest
static var _indexed_manifest_instance_id := 0
static var _items_by_id: Dictionary = {}
static var _tasks_by_id: Dictionary = {}
static var _stores_by_id: Dictionary = {}
static var _owners_by_id: Dictionary = {}
static var _recipes_by_id: Dictionary = {}
static var _properties_by_id: Dictionary = {}
static var _store_unlocks_by_id: Dictionary = {}
static var _manifest_path_override := ""


static func manifest() -> GameContentManifest:
	if _cached_manifest == null:
		_cached_manifest = load(_selected_manifest_path()) as GameContentManifest
	return _cached_manifest


static func using_legacy_demo() -> bool:
	return LEGACY_DEMO_ARGUMENT in OS.get_cmdline_args() or LEGACY_DEMO_ARGUMENT in OS.get_cmdline_user_args()


static func _selected_manifest_path() -> String:
	if not _manifest_path_override.is_empty():
		return _manifest_path_override
	return LEGACY_MANIFEST_PATH if using_legacy_demo() else MANIFEST_PATH


static func use_manifest_for_tests(path: String) -> bool:
	if not _is_gut_process() or path not in [MANIFEST_PATH, LEGACY_MANIFEST_PATH]:
		return false
	_manifest_path_override = path
	_clear_cache()
	return true


static func clear_manifest_test_override() -> void:
	if not _is_gut_process():
		return
	_manifest_path_override = ""
	_clear_cache()


static func _clear_cache() -> void:
	_cached_manifest = null
	_indexed_manifest_instance_id = 0
	_items_by_id.clear()
	_tasks_by_id.clear()
	_stores_by_id.clear()
	_owners_by_id.clear()
	_recipes_by_id.clear()
	_properties_by_id.clear()
	_store_unlocks_by_id.clear()


static func _is_gut_process() -> bool:
	for argument in OS.get_cmdline_args():
		if "gut" in argument.to_lower():
			return true
	return false


static func item_by_id(item_id: StringName) -> QuestItemDefinition:
	_ensure_indexes()
	return _items_by_id.get(item_id) as QuestItemDefinition


static func task_by_id(task_id: StringName) -> TaskDefinition:
	_ensure_indexes()
	return _tasks_by_id.get(task_id) as TaskDefinition


static func store_by_id(store_id: StringName) -> StoreDefinition:
	_ensure_indexes()
	return _stores_by_id.get(store_id) as StoreDefinition


static func owner_by_id(owner_id: StringName) -> OwnerDefinition:
	_ensure_indexes()
	return _owners_by_id.get(owner_id) as OwnerDefinition


static func owner_for_store(store_id: StringName) -> OwnerDefinition:
	var store := store_by_id(store_id)
	return owner_by_id(store.owner_id) if store != null and not store.owner_id.is_empty() else null


static func recipe_by_id(recipe_id: StringName) -> SynthesisRecipeDefinition:
	_ensure_indexes()
	return _recipes_by_id.get(recipe_id) as SynthesisRecipeDefinition


static func property_by_id(property_id: StringName) -> PropertyDefinition:
	_ensure_indexes()
	return _properties_by_id.get(property_id) as PropertyDefinition


static func store_unlock_by_id(unlock_id: StringName) -> StoreUnlockDefinition:
	_ensure_indexes()
	return _store_unlocks_by_id.get(unlock_id) as StoreUnlockDefinition


static func store_unlock_for_store(store_id: StringName) -> StoreUnlockDefinition:
	var store := store_by_id(store_id)
	return (
		store_unlock_by_id(store.unlock_definition_id)
		if store != null and not store.unlock_definition_id.is_empty()
		else null
	)


static func _ensure_indexes() -> void:
	var content := manifest()
	if content == null:
		return
	var instance_id := content.get_instance_id()
	if _indexed_manifest_instance_id == instance_id:
		return
	_indexed_manifest_instance_id = instance_id
	_items_by_id.clear()
	_tasks_by_id.clear()
	_stores_by_id.clear()
	_owners_by_id.clear()
	_recipes_by_id.clear()
	_properties_by_id.clear()
	_store_unlocks_by_id.clear()
	_index_resources(content.items, _items_by_id)
	_index_resources(content.tasks, _tasks_by_id)
	_index_resources(content.stores, _stores_by_id)
	_index_resources(content.owners, _owners_by_id)
	_index_resources(content.recipes, _recipes_by_id)
	_index_resources(content.properties, _properties_by_id)
	_index_resources(content.store_unlocks, _store_unlocks_by_id)


static func _index_resources(resources: Array, target: Dictionary) -> void:
	for raw_resource in resources:
		var definition := raw_resource as Resource
		if definition != null:
			target[StringName(definition.get("id"))] = definition
