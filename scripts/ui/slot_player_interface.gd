class_name SlotPlayerInterface
extends CanvasLayer

signal slot_rule_focused(rule: CardSlotRule)

var commerce: SlotCommerceState
var view_context := &"map"
var root: Control
var hand_bar: CardHandBar
var bag_button: TextureButton
var task_window: SlotTaskWindow


func setup(commerce_state: SlotCommerceState) -> void:
	commerce = commerce_state
	if is_node_ready():
		hand_bar.setup(commerce, commerce.activity_state)
		task_window.setup(commerce)


func _ready() -> void:
	layer = 20
	if commerce == null:
		commerce = GameState.slot_commerce
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	hand_bar.setup(commerce, commerce.activity_state)
	task_window.setup(commerce)
	_refresh_locale()


func _build_interface() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hand_bar = CardHandBar.new()
	hand_bar.name = "GlobalCardHand"
	hand_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_bar.offset_left = 14
	hand_bar.offset_top = -146
	hand_bar.offset_right = -182
	hand_bar.offset_bottom = -10
	root.add_child(hand_bar)
	task_window = SlotTaskWindow.new()
	task_window.name = "TaskWindow"
	task_window.visible = false
	task_window.close_requested.connect(close_task_window)
	task_window.slot_rule_focused.connect(_on_slot_rule_focused)
	root.add_child(task_window)
	bag_button = TextureButton.new()
	bag_button.name = "ProtagonistBagButton"
	bag_button.texture_normal = load("res://pic/bag.png") as Texture2D
	bag_button.texture_hover = load("res://pic/bag-light.png") as Texture2D
	bag_button.ignore_texture_size = true
	bag_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bag_button.offset_left = -176
	bag_button.offset_top = -172
	bag_button.offset_right = -4
	bag_button.offset_bottom = 0
	bag_button.pressed.connect(toggle_task_window)
	root.add_child(bag_button)


func set_view_context(context: StringName) -> void:
	view_context = context
	if task_window != null and not task_window.user_moved:
		task_window.position = _default_window_position()


func toggle_task_window() -> void:
	task_window.visible = not task_window.visible
	if task_window.visible:
		task_window.refresh()
		task_window.fit_to_contents()
		if not task_window.user_moved:
			task_window.position = _default_window_position()
		root.move_child(task_window, root.get_child_count() - 1)
	else:
		hand_bar.set_highlight_rule(null)
		slot_rule_focused.emit(null)


func close_task_window() -> void:
	task_window.visible = false
	hand_bar.set_highlight_rule(null)
	slot_rule_focused.emit(null)


func _on_slot_rule_focused(rule: CardSlotRule) -> void:
	hand_bar.set_highlight_rule(rule)
	slot_rule_focused.emit(rule)


func _default_window_position() -> Vector2:
	return Vector2(635, 24) if view_context == &"shop" else Vector2(330, 44)


func _on_locale_changed(_locale: String) -> void:
	_refresh_locale()


func _refresh_locale() -> void:
	bag_button.tooltip_text = TranslationServer.translate(&"slot.task.open")
