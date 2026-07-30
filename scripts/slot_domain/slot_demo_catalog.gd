class_name SlotDemoCatalog
extends RefCounted

const STORE_BOOK := &"book"
const STORE_TOY := &"toy"
const STORE_FLOWER := &"flower"
const STORE_RECORD := &"record"
const STORE_FAST_FOOD := &"fast_food"

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
