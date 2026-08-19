class_name QuestMapScreen
extends Control

signal shop_requested(store_id: StringName)
signal expedition_requested
signal card_staging_changed(card: CardItemState, staged: bool)
signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
signal background_pressed

var state: QuestGameState
var store_hotspots: Dictionary = {}
var notice_label: Label
var notice_panel: PanelContainer
var location_popup: QuestLocationPopup
var location_popups: Dictionary = {}
var background_input: Control
var debug_refresh_count := 0
var expedition_button: Button
var expedition_confirm_dialog: ConfirmationDialog


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
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)


func refresh() -> void:
	if state == null:
		return
	debug_refresh_count += 1
	for store_id in store_hotspots:
		var hotspot := store_hotspots[store_id] as QuestStoreHotspot
		var map_visible := state.is_store_visible(store_id)
		hotspot.visible = map_visible
		if not map_visible:
			continue
		var unlocked := state.is_store_unlocked(store_id)
		hotspot.text = "➜" if unlocked else "▣"
		hotspot.add_theme_font_size_override("font_size", 32 if unlocked else 26)
		hotspot.modulate = Color.WHITE if unlocked else Color(0.62, 0.71, 0.69, 0.92)
		hotspot.tooltip_text = ""


func show_notice(message_key: StringName) -> void:
	notice_label.text = TranslationServer.translate(message_key)
	notice_panel.visible = true


func _build_interface() -> void:
	var background := TextureRect.new()
	background.name = "MapBackground"
	background.texture = load("res://resources/background/map.png") as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left = -QuestMain.BACKGROUND_OVERSCAN
	background.offset_top = -QuestMain.BACKGROUND_OVERSCAN
	background.offset_right = QuestMain.BACKGROUND_OVERSCAN
	background.offset_bottom = QuestMain.BACKGROUND_OVERSCAN
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var night_filter := ColorRect.new()
	night_filter.color = Color(0.012, 0.04, 0.06, 0.38)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.offset_left = -QuestMain.BACKGROUND_OVERSCAN
	night_filter.offset_top = -QuestMain.BACKGROUND_OVERSCAN
	night_filter.offset_right = QuestMain.BACKGROUND_OVERSCAN
	night_filter.offset_bottom = QuestMain.BACKGROUND_OVERSCAN
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)
	background_input = Control.new()
	background_input.name = "MapBackgroundInput"
	background_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_input.mouse_filter = Control.MOUSE_FILTER_STOP
	background_input.gui_input.connect(_on_background_gui_input)
	add_child(background_input)

	var content := QuestArcCatalog.manifest()
	if content != null:
		for raw_store in content.stores:
			var store := raw_store as StoreDefinition
			if store == null:
				continue
			var hotspot := QuestStoreHotspot.new()
			hotspot.name = "%sHotspot" % String(store.id).to_pascal_case()
			hotspot.state = state
			hotspot.store_id = store.id
			var anchor := store.map_anchor
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

	expedition_button = Button.new()
	expedition_button.name = "MallExpeditionEntrance"
	expedition_button.anchor_left = 0.405
	expedition_button.anchor_top = 0.69
	expedition_button.anchor_right = 0.595
	expedition_button.anchor_bottom = 0.785
	expedition_button.add_theme_font_size_override("font_size", 18)
	expedition_button.add_theme_color_override("font_color", Color("e7eee8"))
	expedition_button.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("081318", 0.92), Color("d0bd7f", 0.88))
	)
	expedition_button.add_theme_stylebox_override(
		"hover", UiPalette.panel_style(Color("10252a", 0.98), Color("f0d590"))
	)
	expedition_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	expedition_button.pressed.connect(_on_expedition_pressed)
	add_child(expedition_button)
	expedition_confirm_dialog = ConfirmationDialog.new()
	expedition_confirm_dialog.name = "ExpeditionConfirmation"
	expedition_confirm_dialog.confirmed.connect(expedition_requested.emit)
	add_child(expedition_confirm_dialog)
	_refresh_expedition_text()


func _on_store_pressed(store_id: StringName) -> void:
	if not state.is_store_visible(store_id):
		return
	if state.is_store_unlocked(store_id):
		shop_requested.emit(store_id)
	else:
		_open_location_popup(store_id)


func _on_expedition_pressed() -> void:
	_close_location_popup()
	expedition_confirm_dialog.popup_centered(Vector2i(480, 190))


func _refresh_expedition_text() -> void:
	if expedition_button == null or expedition_confirm_dialog == null:
		return
	expedition_button.text = TranslationServer.translate(&"expedition.ui.enter")
	expedition_confirm_dialog.title = TranslationServer.translate(&"expedition.ui.enter")
	expedition_confirm_dialog.dialog_text = TranslationServer.translate(
		&"expedition.ui.confirm_enter"
	)
	expedition_confirm_dialog.ok_button_text = TranslationServer.translate(&"demo.ui.confirm")
	expedition_confirm_dialog.cancel_button_text = TranslationServer.translate(&"demo.ui.cancel")


func _open_location_popup(store_id: StringName) -> void:
	_close_location_popup()
	location_popup = location_popups.get(store_id) as QuestLocationPopup
	if location_popup == null:
		location_popup = QuestLocationPopup.new()
		location_popup.name = "%sLocationPopup" % String(store_id).to_pascal_case()
		location_popup.setup(state, store_id)
		location_popup.closed.connect(_close_location_popup)
		location_popup.staging_changed.connect(card_staging_changed.emit)
		location_popup.rule_focused.connect(rule_focused.emit)
		location_popup.item_inspected.connect(item_inspected.emit)
		location_popup.unlock_confirmed.connect(_on_unlock_confirmed)
		add_child(location_popup)
		location_popup.set_drag_bounds_control(self)
		location_popups[store_id] = location_popup
	else:
		location_popup.refresh()
	location_popup.visible = true


func _close_location_popup() -> void:
	if location_popup != null and is_instance_valid(location_popup):
		location_popup.release_pending_card()
		location_popup.visible = false
	location_popup = null
	rule_focused.emit(null)


func show_drop_targets_for_card(card: CardItemState) -> void:
	if location_popup != null and location_popup.visible:
		location_popup.show_drop_targets_for_card(card)


func clear_drop_target_highlights() -> void:
	if location_popup != null:
		location_popup.clear_drop_target_highlights()


func _on_unlock_confirmed(store_id: StringName, card: CardItemState) -> void:
	var result := state.unlock_store(store_id, card)
	if result.ok:
		_close_location_popup()
		refresh()
		shop_requested.emit(store_id)
	elif location_popup != null:
		location_popup.show_feedback(StringName(result.reason))


func _on_locale_changed(_locale: String) -> void:
	_refresh_expedition_text()
	refresh()


func _on_background_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	if location_popup != null:
		_close_location_popup()
	background_pressed.emit()


func _on_state_delta(delta: QuestStateDelta) -> void:
	if delta != null and delta.affects_map():
		refresh()
