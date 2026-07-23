extends Control

var current_screen: Control
var current_view: StringName = &""


func _ready() -> void:
	GameState.reset_demo()
	_show_map()


func _show_map(notice_key: StringName = &"") -> void:
	_clear_screen()
	var map := MallMapScreen.new()
	map.name = "MallMapScreen"
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.shop_requested.connect(_on_shop_requested)
	add_child(map)
	current_screen = map
	current_view = &"map"
	if not notice_key.is_empty():
		map.call_deferred("show_notice", notice_key)


func _show_shop() -> void:
	_clear_screen()
	var packed := load("res://scenes/shop_lab/shop_lab.tscn") as PackedScene
	var shop := packed.instantiate()
	shop.name = "ToyShopScreen"
	shop.leave_requested.connect(_on_shop_leave_requested)
	shop.event_completed.connect(_on_teddy_event_completed)
	add_child(shop)
	current_screen = shop
	current_view = &"shop"


func _clear_screen() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null


func _on_shop_requested(store_id: StringName) -> void:
	if store_id == DemoCatalog.STORE_TOY:
		_show_shop()


func _on_shop_leave_requested() -> void:
	_show_map()


func _on_teddy_event_completed() -> void:
	_show_map(&"map.notice.teddy_complete")
