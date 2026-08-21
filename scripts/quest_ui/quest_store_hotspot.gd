class_name QuestStoreHotspot
extends TextureButton

const HOTSPOT_SIZE := Vector2(66, 95)
const NAME_LABEL_WIDTH := 220.0
const LOCKED_MODULATE := Color(1.15, 1.15, 1.15, 1.18)
const CLOSED_TEXTURE: Texture2D = preload("res://resources/ui/map/store-door-closed.png")
const OPEN_TEXTURE: Texture2D = preload("res://resources/ui/map/store-door-open.png")
const LOCKED_TEXTURE: Texture2D = preload("res://resources/ui/map/store-door-locked.png")

var state: QuestGameState
var store_id: StringName
var name_label: Label


func _ready() -> void:
	custom_minimum_size = HOTSPOT_SIZE
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = ""
	name_label = QuestExpeditionDoor.make_name_label(NAME_LABEL_WIDTH)
	name_label.name = "StoreNameLabel"
	name_label.anchor_left = 0.5
	name_label.anchor_top = 0.0
	name_label.anchor_right = 0.5
	name_label.anchor_bottom = 0.0
	name_label.offset_left = -NAME_LABEL_WIDTH * 0.5
	name_label.offset_top = -38.0
	name_label.offset_right = NAME_LABEL_WIDTH * 0.5
	name_label.offset_bottom = -4.0
	name_label.z_index = 2
	name_label.visible = false
	add_child(name_label)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	refresh()


func refresh() -> void:
	if name_label == null or state == null or store_id.is_empty():
		return
	var store := QuestArcCatalog.store_by_id(store_id)
	name_label.text = (
		TranslationServer.translate(store.display_name_key) if store != null else ""
	)
	name_label.visible = false
	var unlocked := state.is_store_unlocked(store_id)
	self_modulate = Color.WHITE if unlocked else LOCKED_MODULATE
	texture_normal = CLOSED_TEXTURE if unlocked else LOCKED_TEXTURE
	texture_hover = OPEN_TEXTURE if unlocked else LOCKED_TEXTURE
	texture_pressed = OPEN_TEXTURE if unlocked else LOCKED_TEXTURE
	texture_focused = OPEN_TEXTURE if unlocked else LOCKED_TEXTURE


func _on_hover_changed(hovered: bool) -> void:
	if name_label != null:
		name_label.visible = hovered


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return false
