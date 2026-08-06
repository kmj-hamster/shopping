class_name QuestMain
extends Control

var state: QuestGameState
var current_screen: Control
var task_dock: QuestTaskDock
var synthesis_interface: QuestSynthesisInterface
var hand_bar: QuestHandBar
var detail_popup: ItemDetailPopup
var arc_overlay: ColorRect
var arc_day_label: Label
var arc_result_label: Label
var transition_in_progress := false
var focused_rule: CardSlotRule
var arc_fade_seconds := 0.35
var arc_result_seconds := 1.35
var arc_empty_seconds := 1.15
var arc_new_day_seconds := 0.55


func _ready() -> void:
	state = GameState.quest_state
	_build_global_interface()
	_show_map()
	if state.pending_arc != null:
		call_deferred("_resume_arc")


func _build_global_interface() -> void:
	task_dock = QuestTaskDock.new()
	task_dock.name = "QuestTaskDock"
	task_dock.setup(state)
	task_dock.rule_focused.connect(_on_rule_focused)
	task_dock.item_inspected.connect(_show_item)
	add_child(task_dock)
	synthesis_interface = QuestSynthesisInterface.new()
	synthesis_interface.name = "QuestSynthesisInterface"
	synthesis_interface.setup(state)
	synthesis_interface.rule_focused.connect(_on_rule_focused)
	synthesis_interface.item_inspected.connect(_show_item)
	add_child(synthesis_interface)
	hand_bar = QuestHandBar.new()
	hand_bar.name = "QuestHandBar"
	hand_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_bar.offset_top = -132
	hand_bar.setup(state)
	hand_bar.item_inspected.connect(_show_item)
	add_child(hand_bar)
	detail_popup = ItemDetailPopup.new()
	add_child(detail_popup)
	_build_arc_overlay()


func _show_map() -> void:
	_clear_screen()
	var map := QuestMapScreen.new()
	map.name = "QuestMapScreen"
	map.setup(state)
	map.shop_requested.connect(_show_shop)
	map.next_day_requested.connect(_on_next_day_requested)
	add_child(map)
	move_child(map, 0)
	current_screen = map
	task_dock.set_store_context(&"")
	hand_bar.visible = true


func _show_shop(store_id: StringName) -> void:
	_clear_screen()
	var shop := QuestShopScreen.new()
	shop.name = "%sShopScreen" % String(store_id).to_pascal_case()
	shop.setup(state, store_id)
	shop.leave_requested.connect(_show_map)
	shop.item_inspected.connect(_show_item)
	add_child(shop)
	move_child(shop, 0)
	current_screen = shop
	task_dock.set_store_context(store_id)
	shop.set_highlight_rule(focused_rule)
	hand_bar.visible = true


func _clear_screen() -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null


func _show_item(definition: CardItemDefinition) -> void:
	detail_popup.show_item(definition)


func _on_rule_focused(rule: CardSlotRule) -> void:
	focused_rule = rule
	hand_bar.set_highlight_rule(rule)
	if current_screen != null and current_screen.has_method("set_highlight_rule"):
		current_screen.set_highlight_rule(rule)


func _on_next_day_requested() -> void:
	if transition_in_progress:
		return
	var result := state.begin_next_day()
	if result.ok:
		_run_arc()


func _resume_arc() -> void:
	if not transition_in_progress and state.pending_arc != null:
		_run_arc()


func _run_arc() -> void:
	transition_in_progress = true
	hand_bar.visible = false
	detail_popup.close()
	arc_day_label.text = TranslationServer.translate(&"quest.ui.arc.night") % state.day
	arc_result_label.text = ""
	arc_overlay.visible = true
	arc_overlay.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(arc_overlay, "modulate:a", 1.0, arc_fade_seconds)
	await fade.finished
	var applied := state.apply_arc_effects()
	if not applied.ok:
		push_error("Arc application failed: %s" % applied.reason)
		transition_in_progress = false
		return
	if state.pending_arc.entries.is_empty():
		arc_result_label.text = TranslationServer.translate(&"quest.ui.arc.empty")
		await get_tree().create_timer(arc_empty_seconds).timeout
	while state.pending_arc != null and state.pending_arc.next_entry_index < state.pending_arc.entries.size():
		var entry := state.pending_arc.entries[state.pending_arc.next_entry_index]
		arc_result_label.text = TranslationServer.translate(StringName(entry.result_text_key))
		await get_tree().create_timer(arc_result_seconds).timeout
		state.mark_arc_entry_shown()
	var finish := state.finish_arc()
	if not finish.ok:
		push_error("Arc finish failed: %s" % finish.reason)
		transition_in_progress = false
		return
	arc_day_label.text = TranslationServer.translate(&"quest.ui.arc.new_day") % state.day
	arc_result_label.text = ""
	await get_tree().create_timer(arc_new_day_seconds).timeout
	var fade_out := create_tween()
	fade_out.tween_property(arc_overlay, "modulate:a", 0.0, arc_fade_seconds)
	await fade_out.finished
	arc_overlay.visible = false
	transition_in_progress = false
	hand_bar.visible = true
	_show_map()


func _build_arc_overlay() -> void:
	arc_overlay = ColorRect.new()
	arc_overlay.name = "QuestArcOverlay"
	arc_overlay.color = Color("010204")
	arc_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	arc_overlay.z_index = 500
	arc_overlay.visible = false
	add_child(arc_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(760, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	arc_day_label = Label.new()
	arc_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arc_day_label.add_theme_font_size_override("font_size", 16)
	arc_day_label.add_theme_color_override("font_color", Color("718582"))
	column.add_child(arc_day_label)
	arc_result_label = Label.new()
	arc_result_label.custom_minimum_size = Vector2(740, 140)
	arc_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arc_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arc_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arc_result_label.add_theme_font_size_override("font_size", 23)
	arc_result_label.add_theme_color_override("font_color", Color("d7d0b9"))
	column.add_child(arc_result_label)
