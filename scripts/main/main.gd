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
	map.next_day_requested.connect(_on_next_day_requested)
	add_child(map)
	current_screen = map
	current_view = &"map"
	if not notice_key.is_empty():
		map.call_deferred("show_notice", notice_key)


func _show_shop(store_id: StringName = DemoCatalog.STORE_TOY) -> void:
	_clear_screen()
	var packed := load("res://scenes/shop_lab/shop_lab.tscn") as PackedScene
	var shop := packed.instantiate()
	shop.store_id = store_id
	shop.name = "%sShopScreen" % String(store_id).to_pascal_case()
	shop.leave_requested.connect(_on_shop_leave_requested)
	shop.event_completed.connect(_on_teddy_event_completed)
	shop.next_day_requested.connect(_on_shop_next_day_requested)
	add_child(shop)
	current_screen = shop
	current_view = &"shop"


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


func _on_teddy_event_completed() -> void:
	_show_map(&"map.notice.teddy_complete")


func _on_next_day_requested() -> void:
	var result := GameState.advance_day()
	if current_view == &"map" and current_screen is MallMapScreen:
		current_screen.show_day_transition(result)


func _on_shop_next_day_requested() -> void:
	var result := GameState.advance_day()
	_show_map()
	current_screen.show_day_transition(result)
