class_name MallMapScreen
extends Control

signal shop_requested(store_id: StringName)
signal next_day_requested

var title_label: Label
var day_money_label: Label
var language_button: Button
var store_hotspots: Dictionary = {}
var notice_label: Label
var notice_key: StringName = &""
var notice_store_id: StringName = &""
var schedule_button: Button
var next_day_button: Button
var next_day_hint_label: Label
var schedule_panel: PanelContainer
var schedule_list: VBoxContainer
var schedule_title_label: Label
var transition_panel: PanelContainer
var transition_title_label: Label
var transition_body_label: Label
var transition_day := 0
var demo_complete_scrim: ColorRect
var demo_complete_panel: PanelContainer
var demo_complete_title: Label
var demo_complete_body: Label
var demo_continue_button: Button


func _ready() -> void:
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	GameState.state_changed.connect(refresh)
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


func show_day_transition(result: Dictionary) -> void:
	transition_day = result.day
	schedule_panel.visible = false
	transition_panel.visible = true
	_refresh_transition()


func show_demo_complete() -> void:
	schedule_panel.visible = false
	transition_panel.visible = false
	demo_complete_scrim.visible = true
	demo_complete_panel.visible = true


func refresh() -> void:
	if not is_node_ready():
		return
	day_money_label.text = TranslationServer.translate(&"map.day_week_money") % [
		GameState.day,
		TranslationServer.translate(ShopSchedule.weekday_key(GameState.day)),
		GameState.wallet.money,
	]
	next_day_button.disabled = false
	var next_day_tooltip_key := &"map.next_day.ready"
	if not GameState.daily_goal.submitted:
		next_day_tooltip_key = &"map.next_day.locked"
	next_day_button.tooltip_text = TranslationServer.translate(next_day_tooltip_key)
	if GameState.daily_goal.submitted:
		next_day_hint_label.visible = false
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
	var next_day_box := VBoxContainer.new()
	next_day_box.custom_minimum_size = Vector2(108, 0)
	next_day_box.add_theme_constant_override("separation", 2)
	top.add_child(next_day_box)
	next_day_button = Button.new()
	next_day_button.custom_minimum_size = Vector2(82, 38)
	next_day_button.pressed.connect(_on_next_day_pressed)
	next_day_box.add_child(next_day_button)
	next_day_hint_label = Label.new()
	next_day_hint_label.visible = false
	next_day_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_day_hint_label.add_theme_font_size_override("font_size", 10)
	next_day_hint_label.add_theme_color_override("font_color", Color("d9b96f"))
	next_day_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_day_box.add_child(next_day_hint_label)
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(58, 38)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	top.add_child(language_button)

	var hotspot_layout := {
		DemoCatalog.STORE_BOOK: Rect2(770, 150, 230, 130),
		DemoCatalog.STORE_TOY: Rect2(130, 322, 252, 150),
		DemoCatalog.STORE_FLOWER: Rect2(340, 402, 210, 145),
		DemoCatalog.STORE_RECORD: Rect2(650, 392, 240, 150),
		DemoCatalog.STORE_FAST_FOOD: Rect2(1010, 315, 220, 155),
		DemoCatalog.STORE_RECYCLING: Rect2(76, 512, 208, 96),
	}
	for store_id in DemoCatalog.STORE_IDS:
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

	transition_panel = PanelContainer.new()
	transition_panel.name = "DayTransition"
	transition_panel.position = Vector2(420, 235)
	transition_panel.size = Vector2(440, 220)
	transition_panel.visible = false
	transition_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("071a20", 0.98), Color("d4b66f", 0.92))
	)
	add_child(transition_panel)
	var transition_column := VBoxContainer.new()
	transition_column.alignment = BoxContainer.ALIGNMENT_CENTER
	transition_column.add_theme_constant_override("separation", 12)
	transition_panel.add_child(transition_column)
	transition_title_label = Label.new()
	transition_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_title_label.add_theme_font_size_override("font_size", 25)
	transition_title_label.add_theme_color_override("font_color", Color("efd18a"))
	transition_column.add_child(transition_title_label)
	transition_body_label = Label.new()
	transition_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_body_label.add_theme_font_size_override("font_size", 17)
	transition_column.add_child(transition_body_label)
	var transition_close := Button.new()
	transition_close.custom_minimum_size = Vector2(100, 36)
	transition_close.text = "OK"
	transition_close.pressed.connect(func() -> void: transition_panel.visible = false)
	transition_column.add_child(transition_close)

	var notice_panel := PanelContainer.new()
	notice_panel.name = "NightNotice"
	notice_panel.position = Vector2(28, 630)
	notice_panel.size = Vector2(720, 52)
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
	if next_day_hint_label.visible:
		next_day_hint_label.text = TranslationServer.translate(&"map.next_day.locked")
	schedule_title_label.text = TranslationServer.translate(&"map.schedule.title")
	demo_complete_title.text = TranslationServer.translate(&"demo.complete.title")
	demo_complete_body.text = TranslationServer.translate(&"demo.complete.body")
	demo_continue_button.text = TranslationServer.translate(&"demo.complete.continue")
	_refresh_transition()
	_refresh_notice()


func _refresh_notice() -> void:
	if notice_label == null:
		return
	if notice_key.is_empty():
		notice_label.text = ""
	elif not notice_store_id.is_empty():
		var next_day := ShopSchedule.next_open_day(notice_store_id, GameState.day)
		notice_label.text = TranslationServer.translate(notice_key) % [
			TranslationServer.translate(DemoCatalog.store_name_key(notice_store_id)),
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
		var open := GameState.is_store_open(store_id)
		var status_text := TranslationServer.translate(&"map.open")
		if not open:
			var next_day := ShopSchedule.next_open_day(store_id, GameState.day)
			status_text = TranslationServer.translate(&"map.closed_until") % \
				TranslationServer.translate(ShopSchedule.weekday_key(next_day))
		hotspot.text = "%s\n%s" % [
			TranslationServer.translate(DemoCatalog.store_name_key(store_id)),
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
			store_names.append(TranslationServer.translate(DemoCatalog.store_name_key(store_id)))
		row.text = "%s   %s" % [
			TranslationServer.translate(ShopSchedule.WEEKDAY_KEYS[index]),
			" · ".join(store_names),
		]
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override(
			"font_color",
			Color("efd18a") if index == ShopSchedule.weekday_index(GameState.day) else Color("b8ceca")
		)
		schedule_list.add_child(row)


func _refresh_transition() -> void:
	if transition_title_label == null or transition_day <= 0:
		return
	transition_title_label.text = TranslationServer.translate(&"map.day.title") % [
		transition_day,
		TranslationServer.translate(ShopSchedule.weekday_key(transition_day)),
	]
	var store_names: PackedStringArray = []
	for store_id in ShopSchedule.open_store_ids(transition_day):
		store_names.append(TranslationServer.translate(DemoCatalog.store_name_key(store_id)))
	transition_body_label.text = TranslationServer.translate(&"map.day.summary") % \
		" · ".join(store_names)


func _on_store_pressed(store_id: StringName) -> void:
	shop_requested.emit(store_id)


func _on_schedule_pressed() -> void:
	schedule_panel.visible = not schedule_panel.visible


func _on_next_day_pressed() -> void:
	if not GameState.daily_goal.submitted:
		next_day_hint_label.text = TranslationServer.translate(&"map.next_day.locked")
		next_day_hint_label.visible = true
		return
	next_day_requested.emit()


func _on_demo_continue_pressed() -> void:
	demo_complete_scrim.visible = false
	demo_complete_panel.visible = false
