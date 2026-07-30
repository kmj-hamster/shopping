class_name SlotTaskWindow
extends PanelContainer

signal close_requested
signal slot_rule_focused(rule: CardSlotRule)

const TAB_DAILY := &"daily"
const TAB_RECIPES := &"recipes"
const TAB_REQUESTS := &"requests"

var commerce: SlotCommerceState
var activity_state: SlotActivityState
var current_tab := TAB_DAILY
var current_activity_id: StringName = &"wish_hungry"
var tab_buttons: Dictionary = {}
var activity_tabs: HBoxContainer
var activity_title: Label
var slots_row: HBoxContainer
var result_label: Label
var action_button: Button
var slot_views: Dictionary = {}
var dragging := false
var user_moved := false
var refresh_queued := false


func setup(commerce_state: SlotCommerceState) -> void:
	commerce = commerce_state
	activity_state = commerce.activity_state if commerce != null else null
	if is_node_ready():
		_bind_state()
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(620, 430)
	size = Vector2(620, 430)
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("020609", 0.985), Color("596c68", 0.9))
	)
	_build_interface()
	_bind_state()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func _bind_state() -> void:
	if activity_state != null and not activity_state.state_changed.is_connected(_queue_refresh):
		activity_state.state_changed.connect(_queue_refresh)


func _build_interface() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 34)
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_header_input)
	column.add_child(header)
	var window_title := Label.new()
	window_title.name = "WindowTitle"
	window_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_title.add_theme_font_size_override("font_size", 18)
	window_title.add_theme_color_override("font_color", Color("d5e1db"))
	header.add_child(window_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	var primary_tabs := HBoxContainer.new()
	primary_tabs.add_theme_constant_override("separation", 6)
	column.add_child(primary_tabs)
	for tab_id in [TAB_DAILY, TAB_RECIPES, TAB_REQUESTS]:
		var button := Button.new()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(tab_id))
		primary_tabs.add_child(button)
		tab_buttons[tab_id] = button
	activity_tabs = HBoxContainer.new()
	activity_tabs.add_theme_constant_override("separation", 5)
	column.add_child(activity_tabs)
	activity_title = Label.new()
	activity_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_title.add_theme_font_size_override("font_size", 19)
	activity_title.add_theme_color_override("font_color", Color("d6bd77"))
	column.add_child(activity_title)
	var slots_center := CenterContainer.new()
	slots_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(slots_center)
	slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 10)
	slots_center.add_child(slots_row)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 13)
	result_label.add_theme_color_override("font_color", Color("8ea49f"))
	column.add_child(result_label)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(0, 38)
	action_button.pressed.connect(_on_action_pressed)
	column.add_child(action_button)


func refresh() -> void:
	if activity_tabs == null or activity_state == null:
		return
	_refresh_tab_texts()
	for child in activity_tabs.get_children():
		child.free()
	var activities := _activities_for_current_tab()
	if activities.is_empty():
		current_activity_id = &""
	else:
		if current_activity_id not in activities:
			current_activity_id = activities[0]
		for activity_id in activities:
			var button := Button.new()
			button.toggle_mode = true
			button.text = "%s%s" % [
				"✓  " if activity_state.is_daily_confirmed(activity_id) else "",
				_activity_name(activity_id),
			]
			button.button_pressed = activity_id == current_activity_id
			button.pressed.connect(_select_activity.bind(activity_id))
			activity_tabs.add_child(button)
	_rebuild_slots()
	fit_to_contents()
	call_deferred("fit_to_contents")


func fit_to_contents() -> void:
	size = get_combined_minimum_size()


func _rebuild_slots() -> void:
	for child in slots_row.get_children():
		child.free()
	slot_views.clear()
	if current_activity_id.is_empty():
		activity_title.text = TranslationServer.translate(&"slot.task.none")
		result_label.text = ""
		action_button.visible = false
		return
	activity_title.text = _activity_name(current_activity_id)
	for rule in activity_state.rules_for_activity(current_activity_id):
		var slot := CardTaskSlot.new()
		slot.setup(commerce, activity_state, current_activity_id, rule)
		slot.focused.connect(_on_slot_focused)
		slot.drop_resolved.connect(_on_drop_resolved)
		slots_row.add_child(slot)
		slot_views[rule.id] = slot
	var evaluation := activity_state.evaluation_for(current_activity_id)
	var confirmed := activity_state.is_daily_confirmed(current_activity_id)
	result_label.text = TranslationServer.translate(
		&"slot.task.confirmed"
		if confirmed
		else &"slot.task.ready" if evaluation.is_ready else &"slot.task.waiting"
	)
	action_button.visible = current_tab == TAB_DAILY
	action_button.disabled = not confirmed and not evaluation.is_ready
	action_button.text = TranslationServer.translate(
		&"slot.task.cancel_confirm" if confirmed else &"slot.task.confirm"
	)
	if evaluation.is_ready and evaluation.has("synthesis"):
		var preview_key: StringName = evaluation.synthesis.preview_key
		if not preview_key.is_empty():
			result_label.text = TranslationServer.translate(preview_key)


func _select_tab(tab_id: StringName) -> void:
	current_tab = tab_id
	var activities := _activities_for_current_tab()
	current_activity_id = activities[0] if not activities.is_empty() else &""
	refresh()


func _select_activity(activity_id: StringName) -> void:
	current_activity_id = activity_id
	refresh()


func _activities_for_current_tab() -> Array[StringName]:
	match current_tab:
		TAB_DAILY:
			return activity_state.active_daily_wish_ids
		TAB_RECIPES:
			return activity_state.known_recipe_ids
		TAB_REQUESTS:
			return activity_state.active_request_ids
	return []


func _activity_name(activity_id: StringName) -> String:
	var wish := SlotDemoCatalog.wish_by_id(activity_id)
	if wish != null:
		return wish.localized_name()
	var recipe := SlotDemoCatalog.recipe_by_id(activity_id)
	if recipe != null:
		return TranslationServer.translate(recipe.display_name_key)
	return String(activity_id)


func _refresh_tab_texts() -> void:
	(tab_buttons[TAB_DAILY] as Button).text = TranslationServer.translate(&"slot.task.tab.daily")
	(tab_buttons[TAB_RECIPES] as Button).text = TranslationServer.translate(&"slot.task.tab.recipes")
	(tab_buttons[TAB_REQUESTS] as Button).text = TranslationServer.translate(&"slot.task.tab.requests")
	for tab_id in tab_buttons:
		(tab_buttons[tab_id] as Button).button_pressed = tab_id == current_tab
	var title := find_child("WindowTitle", true, false) as Label
	if title != null:
		title.text = TranslationServer.translate(&"slot.task.window.title")


func _on_slot_focused(rule: CardSlotRule) -> void:
	slot_rule_focused.emit(rule)


func _on_drop_resolved(result: Dictionary) -> void:
	if not result.ok:
		result_label.text = TranslationServer.translate(&"slot.task.drop.rejected")


func _on_action_pressed() -> void:
	if current_tab != TAB_DAILY or current_activity_id.is_empty():
		return
	if activity_state.is_daily_confirmed(current_activity_id):
		activity_state.cancel_daily_confirmation(current_activity_id)
	else:
		activity_state.confirm_daily_wish(current_activity_id)


func _on_locale_changed(_locale: String) -> void:
	refresh()


func _queue_refresh() -> void:
	if refresh_queued:
		return
	refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	refresh_queued = false
	refresh()


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed:
			user_moved = true
	elif event is InputEventMouseMotion and dragging:
		position += event.relative
		var viewport_size := get_viewport_rect().size
		position.x = clampf(position.x, 0.0, maxf(0.0, viewport_size.x - 120.0))
		position.y = clampf(position.y, 0.0, maxf(0.0, viewport_size.y - 60.0))
