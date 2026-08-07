class_name QuestMapScreen
extends Control

signal shop_requested(store_id: StringName)
signal card_staging_changed(card: CardItemState, staged: bool)
signal rule_focused(rule: CardSlotRule)

var state: QuestGameState
var store_hotspots: Dictionary = {}
var notice_label: Label
var notice_panel: PanelContainer
var location_popup: QuestLocationPopup


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
	if state == null:
		return
	for store_id in store_hotspots:
		var hotspot := store_hotspots[store_id] as QuestStoreHotspot
		var store := QuestArcCatalog.store_by_id(store_id)
		var unlocked := state.is_store_unlocked(store_id)
		hotspot.text = "➜" if unlocked else "▣"
		hotspot.add_theme_font_size_override("font_size", 32 if unlocked else 26)
		hotspot.modulate = Color.WHITE if unlocked else Color(0.62, 0.71, 0.69, 0.92)
		if unlocked:
			hotspot.tooltip_text = TranslationServer.translate(store.display_name_key)
		else:
			var unlock := QuestArcCatalog.store_unlock_for_store(store_id)
			hotspot.tooltip_text = "%s\n%s" % [
				TranslationServer.translate(store.display_name_key),
				TranslationServer.translate(unlock.prompt_text_key),
			]


func show_notice(message_key: StringName) -> void:
	notice_label.text = TranslationServer.translate(message_key)
	notice_panel.visible = true


func _build_interface() -> void:
	var background := TextureRect.new()
	background.texture = load("res://resources/background/map.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var night_filter := ColorRect.new()
	night_filter.color = Color(0.012, 0.04, 0.06, 0.38)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)

	var layout := {
		&"flower": Vector2(0.40, 0.61),
		&"record": Vector2(0.66, 0.46),
	}
	var content := QuestArcCatalog.manifest()
	if content != null:
		for raw_store in content.stores:
			var store := raw_store as StoreDefinition
			if store == null or not layout.has(store.id):
				continue
			var hotspot := QuestStoreHotspot.new()
			hotspot.name = "%sHotspot" % String(store.id).to_pascal_case()
			hotspot.state = state
			hotspot.store_id = store.id
			var anchor: Vector2 = layout[store.id]
			hotspot.anchor_left = anchor.x
			hotspot.anchor_top = anchor.y
			hotspot.anchor_right = anchor.x
			hotspot.anchor_bottom = anchor.y
			hotspot.offset_left = -42
			hotspot.offset_top = -42
			hotspot.offset_right = 42
			hotspot.offset_bottom = 42
			hotspot.pressed.connect(_on_store_pressed.bind(store.id))
			hotspot.add_theme_stylebox_override(
				"normal", UiPalette.round_button_style(Color("081b20", 0.82), Color("9bb8ad", 0.9), 44)
			)
			hotspot.add_theme_stylebox_override(
				"hover", UiPalette.round_button_style(Color("17373a", 0.96), Color("f0d28a"), 44)
			)
			store_hotspots[store.id] = hotspot
			add_child(hotspot)

	notice_panel = PanelContainer.new()
	notice_panel.anchor_left = 0.25
	notice_panel.anchor_top = 0.84
	notice_panel.anchor_right = 0.75
	notice_panel.anchor_bottom = 0.96
	notice_panel.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("041117", 0.94), Color("617c79", 0.78))
	)
	add_child(notice_panel)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_color_override("font_color", Color("e2c77b"))
	notice_panel.add_child(notice_label)
	notice_panel.visible = false


func _on_store_pressed(store_id: StringName) -> void:
	if state.is_store_unlocked(store_id):
		shop_requested.emit(store_id)
	else:
		_open_location_popup(store_id)


func _open_location_popup(store_id: StringName) -> void:
	_close_location_popup()
	location_popup = QuestLocationPopup.new()
	location_popup.name = "LocationPopup"
	location_popup.setup(state, store_id)
	location_popup.closed.connect(_close_location_popup)
	location_popup.staging_changed.connect(card_staging_changed.emit)
	location_popup.rule_focused.connect(rule_focused.emit)
	location_popup.unlock_confirmed.connect(_on_unlock_confirmed)
	add_child(location_popup)


func _close_location_popup() -> void:
	if location_popup != null and is_instance_valid(location_popup):
		location_popup.release_pending_card()
		location_popup.queue_free()
	location_popup = null
	rule_focused.emit(null)


func _on_unlock_confirmed(store_id: StringName, card: CardItemState) -> void:
	var result := state.unlock_store(store_id, card)
	if result.ok:
		_close_location_popup()
		refresh()
		shop_requested.emit(store_id)
	elif location_popup != null:
		location_popup.show_feedback(StringName(result.reason))


func _on_locale_changed(_locale: String) -> void:
	refresh()
