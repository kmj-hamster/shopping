class_name SlotDemoCatalog
extends RefCounted

const STORE_BOOK := &"book"
const STORE_TOY := &"toy"
const STORE_FLOWER := &"flower"
const STORE_RECORD := &"record"
const STORE_FAST_FOOD := &"fast_food"
const STORE_RECYCLING := &"recycling"

const OWNER_BALLOON := &"balloon"
const OWNER_SUNFLOWER := &"sunflower"
const OWNER_GRAMOPHONE := &"gramophone"
const OWNER_MAGICAL_GIRL := &"magical_girl"
const OWNER_MOUSE := &"mouse"

const STORE_IDS: Array[StringName] = [
	STORE_BOOK,
	STORE_TOY,
	STORE_FLOWER,
	STORE_RECORD,
	STORE_FAST_FOOD,
]

const MAP_STORE_IDS: Array[StringName] = [
	STORE_BOOK,
	STORE_TOY,
	STORE_FLOWER,
	STORE_RECORD,
	STORE_FAST_FOOD,
	STORE_RECYCLING,
]

const STORE_OWNER_IDS := {
	STORE_BOOK: OWNER_MAGICAL_GIRL,
	STORE_TOY: OWNER_BALLOON,
	STORE_FLOWER: OWNER_SUNFLOWER,
	STORE_RECORD: OWNER_GRAMOPHONE,
	STORE_FAST_FOOD: OWNER_MOUSE,
}

const RETAIL_ITEM_PATHS := [
	"res://data/slot_demo/items/book_bedtime_clipping.tres",
	"res://data/slot_demo/items/book_aquarium_issue.tres",
	"res://data/slot_demo/items/record_lullaby_cassette.tres",
	"res://data/slot_demo/items/record_fluorescent_single.tres",
	"res://data/slot_demo/items/flower_sunflower.tres",
	"res://data/slot_demo/items/flower_lavender_sachet.tres",
	"res://data/slot_demo/items/flower_night_jasmine.tres",
	"res://data/slot_demo/items/toy_cloth_scraps.tres",
	"res://data/slot_demo/items/toy_glass_marble.tres",
	"res://data/slot_demo/items/toy_windup_moth.tres",
	"res://data/slot_demo/items/fast_warm_milk.tres",
	"res://data/slot_demo/items/fast_hash_brown.tres",
]

const CRAFTED_ITEM_PATHS := [
	"res://data/slot_demo/items/craft_childhood_teddy.tres",
	"res://data/slot_demo/items/craft_comfort_bear.tres",
	"res://data/slot_demo/items/craft_clear_receiver.tres",
	"res://data/slot_demo/items/craft_tide_receiver.tres",
]

const WISH_PATHS := [
	"res://data/slot_demo/wishes/wish_hungry.tres",
	"res://data/slot_demo/wishes/wish_bedside.tres",
	"res://data/slot_demo/wishes/wish_stay_awake.tres",
	"res://data/slot_demo/wishes/wish_remember.tres",
	"res://data/slot_demo/wishes/wish_settle_down.tres",
	"res://data/slot_demo/wishes/wish_rain_close.tres",
]

const RECIPE_PATHS := [
	"res://data/slot_demo/recipes/recipe_teddy.tres",
	"res://data/slot_demo/recipes/recipe_night_radio.tres",
]

const OWNER_PATHS := [
	"res://data/slot_demo/owners/owner_balloon.tres",
]

const REQUEST_PATHS := [
	"res://data/slot_demo/requests/request_balloon_hug.tres",
]

const INITIAL_SHELF_ITEMS := {
	STORE_BOOK: [
		&"book_bedtime_clipping", &"book_bedtime_clipping",
		&"book_bedtime_clipping", &"book_bedtime_clipping",
		&"book_aquarium_issue", &"book_aquarium_issue",
	],
	STORE_RECORD: [
		&"record_fluorescent_single", &"record_fluorescent_single",
		&"record_fluorescent_single", &"record_fluorescent_single",
		&"record_lullaby_cassette", &"record_lullaby_cassette",
	],
	STORE_FLOWER: [
		&"flower_sunflower", &"flower_sunflower", &"flower_sunflower",
		&"flower_night_jasmine", &"flower_night_jasmine",
		&"flower_lavender_sachet",
	],
	STORE_TOY: [
		&"toy_cloth_scraps", &"toy_cloth_scraps",
		&"toy_cloth_scraps", &"toy_cloth_scraps",
		&"toy_glass_marble", &"toy_glass_marble",
	],
	STORE_FAST_FOOD: [
		&"fast_hash_brown", &"fast_hash_brown",
		&"fast_hash_brown", &"fast_hash_brown",
		&"fast_warm_milk", &"fast_warm_milk",
	],
}


static func retail_items() -> Array[CardItemDefinition]:
	var result: Array[CardItemDefinition] = []
	for path in RETAIL_ITEM_PATHS:
		var resource := load(path) as CardItemDefinition
		assert(resource != null, "Missing card item resource: %s" % path)
		result.append(resource)
	return result


static func crafted_items() -> Array[CardItemDefinition]:
	var result: Array[CardItemDefinition] = []
	for path in CRAFTED_ITEM_PATHS:
		var resource := load(path) as CardItemDefinition
		assert(resource != null, "Missing crafted item resource: %s" % path)
		result.append(resource)
	return result


static func all_items() -> Array[CardItemDefinition]:
	var result := retail_items()
	result.append_array(crafted_items())
	return result


static func item_by_id(item_id: StringName) -> CardItemDefinition:
	for item in all_items():
		if item.id == item_id:
			return item
	return null


static func retail_items_for_store(store_id: StringName) -> Array[CardItemDefinition]:
	var result: Array[CardItemDefinition] = []
	for item in retail_items():
		if item.store_id == store_id:
			result.append(item)
	return result


static func initial_shelf_item_ids(store_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id in INITIAL_SHELF_ITEMS.get(store_id, []):
		result.append(StringName(item_id))
	return result


static func store_name_key(store_id: StringName) -> StringName:
	return StringName("store.%s" % store_id)


static func wishes() -> Array[DailyWishDefinition]:
	var result: Array[DailyWishDefinition] = []
	for path in WISH_PATHS:
		var resource := load(path) as DailyWishDefinition
		assert(resource != null, "Missing daily wish resource: %s" % path)
		result.append(resource)
	return result


static func wish_by_id(wish_id: StringName) -> DailyWishDefinition:
	for wish in wishes():
		if wish.id == wish_id:
			return wish
	return null


static func recipes() -> Array[SynthesisRecipeDefinition]:
	var result: Array[SynthesisRecipeDefinition] = []
	for path in RECIPE_PATHS:
		var resource := load(path) as SynthesisRecipeDefinition
		assert(resource != null, "Missing recipe resource: %s" % path)
		result.append(resource)
	return result


static func recipe_by_id(recipe_id: StringName) -> SynthesisRecipeDefinition:
	for recipe in recipes():
		if recipe.id == recipe_id:
			return recipe
	return null


static func owners() -> Array[OwnerRelationshipDefinition]:
	var result: Array[OwnerRelationshipDefinition] = []
	for path in OWNER_PATHS:
		var resource := load(path) as OwnerRelationshipDefinition
		assert(resource != null, "Missing owner relationship resource: %s" % path)
		result.append(resource)
	return result


static func owner_by_id(owner_id: StringName) -> OwnerRelationshipDefinition:
	for owner in owners():
		if owner.id == owner_id:
			return owner
	return null


static func owner_id_for_store(store_id: StringName) -> StringName:
	return StringName(STORE_OWNER_IDS.get(store_id, &""))


static func owner_name_key(owner_id: StringName) -> StringName:
	var definition := owner_by_id(owner_id)
	return (
		definition.display_name_key
		if definition != null
		else StringName("slot.owner.%s.name" % owner_id)
	)


static func requests() -> Array[OwnerRequestDefinition]:
	var result: Array[OwnerRequestDefinition] = []
	for path in REQUEST_PATHS:
		var resource := load(path) as OwnerRequestDefinition
		assert(resource != null, "Missing owner request resource: %s" % path)
		result.append(resource)
	return result


static func request_by_id(request_id: StringName) -> OwnerRequestDefinition:
	for request in requests():
		if request.id == request_id:
			return request
	return null
