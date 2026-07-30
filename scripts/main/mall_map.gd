class_name MallMapScreen
extends Control

signal shop_requested(store_id: StringName)
signal next_day_requested
signal demo_continue_requested

var commerce: SlotCommerceState
var title_label: Label
var day_money_label: Label
var language_button: Button
var store_hotspots: Dictionary = {}
var notice_label: Label
var notice_panel: PanelContainer
var notice_key: StringName = &""
var notice_store_id: StringName = &""
var schedule_button: Button
var next_day_button: Button
var schedule_panel: PanelContainer
var schedule_list: VBoxContainer
var schedule_title_label: Label
var night_overlay: ColorRect
var night_result_label: Label
var night_day_label: Label
var demo_complete_scrim: ColorRect
var demo_complete_panel: PanelContainer
var demo_complete_title: Label
var demo_complete_body: Label
var demo_continue_button: Button
var transition_fade_seconds := 0.35
var transition_result_seconds := 1.15
var transition_dawn_seconds := 0.7
var transition_return_seconds := 0.4


func _ready() -> void:
	if commerce == null:
		commerce = GameState.slot_commerce
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	commerce.state_changed.connect(refresh)
	_apply_locale_texts()
	refresh()


func show_notice(message_key: StringName) -> void:
	notice_key = message_key
	notice_store_id = &""
	_refresh_notice()


func show_closed_notice(store_id: StringName) -> void:
	notice_key = &"map.notice.store_closed"
	notice_store_id = store_id
	_refresh_notice()


func show_demo_complete() -> void:
	schedule_panel.visible = false
	_refresh_demo_complete_body()
	demo_complete_scrim.visible = true
	demo_complete_panel.visible = true


func refresh() -> void:
	if not is_node_ready():
		return
	day_money_label.text = TranslationServer.translate(&"map.day_week_money") % [
		commerce.day,
		TranslationServer.translate(ShopSchedule.weekday_key(commerce.day)),
		commerce.wallet.money,
	]
	next_day_button.disabled = false
	var next_day_tooltip_key := &"map.next_day.ready"
	if not commerce.activity_state.all_daily_wishes_confirmed():
		next_day_tooltip_key = &"slot.map.next_day.incomplete"
	next_day_button.tooltip_text = TranslationServer.translate(next_day_tooltip_key)
	if (
		commerce.activity_state.all_daily_wishes_confirmed()
		and notice_key == &"slot.map.next_day.incomplete"
	):
		notice_key = &""
		notice_store_id = &""
		_refresh_notice()
	_refresh_store_hotspots()
	_refresh_schedule()


func _build_interface() -> void:
	var background := TextureRect.new()
	background.name = "MallMap"
	background.texture = load("res://pic/map.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var night_filter := ColorRect.new()
	night_filter.color = Color(0.015, 0.045, 0.065, 0.42)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 28)
	top_margin.add_theme_constant_override("margin_right", 28)
	top_margin.add_theme_constant_override("margin_top", 20)
	add_child(top_margin)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top_margin.add_child(top)
	var sign_box := VBoxContainer.new()
	sign_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_box.add_theme_constant_override("separation", -2)
	top.add_child(sign_box)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("def2eb"))
	sign_box.add_child(title_label)
	var clock := Label.new()
	clock.text = "21:41  ·  AFTER WORK"
	clock.add_theme_font_size_override("font_size", 11)
	clock.add_theme_color_override("font_color", Color("95b7b2"))
	sign_box.add_child(clock)
	day_money_label = Label.new()
	day_money_label.add_theme_font_size_override("font_size", 20)
	day_money_label.add_theme_color_override("font_color", Color("efd18a"))
	top.add_child(day_money_label)
	schedule_button = Button.new()
	schedule_button.custom_minimum_size = Vector2(76, 38)
	schedule_button.pressed.connect(_on_schedule_pressed)
	top.add_child(schedule_button)
	next_day_button = Button.new()
	next_day_button.custom_minimum_size = Vector2(82, 38)
	next_day_button.pressed.connect(_on_next_day_pressed)
	top.add_child(next_day_button)
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(58, 38)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	top.add_child(language_button)

	var hotspot_layout := {
		SlotDemoCatalog.STORE_BOOK: Rect2(770, 150, 230, 130),
		SlotDemoCatalog.STORE_TOY: Rect2(105, 322, 230, 140),
		SlotDemoCatalog.STORE_FLOWER: Rect2(370, 402, 190, 135),
		SlotDemoCatalog.STORE_RECORD: Rect2(650, 392, 220, 145),
		SlotDemoCatalog.STORE_FAST_FOOD: Rect2(1010, 315, 220, 150),
		SlotDemoCatalog.STORE_RECYCLING: Rect2(64, 148, 210, 104),
	}
	for store_id in SlotDemoCatalog.MAP_STORE_IDS:
		_create_store_hotspot(store_id, hotspot_layout[store_id])

	schedule_panel = PanelContainer.new()
	schedule_panel.name = "WeeklySchedule"
	schedule_panel.position = Vector2(760, 86)
	schedule_panel.size = Vector2(468, 350)
	schedule_panel.visible = false
	schedule_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("06171d", 0.97), Color("76a9a4", 0.9))
	)
	add_child(schedule_panel)
	var schedule_column := VBoxContainer.new()
	schedule_column.add_theme_constant_override("separation", 7)
	schedule_panel.add_child(schedule_column)
	var schedule_header := HBoxContainer.new()
	schedule_column.add_child(schedule_header)
	schedule_title_label = Label.new()
	schedule_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	schedule_title_label.add_theme_font_size_override("font_size", 20)
	schedule_header.add_child(schedule_title_label)
	var schedule_close := Button.new()
	schedule_close.text = "×"
	schedule_close.pressed.connect(func() -> void: schedule_panel.visible = false)
	schedule_header.add_child(schedule_close)
	schedule_list = VBoxContainer.new()
	schedule_list.add_theme_constant_override("separation", 4)
	schedule_column.add_child(schedule_list)

	notice_panel = PanelContainer.new()
	notice_panel.name = "NightNotice"
	notice_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice_panel.offset_left = 300.0
	notice_panel.offset_top = -216.0
	notice_panel.offset_right = -300.0
	notice_panel.offset_bottom = -158.0
	notice_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("06171d", 0.88), Color("587a78", 0.84))
	)
	add_child(notice_panel)
	notice_label = Label.new()
	notice_label.visible = false
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color("efd18a"))
	notice_panel.add_child(notice_label)
	notice_panel.visible = false
	notice_label.visibility_changed.connect(func() -> void: notice_panel.visible = notice_label.visible)

	night_overlay = ColorRect.new()
	night_overlay.name = "NightTransition"
	night_overlay.color = Color("010204")
	night_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	night_overlay.visible = false
	night_overlay.modulate.a = 0.0
	add_child(night_overlay)
	var transition_center := CenterContainer.new()
	transition_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_overlay.add_child(transition_center)
	var transition_column := VBoxContainer.new()
	transition_column.custom_minimum_size = Vector2(720, 0)
	transition_column.alignment = BoxContainer.ALIGNMENT_CENTER
	transition_column.add_theme_constant_override("separation", 20)
	transition_center.add_child(transition_column)
	night_day_label = Label.new()
	night_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	night_day_label.add_theme_font_size_override("font_size", 17)
	night_day_label.add_theme_color_override("font_color", Color("778a89"))
	transition_column.add_child(night_day_label)
	night_result_label = Label.new()
	night_result_label.custom_minimum_size = Vector2(700, 110)
	night_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	night_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	night_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	night_result_label.add_theme_font_size_override("font_size", 22)
	night_result_label.add_theme_color_override("font_color", Color("d8d3bd"))
	transition_column.add_child(night_result_label)

	demo_complete_scrim = ColorRect.new()
	demo_complete_scrim.color = Color(0.005, 0.02, 0.028, 0.78)
	demo_complete_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	demo_complete_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	demo_complete_scrim.visible = false
	add_child(demo_complete_scrim)
	demo_complete_panel = PanelContainer.new()
	demo_complete_panel.position = Vector2(390, 175)
	demo_complete_panel.size = Vector2(500, 350)
	demo_complete_panel.visible = false
	demo_complete_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("06171d", 0.99), Color("d4b66f", 0.95))
	)
	add_child(demo_complete_panel)
	var demo_column := VBoxContainer.new()
	demo_column.alignment = BoxContainer.ALIGNMENT_CENTER
	demo_column.add_theme_constant_override("separation", 18)
	demo_complete_panel.add_child(demo_column)
	demo_complete_title = Label.new()
	demo_complete_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_complete_title.add_theme_font_size_override("font_size", 29)
	demo_complete_title.add_theme_color_override("font_color", Color("efd18a"))
	demo_column.add_child(demo_complete_title)
	demo_complete_body = Label.new()
	demo_complete_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_complete_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo_complete_body.add_theme_font_size_override("font_size", 17)
	demo_complete_body.add_theme_color_override("font_color", Color("c4d8d4"))
	demo_column.add_child(demo_complete_body)
	demo_continue_button = Button.new()
	demo_continue_button.custom_minimum_size = Vector2(150, 40)
	demo_continue_button.pressed.connect(_on_demo_continue_pressed)
	demo_column.add_child(demo_continue_button)


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_texts()
	refresh()


func _apply_locale_texts() -> void:
	title_label.text = TranslationServer.translate(&"game.title")
	language_button.text = LocaleManager.switch_button_text()
	language_button.tooltip_text = TranslationServer.translate(&"ui.language.tooltip")
	schedule_button.text = TranslationServer.translate(&"map.schedule")
	next_day_button.text = TranslationServer.translate(&"map.next_day")
	schedule_title_label.text = TranslationServer.translate(&"map.schedule.title")
	demo_complete_title.text = TranslationServer.translate(&"demo.complete.title")
	_refresh_demo_complete_body()
	demo_continue_button.text = TranslationServer.translate(&"demo.complete.continue")
	_refresh_notice()


func _refresh_demo_complete_body() -> void:
	if demo_complete_body == null:
		return
	var branch := StringName(commerce.story_flags.get(&"balloon_hug", &""))
	var body_key := &"demo.complete.body"
	if branch == &"memory":
		body_key = &"demo.complete.body.balloon_memory"
	elif branch == &"comfort":
		body_key = &"demo.complete.body.balloon_comfort"
	demo_complete_body.text = TranslationServer.translate(body_key)


func _refresh_notice() -> void:
	if notice_label == null:
		return
	if notice_key.is_empty():
		notice_label.text = ""
	elif not notice_store_id.is_empty():
		var next_day := ShopSchedule.next_open_day(notice_store_id, commerce.day)
		notice_label.text = TranslationServer.translate(notice_key) % [
			TranslationServer.translate(SlotDemoCatalog.store_name_key(notice_store_id)),
			TranslationServer.translate(ShopSchedule.weekday_key(next_day)),
		]
	else:
		notice_label.text = TranslationServer.translate(notice_key)
	notice_label.visible = not notice_key.is_empty()


func _create_store_hotspot(store_id: StringName, rect: Rect2) -> void:
	var hotspot := Button.new()
	hotspot.name = "%sHotspot" % String(store_id).to_pascal_case()
	hotspot.position = rect.position
	hotspot.size = rect.size
	hotspot.add_theme_font_size_override("font_size", 17)
	hotspot.pressed.connect(_on_store_pressed.bind(store_id))
	store_hotspots[store_id] = hotspot
	add_child(hotspot)


func _refresh_store_hotspots() -> void:
	for store_id in store_hotspots:
		var hotspot := store_hotspots[store_id] as Button
		var open := ShopSchedule.is_store_open(store_id, commerce.day)
		var status_text := TranslationServer.translate(&"map.open")
		if not open:
			var next_day := ShopSchedule.next_open_day(store_id, commerce.day)
			status_text = TranslationServer.translate(&"map.closed_until") % \
				TranslationServer.translate(ShopSchedule.weekday_key(next_day))
		hotspot.text = "%s\n%s" % [
			TranslationServer.translate(SlotDemoCatalog.store_name_key(store_id)),
			status_text,
		]
		hotspot.add_theme_stylebox_override(
			"normal",
			UiPalette.panel_style(
				Color("071a20", 0.24 if open else 0.66),
				Color("76c8bc", 0.72) if open else Color("536566", 0.58)
			)
		)
		hotspot.add_theme_stylebox_override(
			"hover",
			UiPalette.panel_style(
				Color("0b2c31", 0.72),
				Color("a4e2d3", 0.95) if open else Color("788d8c", 0.8)
			)
		)
		hotspot.modulate = Color.WHITE if open else Color(0.7, 0.76, 0.76, 0.86)


func _refresh_schedule() -> void:
	if schedule_list == null:
		return
	for child in schedule_list.get_children():
		child.free()
	for index in range(7):
		var row := Label.new()
		var store_names: PackedStringArray = []
		for store_id in ShopSchedule.OPEN_STORES[index]:
			store_names.append(TranslationServer.translate(SlotDemoCatalog.store_name_key(store_id)))
		row.text = "%s   %s" % [
			TranslationServer.translate(ShopSchedule.WEEKDAY_KEYS[index]),
			" · ".join(store_names),
		]
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override(
			"font_color",
			Color("efd18a") if index == ShopSchedule.weekday_index(commerce.day) else Color("b8ceca")
		)
		schedule_list.add_child(row)


func fade_to_night() -> void:
	schedule_panel.visible = false
	notice_key = &""
	_refresh_notice()
	night_day_label.text = TranslationServer.translate(&"slot.transition.night") % commerce.day
	night_result_label.text = ""
	night_overlay.visible = true
	move_child(night_overlay, get_child_count() - 1)
	night_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(night_overlay, "modulate:a", 1.0, transition_fade_seconds)
	await tween.finished


func show_night_result(entry: Dictionary) -> void:
	night_result_label.text = TranslationServer.translate(StringName(entry.result_key))
	await get_tree().create_timer(transition_result_seconds).timeout


func fade_from_night(result: Dictionary) -> void:
	night_day_label.text = TranslationServer.translate(&"slot.transition.new_day") % result.day
	night_result_label.text = TranslationServer.translate(&"slot.transition.income") % result.income
	await get_tree().create_timer(transition_dawn_seconds).timeout
	var tween := create_tween()
	tween.tween_property(night_overlay, "modulate:a", 0.0, transition_return_seconds)
	await tween.finished
	night_overlay.visible = false


func _on_store_pressed(store_id: StringName) -> void:
	shop_requested.emit(store_id)


func _on_schedule_pressed() -> void:
	schedule_panel.visible = not schedule_panel.visible


func _on_next_day_pressed() -> void:
	if not commerce.activity_state.all_daily_wishes_confirmed():
		show_notice(&"slot.map.next_day.incomplete")
		return
	next_day_requested.emit()


func _on_demo_continue_pressed() -> void:
	demo_complete_scrim.visible = false
	demo_complete_panel.visible = false
	demo_continue_requested.emit()
