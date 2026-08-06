class_name QuestMapScreen
extends Control

signal shop_requested(store_id: StringName)
signal next_day_requested

var state: QuestGameState
var store_hotspots: Dictionary = {}
var title_label: Label
var day_money_label: Label
var notice_label: Label
var notice_panel: PanelContainer
var next_day_dialog: ConfirmationDialog
var next_day_button: Button
var language_button: Button


func setup(game_state: QuestGameState) -> void:
	state = game_state
	if is_node_ready():
		_bind_state()
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_bind_state()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func _bind_state() -> void:
	if state != null and not state.state_changed.is_connected(refresh):
		state.state_changed.connect(refresh)


func refresh() -> void:
	if state == null or day_money_label == null:
		return
	day_money_label.text = TranslationServer.translate(&"quest.ui.day_money") % [
		state.day, state.wallet.money
	]
	for store_id in store_hotspots:
		var hotspot := store_hotspots[store_id] as QuestStoreHotspot
		var store := QuestArcCatalog.store_by_id(store_id)
		var unlocked := state.is_store_unlocked(store_id)
		if unlocked:
			hotspot.text = str(TranslationServer.translate(store.display_name_key))
		else:
			hotspot.text = "%s\n%s" % [
				TranslationServer.translate(store.display_name_key),
				TranslationServer.translate(&"quest.ui.map.locked"),
			]
		hotspot.modulate = Color.WHITE if unlocked else Color(0.58, 0.65, 0.66, 0.9)
		if unlocked:
			hotspot.tooltip_text = ""
		else:
			hotspot.tooltip_text = str(TranslationServer.translate(
				QuestArcCatalog.store_unlock_for_store(store_id).prompt_text_key
			))


func show_notice(message_key: StringName) -> void:
	notice_label.text = TranslationServer.translate(message_key)
	notice_label.visible = true
	notice_panel.visible = true


func _build_interface() -> void:
	var background := TextureRect.new()
	background.texture = load("res://pic/map.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var night_filter := ColorRect.new()
	night_filter.color = Color(0.012, 0.04, 0.06, 0.48)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	var top := HBoxContainer.new()
	top.position = Vector2(28, 20)
	top.size = Vector2(1224, 50)
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("dcece5"))
	top.add_child(title_label)
	day_money_label = Label.new()
	day_money_label.add_theme_font_size_override("font_size", 20)
	day_money_label.add_theme_color_override("font_color", Color("efd18a"))
	top.add_child(day_money_label)
	next_day_button = Button.new()
	next_day_button.custom_minimum_size = Vector2(112, 40)
	next_day_button.pressed.connect(_on_next_day_pressed)
	top.add_child(next_day_button)
	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(60, 40)
	language_button.pressed.connect(LocaleManager.toggle_locale)
	top.add_child(language_button)

	var layout := {
		&"recycling": Rect2(180, 140, 230, 112),
		&"book": Rect2(750, 130, 245, 132),
		&"toy": Rect2(88, 314, 242, 148),
		&"flower": Rect2(360, 386, 200, 142),
		&"record": Rect2(642, 378, 235, 150),
		&"fast_food": Rect2(992, 300, 238, 160),
	}
	var content := QuestArcCatalog.manifest()
	if content != null:
		for raw_store in content.stores:
			var store := raw_store as StoreDefinition
			var hotspot := QuestStoreHotspot.new()
			hotspot.name = "%sHotspot" % String(store.id).to_pascal_case()
			hotspot.state = state
			hotspot.store_id = store.id
			var hotspot_rect: Rect2 = layout.get(store.id, Rect2(40, 100, 220, 120))
			hotspot.position = hotspot_rect.position
			hotspot.size = hotspot_rect.size
			hotspot.add_theme_font_size_override("font_size", 17)
			hotspot.pressed.connect(_on_store_pressed.bind(store.id))
			hotspot.unlock_requested.connect(_on_unlock_requested)
			hotspot.add_theme_stylebox_override(
				"normal", UiPalette.panel_style(Color("06171d", 0.52), Color("6ba39c", 0.74))
			)
			hotspot.add_theme_stylebox_override(
				"hover", UiPalette.panel_style(Color("0c2b30", 0.83), Color("b2ded1", 0.95))
			)
			store_hotspots[store.id] = hotspot
			add_child(hotspot)

	notice_panel = PanelContainer.new()
	notice_panel.position = Vector2(370, 526)
	notice_panel.size = Vector2(540, 52)
	notice_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("041117", 0.9), Color("617c79", 0.75))
	)
	add_child(notice_panel)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", Color("e2c77b"))
	notice_label.visible = false
	notice_panel.add_child(notice_label)
	notice_panel.visible = false

	next_day_dialog = ConfirmationDialog.new()
	next_day_dialog.title = TranslationServer.translate(&"quest.ui.next_day.confirm_title")
	next_day_dialog.dialog_text = TranslationServer.translate(&"quest.ui.next_day.confirm_body")
	next_day_dialog.ok_button_text = TranslationServer.translate(&"quest.ui.next_day.confirm")
	next_day_dialog.cancel_button_text = TranslationServer.translate(&"quest.ui.cancel")
	next_day_dialog.confirmed.connect(next_day_requested.emit)
	add_child(next_day_dialog)
	_refresh_locale_texts()


func _on_store_pressed(store_id: StringName) -> void:
	if state.is_store_unlocked(store_id):
		shop_requested.emit(store_id)
	else:
		var unlock := QuestArcCatalog.store_unlock_for_store(store_id)
		notice_label.text = TranslationServer.translate(unlock.prompt_text_key)
		notice_label.visible = true
		notice_panel.visible = true


func _on_unlock_requested(store_id: StringName, card: CardItemState) -> void:
	var result := state.unlock_store(store_id, card)
	if result.ok:
		notice_label.text = TranslationServer.translate(StringName(result.result_text_key))
		notice_label.visible = true
		notice_panel.visible = true
	refresh()


func _on_next_day_pressed() -> void:
	next_day_dialog.popup_centered(Vector2i(480, 220))


func _on_locale_changed(_locale: String) -> void:
	_refresh_locale_texts()
	refresh()


func _refresh_locale_texts() -> void:
	if title_label == null:
		return
	title_label.text = TranslationServer.translate(&"game.title")
	next_day_button.text = TranslationServer.translate(&"quest.ui.next_day")
	language_button.text = LocaleManager.switch_button_text()
	next_day_dialog.title = TranslationServer.translate(&"quest.ui.next_day.confirm_title")
	next_day_dialog.dialog_text = TranslationServer.translate(&"quest.ui.next_day.confirm_body")
	next_day_dialog.ok_button_text = TranslationServer.translate(&"quest.ui.next_day.confirm")
	next_day_dialog.cancel_button_text = TranslationServer.translate(&"quest.ui.cancel")
