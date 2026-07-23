class_name MallMapScreen
extends Control

signal shop_requested(store_id: StringName)

var title_label: Label
var day_money_label: Label
var language_button: Button
var toy_hotspot: Button
var goal_label: Label
var notice_label: Label
var notice_key: StringName = &""


func _ready() -> void:
	_build_interface()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	GameState.state_changed.connect(refresh)
	_apply_locale_texts()
	refresh()


func show_notice(message_key: StringName) -> void:
	notice_key = message_key
	_refresh_notice()


func refresh() -> void:
	if not is_node_ready():
		return
	day_money_label.text = TranslationServer.translate(&"map.day_money") % [
		GameState.day, GameState.wallet.money
	]
	goal_label.text = "□  " + TranslationServer.translate(GameState.shopping_goal_key())


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
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(58, 38)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	top.add_child(language_button)

	toy_hotspot = Button.new()
	toy_hotspot.name = "ToyStoreHotspot"
	toy_hotspot.position = Vector2(130, 322)
	toy_hotspot.size = Vector2(252, 150)
	toy_hotspot.add_theme_font_size_override("font_size", 18)
	toy_hotspot.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("071a20", 0.22), Color("76c8bc", 0.68))
	)
	toy_hotspot.add_theme_stylebox_override(
		"hover", UiPalette.panel_style(Color("0b2c31", 0.66), Color("a4e2d3", 0.95))
	)
	toy_hotspot.pressed.connect(func() -> void: shop_requested.emit(DemoCatalog.STORE_TOY))
	add_child(toy_hotspot)

	var goal_panel := PanelContainer.new()
	goal_panel.name = "ShoppingList"
	goal_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	goal_panel.offset_left = 28
	goal_panel.offset_right = -28
	goal_panel.offset_top = -92
	goal_panel.offset_bottom = -22
	goal_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("06171d", 0.88), Color("587a78", 0.84))
	)
	add_child(goal_panel)
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", 16)
	goal_panel.add_child(goal_row)
	goal_label = Label.new()
	goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_label.add_theme_font_size_override("font_size", 18)
	goal_row.add_child(goal_label)
	notice_label = Label.new()
	notice_label.visible = false
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color("efd18a"))
	goal_row.add_child(notice_label)


func _on_locale_changed(_locale: String) -> void:
	_apply_locale_texts()
	refresh()


func _apply_locale_texts() -> void:
	title_label.text = TranslationServer.translate(&"game.title")
	language_button.text = LocaleManager.switch_button_text()
	language_button.tooltip_text = TranslationServer.translate(&"ui.language.tooltip")
	toy_hotspot.text = "%s\n%s" % [
		TranslationServer.translate(&"store.toy"),
		TranslationServer.translate(&"map.open"),
	]
	_refresh_notice()


func _refresh_notice() -> void:
	if notice_label == null:
		return
	if notice_key.is_empty():
		notice_label.text = ""
	else:
		notice_label.text = TranslationServer.translate(notice_key)
	notice_label.visible = not notice_key.is_empty()
