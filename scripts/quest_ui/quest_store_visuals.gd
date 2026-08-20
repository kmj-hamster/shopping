class_name QuestStoreVisuals
extends RefCounted

const OWNER_TEXTURE_PATHS := {
	&"toy": "res://resources/character/balloon-head.png",
	&"fast_food": "res://resources/character/rat-head.png",
	&"flower": "res://resources/character/flower-head.png",
	&"record": "res://resources/character/phonograph-head.png",
	&"bookstore": "res://resources/character/manga-head.png",
}
const BACKGROUND_TEXTURE_PATHS := {
	&"toy": "res://resources/background/toystore.png",
	&"fast_food": "res://resources/background/food.png",
	&"flower": "res://resources/background/flowerstore.png",
	&"record": "res://resources/background/musicstore.png",
	&"bookstore": "res://resources/background/bookstore.png",
}


static func owner_texture(store_id: StringName) -> Texture2D:
	return _texture(OWNER_TEXTURE_PATHS, store_id)


static func background_texture(store_id: StringName) -> Texture2D:
	return _texture(BACKGROUND_TEXTURE_PATHS, store_id)


static func _texture(paths: Dictionary, store_id: StringName) -> Texture2D:
	var path := String(paths.get(store_id, ""))
	return load(path) as Texture2D if not path.is_empty() else null
