extends Control

var current_screen: Control
var current_view: StringName = &""
var protagonist_interface: SlotPlayerInterface
var transition_in_progress := false


func _ready() -> void:
	_show_map()
	protagonist_interface = SlotPlayerInterface.new()
	protagonist_interface.commerce = GameState.slot_commerce
	protagonist_interface.slot_rule_focused.connect(_on_slot_rule_focused)
	add_child(protagonist_interface)
	protagonist_interface.set_view_context(current_view)
	if GameState.slot_commerce.pending_transition != null:
		call_deferred("_resume_pending_night_transition")


func _show_map(notice_key: StringName = &"") -> void:
	_clear_screen()
	var map := MallMapScreen.new()
	map.name = "MallMapScreen"
	map.commerce = GameState.slot_commerce
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.shop_requested.connect(_on_shop_requested)
	map.next_day_requested.connect(_on_next_day_requested)
	map.demo_continue_requested.connect(_on_demo_continue_requested)
	add_child(map)
	current_screen = map
	current_view = &"map"
	_sync_protagonist_context()
	if not notice_key.is_empty():
		map.call_deferred("show_notice", notice_key)


func _show_shop(store_id: StringName = SlotDemoCatalog.STORE_TOY) -> void:
	_clear_screen()
	var scene_path := (
		"res://scenes/slot_shop/slot_recycle.tscn"
		if store_id == SlotDemoCatalog.STORE_RECYCLING
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
	if ShopSchedule.is_store_open(store_id, GameState.slot_commerce.day):
		_show_shop(store_id)
	else:
		current_screen.show_closed_notice(store_id)


func _on_shop_leave_requested() -> void:
	_show_map()


func _on_next_day_requested() -> void:
	if transition_in_progress:
		return
	var result := GameState.slot_commerce.begin_night_transition()
	if not result.ok:
		if current_screen is MallMapScreen:
			current_screen.show_notice(
				&"slot.map.next_day.synthesis_active"
				if result.reason == SlotCommerceState.RESULT_SYNTHESIS_ACTIVE
				else &"slot.map.next_day.incomplete"
			)
		return
	_run_night_transition(result.transition)


func _run_night_transition(transition: SlotNightTransition) -> void:
	transition_in_progress = true
	var map := current_screen as MallMapScreen
	protagonist_interface.close_task_window()
	protagonist_interface.visible = false
	await map.fade_to_night()
	var consumption := GameState.slot_commerce.apply_night_transition_consumption()
	if not consumption.ok:
		push_error("Night transition consumption failed: %s" % consumption.reason)
		protagonist_interface.visible = true
		transition_in_progress = false
		return
	while transition.next_result_index < transition.entries.size():
		await map.show_night_result(
			transition.entries[transition.next_result_index]
		)
		if not GameState.slot_commerce.mark_night_transition_result_shown():
			push_error("Night transition result checkpoint failed.")
			protagonist_interface.visible = true
			transition_in_progress = false
			return
	var finish := GameState.slot_commerce.finish_night_transition()
	if not finish.ok:
		push_error("Night transition finish failed: %s" % finish.reason)
		protagonist_interface.visible = true
		transition_in_progress = false
		return
	map.refresh()
	await map.fade_from_night(finish)
	transition_in_progress = false
	if finish.demo_complete:
		map.show_demo_complete()
	else:
		protagonist_interface.visible = true


func _resume_pending_night_transition() -> void:
	if transition_in_progress or GameState.slot_commerce.pending_transition == null:
		return
	_run_night_transition(GameState.slot_commerce.pending_transition)


func _on_demo_continue_requested() -> void:
	protagonist_interface.visible = true


func _sync_protagonist_context() -> void:
	if protagonist_interface != null:
		protagonist_interface.set_view_context(current_view)
		_on_slot_rule_focused(protagonist_interface.hand_bar.highlight_rule)


func _on_slot_rule_focused(rule: CardSlotRule) -> void:
	if current_screen != null and current_screen.has_method("set_highlight_rule"):
		current_screen.set_highlight_rule(rule)
