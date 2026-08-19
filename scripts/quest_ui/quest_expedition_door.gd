class_name QuestExpeditionDoor
extends VBoxContainer

signal chosen(room_id: StringName)

const TEXTURES := {
	&"unknown": [
		preload("res://resources/ui/expedition/doorclosed.png"),
		preload("res://resources/ui/expedition/dooropen.png"),
	],
	&"challenge": [
		preload("res://resources/ui/expedition/redclose.png"),
		preload("res://resources/ui/expedition/redopen.png"),
	],
	&"rest": [
		preload("res://resources/ui/expedition/blueclosed.png"),
		preload("res://resources/ui/expedition/blueopen.png"),
	],
	&"work": [
		preload("res://resources/ui/expedition/greyclosed.png"),
		preload("res://resources/ui/expedition/greyopen.png"),
	],
}

var state: QuestGameState
var room: MallRoomDefinition
var name_label: Label
var door_button: TextureButton


func setup(game_state: QuestGameState, definition: MallRoomDefinition) -> void:
	state = game_state
	room = definition
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(210, 390)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	name_label = Label.new()
	name_label.custom_minimum_size = Vector2(210, 34)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color("d9e4e0"))
	name_label.add_theme_color_override("font_outline_color", Color("051015"))
	name_label.add_theme_constant_override("outline_size", 4)
	add_child(name_label)
	door_button = TextureButton.new()
	door_button.custom_minimum_size = Vector2(205, 345)
	door_button.ignore_texture_size = true
	door_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	door_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	door_button.mouse_entered.connect(_on_hover_changed.bind(true))
	door_button.mouse_exited.connect(_on_hover_changed.bind(false))
	door_button.pressed.connect(_on_pressed)
	add_child(door_button)
	refresh()


func refresh() -> void:
	if name_label == null or door_button == null or room == null or state == null:
		return
	var visual_kind := _visual_kind()
	var textures := TEXTURES[visual_kind] as Array
	door_button.texture_normal = textures[0] as Texture2D
	door_button.texture_hover = textures[1] as Texture2D
	door_button.texture_pressed = textures[1] as Texture2D
	name_label.text = (
		TranslationServer.translate(room.display_name_key)
		if state.expedition.is_discovered(room.id) or room.category == MallRoomDefinition.Category.BOSS
		else TranslationServer.translate(&"expedition.ui.unknown")
	)
	name_label.visible = false


func _visual_kind() -> StringName:
	if room.category == MallRoomDefinition.Category.BOSS:
		return &"challenge"
	if not state.expedition.is_discovered(room.id):
		return &"unknown"
	match room.category:
		MallRoomDefinition.Category.CHALLENGE:
			return &"challenge"
		MallRoomDefinition.Category.REST:
			return &"rest"
		MallRoomDefinition.Category.WORK:
			return &"work"
	return &"unknown"


func _on_hover_changed(hovered: bool) -> void:
	if name_label != null:
		name_label.visible = hovered


func _on_pressed() -> void:
	if room != null:
		chosen.emit(room.id)
