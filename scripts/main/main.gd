extends Control

var current_screen: Control
var current_view: StringName = &""
var protagonist_interface: SlotPlayerInterface


func _ready() -> void:
	GameState.reset_demo()
	_show_map()
	protagonist_interface = SlotPlayerInterface.new()
	protagonist_interface.commerce = GameState.slot_commerce
	protagonist_interface.slot_rule_focused.connect(_on_slot_rule_focused)
	add_child(protagonist_interface)
	protagonist_interface.set_view_context(current_view)


func _show_map(notice_key: StringName = &"") -> void:
	_clear_screen()
	var map := MallMapScreen.new()
	map.name = "MallMapScreen"
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.shop_requested.connect(_on_shop_requested)
	map.next_day_requested.connect(_on_next_day_requested)
	add_child(map)
	current_screen = map
	current_view = &"map"
	_sync_protagonist_context()
	if not notice_key.is_empty():
		map.call_deferred("show_notice", notice_key)


func _show_shop(store_id: StringName = DemoCatalog.STORE_TOY) -> void:
	_clear_screen()
	var scene_path := (
		"res://scenes/slot_shop/slot_recycle.tscn"
		if store_id == DemoCatalog.STORE_RECYCLING
		else "res://scenes/slot_shop/slot_shop.tscn"
	)
	var packed := load(scene_path) as PackedScene
	var shop := packed.instantiate()
	shop.commerce = GameState.slot_commerce
	shop.show_embedded_hand_bar = false
	if shop is SlotShopScreen:
		shop.store_id = store_id
	shop.name = "%sShopScreen" % String(store_id).to_pascal_case()
	shop.leave_requested.connect(_on_shop_leave_requested)
	add_child(shop)
	current_screen = shop
	current_view = &"shop"
	_sync_protagonist_context()


func _clear_screen() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null


func _on_shop_requested(store_id: StringName) -> void:
	if GameState.is_store_open(store_id):
		_show_shop(store_id)
	else:
		current_screen.show_closed_notice(store_id)


func _on_shop_leave_requested() -> void:
	_show_map()


func _on_next_day_requested() -> void:
	var result := GameState.advance_day()
	if result.ok and current_view == &"map" and current_screen is MallMapScreen:
		current_screen.show_day_transition(result)


func _sync_protagonist_context() -> void:
	if protagonist_interface != null:
		protagonist_interface.set_view_context(current_view)
		_on_slot_rule_focused(protagonist_interface.hand_bar.highlight_rule)


func _on_slot_rule_focused(rule: CardSlotRule) -> void:
	if current_screen != null and current_screen.has_method("set_highlight_rule"):
		current_screen.set_highlight_rule(rule)
