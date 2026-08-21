class_name QuestShopScreen
extends Control

signal leave_requested
signal item_inspected(definition: CardItemDefinition)
signal checkout_completed
signal background_pressed

const DIALOGUE_SILENT_CHARACTERS := " \t\r\n，。！？、；：,.!?;:…—-（）()“”\"'"
const DIALOGUE_VOICE_PLAYER_COUNT := 3
const DIALOGUE_MAX_VISIBLE_LINES := 4
const SHELF_LABEL_FONT_SIZE := 13
const SHELF_ZH_LABEL_FONT_SIZE := 15
const DIALOGUE_TEXT_COLOR := Color("edf2ee")
const DIALOGUE_FEEDBACK_COLOR := Color("f0d8ce")
const CHECKOUT_NORMAL_COLOR := Color("dce8e4", 0.12)
const CHECKOUT_NORMAL_BORDER := Color("f2f7f5", 0.46)
const SHOP_BACK_TEXTURE: Texture2D = preload("res://resources/ui/shell/shop-back.png")
const SHOP_SHELF_TEXTURE: Texture2D = preload("res://resources/ui/shell/shop-shelf.png")
const SHOP_TALK_TEXTURE: Texture2D = preload("res://resources/ui/shell/shop-talk.png")
const FROSTED_DIALOGUE_SHADER: Shader = preload(
	"res://resources/shaders/frosted_dialogue.gdshader"
)
const LOWERED_OWNER_STORES: Array[StringName] = [&"fast_food", &"record", &"bookstore"]
const OWNER_PORTRAIT_RECTS := {
	# Ratty keeps the shared scale but sits slightly lower so the actual artwork,
	# not only its Control, reaches beneath the lower frame.
	&"fast_food": Rect2(0.595, 0.205, 0.275, 0.92),
	# Mr. Sunflower's source is proportionally smaller in the shared rect. Widen
	# it while lowering its center so the head stays composed and the hem is cut.
	&"flower": Rect2(0.562, 0.17, 0.317, 0.96),
}

var state: QuestGameState
var store_id: StringName
var transaction: CardShopTransaction
var shelf_popup: PanelContainer
var shelf_grid: GridContainer
var title_label: Label
var owner_portrait: TextureRect
var navigation_column: VBoxContainer
var dialogue_panel: PanelContainer
var dialogue_back_buffer: BackBufferCopy
var dialogue_glass: ColorRect
var shelf_back_buffer: BackBufferCopy
var shelf_glass: ColorRect
var owner_name_background: Panel
var checkout_button: Button
var feedback_label: Label
var owner_name_label: Label
var owner_dialogue_label: Label
var shelf_nav_button: Button
var talk_nav_button: Button
var talk_request_dot: Panel
var leave_nav_button: Button
var restock_label: Label
var shelf_buttons: Dictionary = {}
var shelf_views: Array[Dictionary] = []
var shelf_view_slot_ids: Array[StringName] = []
var highlight_rule: CardSlotRule
var owner_dialogue_override_key: StringName
var owner_dialogue_item_name := ""
var owner_dialogue_char_seconds := 0.055
var owner_dialogue_full_text := ""
var owner_dialogue_page_text := ""
var owner_dialogue_pages: Array[String] = []
var owner_dialogue_page_index := 0
var owner_dialogue_layout_width := -1.0
var owner_dialogue_repagination_queued := false
var owner_dialogue_is_typing := false
var owner_dialogue_generation := 0
var owner_dialogue_voice_index := 0
var owner_dialogue_voice_players: Array[AudioStreamPlayer] = []
var owner_dialogue_timer: Timer
var owner_dialogue_character_index := 0
var owner_dialogue_voiced_character_count := 0
var background_input: Control
var selection_dialogue_refresh_suppressed := false


func setup(game_state: QuestGameState, selected_store_id: StringName) -> void:
	state = game_state
	store_id = selected_store_id
	transaction = state.transaction_for_store(store_id)
	if is_node_ready():
		_bind_state()
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_build_owner_dialogue_timer()
	_bind_state()
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func _build_owner_dialogue_timer() -> void:
	owner_dialogue_timer = Timer.new()
	owner_dialogue_timer.one_shot = true
	owner_dialogue_timer.timeout.connect(_advance_owner_dialogue_character)
	add_child(owner_dialogue_timer)


func _on_background_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		background_pressed.emit()


func _bind_state() -> void:
	if transaction != null and not transaction.selection_changed.is_connected(_on_selection_changed):
		transaction.selection_changed.connect(_on_selection_changed)


func _build_interface() -> void:
	var background := TextureRect.new()
	background.name = "StoreBackground"
	background.texture = _store_background_texture()
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
	night_filter.color = Color("031014", 0.28)
	night_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_filter.offset_left = -QuestMain.BACKGROUND_OVERSCAN
	night_filter.offset_top = -QuestMain.BACKGROUND_OVERSCAN
	night_filter.offset_right = QuestMain.BACKGROUND_OVERSCAN
	night_filter.offset_bottom = QuestMain.BACKGROUND_OVERSCAN
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night_filter)
	background_input = Control.new()
	background_input.name = "ShopBackgroundInput"
	background_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_input.mouse_filter = Control.MOUSE_FILTER_STOP
	background_input.gui_input.connect(_on_background_gui_input)
	add_child(background_input)

	owner_portrait = TextureRect.new()
	owner_portrait.name = "StoreOwnerPortrait"
	owner_portrait.texture = _owner_texture()
	var portrait_rect := _owner_portrait_rect()
	owner_portrait.anchor_left = portrait_rect.position.x
	owner_portrait.anchor_top = portrait_rect.position.y
	owner_portrait.anchor_right = portrait_rect.end.x
	owner_portrait.anchor_bottom = portrait_rect.end.y
	owner_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(owner_portrait)

	navigation_column = VBoxContainer.new()
	navigation_column.name = "ShopNavigation"
	navigation_column.anchor_left = 0.88
	navigation_column.anchor_top = 0.36
	navigation_column.anchor_right = 0.957
	navigation_column.anchor_bottom = 0.66
	navigation_column.add_theme_constant_override("separation", 6)
	add_child(navigation_column)
	shelf_nav_button = Button.new()
	shelf_nav_button.name = "ShelfButton"
	_configure_navigation_button(shelf_nav_button, SHOP_SHELF_TEXTURE)
	shelf_nav_button.pressed.connect(_toggle_shelf_popup)
	navigation_column.add_child(shelf_nav_button)
	talk_nav_button = Button.new()
	talk_nav_button.name = "TalkButton"
	_configure_navigation_button(talk_nav_button, SHOP_TALK_TEXTURE)
	talk_nav_button.pressed.connect(_on_owner_pressed)
	navigation_column.add_child(talk_nav_button)
	talk_request_dot = Panel.new()
	talk_request_dot.name = "OwnerRequestNotice"
	talk_request_dot.anchor_left = 0.78
	talk_request_dot.anchor_top = -0.08
	talk_request_dot.anchor_right = 0.78
	talk_request_dot.anchor_bottom = -0.08
	talk_request_dot.offset_left = -5
	talk_request_dot.offset_top = -5
	talk_request_dot.offset_right = 7
	talk_request_dot.offset_bottom = 7
	talk_request_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var notice_style := StyleBoxFlat.new()
	notice_style.bg_color = Color("b83b45")
	notice_style.border_color = Color("ffd2c7", 0.72)
	notice_style.set_border_width_all(1)
	notice_style.set_corner_radius_all(7)
	notice_style.shadow_color = Color("e64a55", 0.56)
	notice_style.shadow_size = 5
	talk_request_dot.add_theme_stylebox_override("panel", notice_style)
	talk_nav_button.add_child(talk_request_dot)
	leave_nav_button = Button.new()
	leave_nav_button.name = "LeaveButton"
	_configure_navigation_button(leave_nav_button, SHOP_BACK_TEXTURE)
	leave_nav_button.pressed.connect(leave_requested.emit)
	navigation_column.add_child(leave_nav_button)

	dialogue_back_buffer = BackBufferCopy.new()
	dialogue_back_buffer.name = "DialogueBackBuffer"
	dialogue_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(dialogue_back_buffer)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "OwnerDialoguePanel"
	dialogue_panel.anchor_left = 0.405
	dialogue_panel.anchor_top = 0.735
	dialogue_panel.anchor_right = 0.865
	dialogue_panel.anchor_bottom = 0.97
	dialogue_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	dialogue_panel.clip_contents = true
	dialogue_panel.gui_input.connect(_on_dialogue_panel_gui_input)
	add_child(dialogue_panel)
	var dialogue_stack := Control.new()
	dialogue_stack.name = "OwnerDialogueStack"
	dialogue_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_panel.add_child(dialogue_stack)
	dialogue_glass = ColorRect.new()
	dialogue_glass.name = "FrostedDialogueGlass"
	dialogue_glass.anchor_top = 0.20
	dialogue_glass.anchor_right = 1.0
	dialogue_glass.anchor_bottom = 1.0
	dialogue_glass.color = Color.WHITE
	dialogue_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass_material := ShaderMaterial.new()
	glass_material.shader = FROSTED_DIALOGUE_SHADER
	dialogue_glass.material = glass_material
	dialogue_glass.resized.connect(_update_dialogue_glass_size)
	dialogue_stack.add_child(dialogue_glass)
	var dialogue_content := Control.new()
	dialogue_content.name = "OwnerDialogueContent"
	dialogue_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_content.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_stack.add_child(dialogue_content)
	owner_name_background = Panel.new()
	owner_name_background.name = "OwnerNameBackground"
	owner_name_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_name_background.anchor_left = 0.10
	owner_name_background.anchor_right = 0.42
	owner_name_background.anchor_bottom = 0.22
	var owner_name_style := StyleBoxFlat.new()
	owner_name_style.bg_color = (
		Color("9a914b", 0.96) if store_id == &"toy" else Color("a6534b", 0.96)
	)
	owner_name_style.corner_radius_top_left = 8
	owner_name_style.corner_radius_top_right = 8
	owner_name_style.corner_radius_bottom_left = 3
	owner_name_style.corner_radius_bottom_right = 3
	owner_name_background.add_theme_stylebox_override("panel", owner_name_style)
	dialogue_content.add_child(owner_name_background)
	owner_name_label = Label.new()
	owner_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	owner_name_label.anchor_left = 0.10
	owner_name_label.anchor_top = 0.0
	owner_name_label.anchor_right = 0.42
	owner_name_label.anchor_bottom = 0.22
	owner_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owner_name_label.add_theme_font_size_override("font_size", 14)
	owner_name_label.add_theme_color_override("font_color", DIALOGUE_TEXT_COLOR)
	dialogue_content.add_child(owner_name_label)
	owner_dialogue_label = Label.new()
	owner_dialogue_label.mouse_filter = Control.MOUSE_FILTER_PASS
	owner_dialogue_label.anchor_left = 0.055
	owner_dialogue_label.anchor_top = 0.28
	owner_dialogue_label.anchor_right = 0.715
	owner_dialogue_label.anchor_bottom = 0.73
	owner_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	owner_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_dialogue_label.max_lines_visible = DIALOGUE_MAX_VISIBLE_LINES
	owner_dialogue_label.clip_text = true
	owner_dialogue_label.add_theme_color_override("font_color", DIALOGUE_TEXT_COLOR)
	owner_dialogue_label.resized.connect(_on_owner_dialogue_label_resized)
	dialogue_content.add_child(owner_dialogue_label)
	feedback_label = Label.new()
	feedback_label.mouse_filter = Control.MOUSE_FILTER_PASS
	feedback_label.anchor_left = 0.055
	feedback_label.anchor_top = 0.74
	feedback_label.anchor_right = 0.715
	feedback_label.anchor_bottom = 0.95
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", DIALOGUE_FEEDBACK_COLOR)
	dialogue_content.add_child(feedback_label)
	checkout_button = Button.new()
	checkout_button.anchor_left = 0.735
	checkout_button.anchor_top = 0.35
	checkout_button.anchor_right = 0.94
	checkout_button.anchor_bottom = 0.82
	_configure_checkout_button()
	checkout_button.pressed.connect(_on_checkout_pressed)
	dialogue_content.add_child(checkout_button)

	_build_dialogue_voice_players()
	_build_shelf_popup()
	call_deferred("_update_dialogue_glass_size")


func _update_dialogue_glass_size() -> void:
	if dialogue_glass == null or not (dialogue_glass.material is ShaderMaterial):
		return
	var glass_material := dialogue_glass.material as ShaderMaterial
	glass_material.set_shader_parameter("panel_size_px", dialogue_glass.size)


func _configure_navigation_button(button: Button, texture: Texture2D) -> void:
	button.custom_minimum_size = Vector2(82, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = texture
	button.expand_icon = true
	button.text = ""
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())


func _configure_checkout_button() -> void:
	checkout_button.focus_mode = Control.FOCUS_NONE
	checkout_button.add_theme_font_size_override("font_size", 15)
	checkout_button.add_theme_color_override("font_color", DIALOGUE_TEXT_COLOR)
	checkout_button.add_theme_color_override("font_hover_color", Color("ffffff"))
	checkout_button.add_theme_color_override("font_pressed_color", Color("f7fbf9"))
	checkout_button.add_theme_color_override("font_disabled_color", Color("aab8b3", 0.64))
	checkout_button.add_theme_stylebox_override(
		"normal", _checkout_style(CHECKOUT_NORMAL_COLOR, CHECKOUT_NORMAL_BORDER)
	)
	checkout_button.add_theme_stylebox_override(
		"hover", _checkout_style(Color("e7f0ed", 0.20), Color("ffffff", 0.68), 0.26)
	)
	checkout_button.add_theme_stylebox_override(
		"pressed", _checkout_style(Color("cbd9d5", 0.18), Color("eef6f3", 0.56), 0.12)
	)
	checkout_button.add_theme_stylebox_override(
		"disabled", _checkout_style(Color("8fa09a", 0.07), Color("c8d4d0", 0.20), 0.0)
	)
	checkout_button.add_theme_stylebox_override(
		"focus", _checkout_style(CHECKOUT_NORMAL_COLOR, Color("ffffff", 0.58), 0.22)
	)


func _checkout_style(background: Color, border: Color, glow_alpha := 0.16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color("f4fbf8", glow_alpha)
	style.shadow_size = 5 if glow_alpha > 0.0 else 0
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


func _build_dialogue_voice_players() -> void:
	for index in range(DIALOGUE_VOICE_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "OwnerDialogueVoice%d" % (index + 1)
		add_child(player)
		owner_dialogue_voice_players.append(player)


func _build_shelf_popup() -> void:
	shelf_back_buffer = BackBufferCopy.new()
	shelf_back_buffer.name = "ShelfBackBuffer"
	shelf_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	shelf_back_buffer.visible = false
	add_child(shelf_back_buffer)
	shelf_popup = PanelContainer.new()
	shelf_popup.name = "ShelfPopup"
	shelf_popup.anchor_left = 0.18
	shelf_popup.anchor_top = 0.13
	shelf_popup.anchor_right = 0.475
	shelf_popup.anchor_bottom = 0.72
	shelf_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	shelf_popup.clip_contents = true
	add_child(shelf_popup)
	shelf_glass = ColorRect.new()
	shelf_glass.name = "FrostedShelfGlass"
	shelf_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shelf_glass.color = Color.WHITE
	shelf_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shelf_glass_material := ShaderMaterial.new()
	shelf_glass_material.shader = FROSTED_DIALOGUE_SHADER
	shelf_glass_material.set_shader_parameter("glass_tint", Color("dce8e4"))
	shelf_glass_material.set_shader_parameter("blur_lod", 2.7)
	shelf_glass_material.set_shader_parameter("tint_strength", 0.18)
	shelf_glass_material.set_shader_parameter("brightness", 1.03)
	shelf_glass_material.set_shader_parameter("distortion_px", 0.82)
	shelf_glass_material.set_shader_parameter("dispersion_px", 0.55)
	shelf_glass_material.set_shader_parameter("corner_radius_px", 16.0)
	shelf_glass_material.set_shader_parameter("edge_depth_px", 9.0)
	shelf_glass.material = shelf_glass_material
	shelf_glass.resized.connect(_update_shelf_glass_size)
	shelf_popup.add_child(shelf_glass)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 10)
	shelf_popup.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	restock_label = Label.new()
	restock_label.custom_minimum_size.y = 20
	restock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	restock_label.add_theme_font_size_override("font_size", SHELF_LABEL_FONT_SIZE)
	restock_label.add_theme_color_override("font_color", Color("e8eeea"))
	restock_label.add_theme_color_override("font_shadow_color", Color("071217", 0.74))
	restock_label.add_theme_constant_override("shadow_offset_x", 1)
	restock_label.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(restock_label)
	shelf_grid = GridContainer.new()
	shelf_grid.name = "ShelfCardGrid"
	shelf_grid.columns = 3
	shelf_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shelf_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_grid.add_theme_constant_override("h_separation", 10)
	shelf_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(shelf_grid)
	_build_shelf_views()
	_set_shelf_popup_visible(false)
	call_deferred("_update_shelf_glass_size")


func _build_shelf_views() -> void:
	for view_index in CardShopTransaction.PAGE_SIZE:
		var holder := VBoxContainer.new()
		holder.name = "ShelfCell%d" % (view_index + 1)
		holder.custom_minimum_size = Vector2(CardHandCard.CARD_SIZE.x, 132)
		holder.add_theme_constant_override("separation", 4)
		shelf_grid.add_child(holder)
		var card_host := Control.new()
		card_host.custom_minimum_size = CardHandCard.CARD_SIZE
		card_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.add_child(card_host)
		var card_view := CardHandCard.new()
		card_view.name = "ShelfItemCard"
		card_view.set_shelf_presentation(true)
		card_view.setup(null, null, false)
		card_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_host.add_child(card_view)
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var selection_outline := Panel.new()
		selection_outline.name = "ShelfSelectionOutline"
		selection_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_outline.z_index = 2
		card_host.add_child(selection_outline)
		var button := Button.new()
		button.name = "ShelfCardButton"
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_configure_shelf_card_button(button)
		button.pressed.connect(_on_shelf_view_pressed.bind(view_index))
		button.z_index = 3
		card_host.add_child(button)
		var price := Label.new()
		price.custom_minimum_size.y = 18
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", SHELF_LABEL_FONT_SIZE)
		price.add_theme_color_override("font_color", Color("f0dc9f"))
		price.add_theme_color_override("font_shadow_color", Color("071217", 0.78))
		price.add_theme_constant_override("shadow_offset_x", 1)
		price.add_theme_constant_override("shadow_offset_y", 1)
		holder.add_child(price)
		shelf_views.append({
			"root": holder,
			"card": card_view,
			"button": button,
			"price": price,
			"selection_outline": selection_outline,
		})
		shelf_view_slot_ids.append(&"")


func _configure_shelf_card_button(button: Button) -> void:
	for state_name in ["normal", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("dce8e4", 0.08)
	hover_style.border_color = Color("e8eeea", 0.46)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := hover_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("e0c77d", 0.10)
	pressed_style.border_color = Color("f0dc9f", 0.62)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover_pressed", pressed_style)


func _update_shelf_glass_size() -> void:
	if shelf_glass == null or not (shelf_glass.material is ShaderMaterial):
		return
	(shelf_glass.material as ShaderMaterial).set_shader_parameter(
		"panel_size_px", shelf_glass.size
	)


func _set_shelf_popup_visible(is_visible: bool) -> void:
	if shelf_popup != null:
		shelf_popup.visible = is_visible
	if shelf_back_buffer != null:
		shelf_back_buffer.visible = is_visible


func refresh() -> void:
	if state == null or shelf_grid == null or transaction == null:
		return
	var owner := QuestArcCatalog.owner_for_store(store_id)
	owner_name_label.text = TranslationServer.translate(owner.display_name_key) if owner != null else ""
	owner_portrait.visible = owner_portrait.texture != null
	talk_nav_button.visible = owner != null
	talk_request_dot.visible = owner != null and state.owner_request_notice_visible(store_id)
	dialogue_panel.visible = owner != null
	shelf_nav_button.text = ""
	talk_nav_button.text = ""
	leave_nav_button.text = ""
	restock_label.text = TranslationServer.translate(&"opening.ui.shop.restock") % state.restock_nights_remaining(store_id)
	_apply_shelf_locale_typography()
	_refresh_owner_dialogue()
	_refresh_shelf()
	_refresh_checkout_state()


func _apply_shelf_locale_typography() -> void:
	var font_size := (
		SHELF_ZH_LABEL_FONT_SIZE
		if LocaleManager.current_locale == LocaleManager.LOCALE_ZH
		else SHELF_LABEL_FONT_SIZE
	)
	restock_label.add_theme_font_size_override("font_size", font_size)
	for view in shelf_views:
		(view.price as Label).add_theme_font_size_override("font_size", font_size)


func _refresh_checkout_state() -> void:
	checkout_button.visible = transaction.has_selection()
	checkout_button.text = TranslationServer.translate(&"quest.ui.shop.checkout") % transaction.selected_price()
	checkout_button.disabled = not transaction.has_selection()


func _refresh_shelf() -> void:
	shelf_buttons.clear()
	var slots := transaction.shelf_slots_for_page(1)
	for view_index in shelf_views.size():
		var view := shelf_views[view_index]
		var holder := view.root as VBoxContainer
		var card_view := view.card as CardHandCard
		var button := view.button as Button
		var price := view.price as Label
		var selection_outline := view.selection_outline as Panel
		holder.visible = true
		if view_index >= slots.size():
			shelf_view_slot_ids[view_index] = &""
			_set_empty_shelf_view(card_view, button, price, selection_outline)
			continue
		var slot := slots[view_index] as ShelfSlotState
		shelf_view_slot_ids[view_index] = slot.slot_id
		button.tooltip_text = ""
		button.button_pressed = false
		if slot.is_empty():
			_set_empty_shelf_view(card_view, button, price, selection_outline)
		else:
			var definition := QuestArcCatalog.item_by_id(slot.item_id)
			card_view.setup(null, definition, false)
			card_view.visible = definition != null
			price.visible = definition != null
			button.visible = definition != null
			button.button_pressed = transaction.is_selected(slot.slot_id)
			button.disabled = definition == null
			price.text = TranslationServer.translate(&"demo.ui.price") % transaction.price_for(
				definition
			)
		shelf_buttons[slot.slot_id] = button
		_apply_shelf_highlight(view, slot)


func _set_empty_shelf_view(
	card_view: CardHandCard,
	button: Button,
	price: Label,
	selection_outline: Panel,
) -> void:
	card_view.visible = false
	card_view.apply_match_highlight(false)
	button.visible = false
	button.disabled = true
	button.button_pressed = false
	price.visible = false
	selection_outline.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func _on_shelf_view_pressed(view_index: int) -> void:
	if view_index < 0 or view_index >= shelf_view_slot_ids.size():
		return
	var slot_id := shelf_view_slot_ids[view_index]
	if not slot_id.is_empty():
		_on_shelf_pressed(slot_id)


func _toggle_shelf_popup() -> void:
	_set_shelf_popup_visible(not shelf_popup.visible)


func _on_shelf_pressed(slot_id: StringName) -> void:
	var slot := transaction.shelf_slot(slot_id)
	if slot != null and not slot.is_empty():
		var definition := QuestArcCatalog.item_by_id(slot.item_id)
		item_inspected.emit(definition)
		var owner := QuestArcCatalog.owner_for_store(store_id)
		if owner != null:
			owner_dialogue_override_key = owner.item_comment_key
			owner_dialogue_item_name = definition.localized_name()
	transaction.toggle_shelf_slot(slot_id)


func _on_selection_changed(previous_slot_id: StringName, selected_slot_id: StringName) -> void:
	for slot_id in [previous_slot_id, selected_slot_id]:
		if slot_id.is_empty() or not shelf_buttons.has(slot_id):
			continue
		var button := shelf_buttons[slot_id] as Button
		button.button_pressed = transaction.is_selected(slot_id)
		var slot := transaction.shelf_slot(slot_id)
		var view_index := shelf_view_slot_ids.find(slot_id)
		if view_index >= 0:
			_apply_shelf_highlight(shelf_views[view_index], slot)
	_refresh_checkout_state()
	if not selection_dialogue_refresh_suppressed:
		_refresh_owner_dialogue()


func _on_owner_pressed() -> void:
	if owner_dialogue_is_typing:
		_finish_owner_dialogue_line()
		return
	if _advance_owner_dialogue_page():
		return
	var result := state.interact_with_store_owner(store_id)
	if not result.ok:
		return
	owner_dialogue_override_key = StringName(result.text_key)
	owner_dialogue_item_name = ""
	talk_request_dot.visible = state.owner_request_notice_visible(store_id)
	_refresh_owner_dialogue(true)


func cancel_pending_purchase() -> void:
	_cancel_owner_dialogue_playback()
	owner_dialogue_override_key = &""
	owner_dialogue_item_name = ""
	if transaction != null:
		# Leaving a shop is state cleanup, not a new player selection. Keep the
		# visual selection signal, but do not let it restart the owner's idle line.
		selection_dialogue_refresh_suppressed = true
		transaction.clear_selection()
		selection_dialogue_refresh_suppressed = false
	if feedback_label != null:
		feedback_label.text = ""
	_set_shelf_popup_visible(false)


func _refresh_owner_dialogue(force_restart := false) -> void:
	var key := owner_dialogue_override_key
	if key.is_empty():
		key = state.owner_dialogue_key(store_id)
	var dialogue_text := ""
	if key.is_empty():
		dialogue_text = ""
	elif owner_dialogue_item_name.is_empty():
		dialogue_text = TranslationServer.translate(key)
	else:
		dialogue_text = TranslationServer.translate(key) % owner_dialogue_item_name
	_present_owner_dialogue(dialogue_text, force_restart)


func _present_owner_dialogue(dialogue_text: String, force_restart := false) -> void:
	if not force_restart and dialogue_text == owner_dialogue_full_text:
		return
	owner_dialogue_generation += 1
	owner_dialogue_full_text = dialogue_text
	owner_dialogue_pages = _paginate_owner_dialogue(dialogue_text)
	owner_dialogue_page_index = 0
	owner_dialogue_voice_index = 0
	owner_dialogue_voiced_character_count = 0
	if owner_dialogue_timer != null:
		owner_dialogue_timer.stop()
	_stop_owner_dialogue_voice()
	if dialogue_text.is_empty():
		owner_dialogue_page_text = ""
		owner_dialogue_label.text = ""
		owner_dialogue_label.visible_characters = -1
		owner_dialogue_is_typing = false
		return
	_start_owner_dialogue_page(0)


func _start_owner_dialogue_page(page_index: int) -> void:
	if page_index < 0 or page_index >= owner_dialogue_pages.size():
		owner_dialogue_is_typing = false
		return
	owner_dialogue_page_index = page_index
	owner_dialogue_page_text = owner_dialogue_pages[page_index]
	owner_dialogue_character_index = 0
	owner_dialogue_label.text = owner_dialogue_page_text
	owner_dialogue_label.visible_characters = 0
	owner_dialogue_is_typing = true
	_advance_owner_dialogue_character()


func _advance_owner_dialogue_page() -> bool:
	var next_page := owner_dialogue_page_index + 1
	if next_page >= owner_dialogue_pages.size():
		return false
	owner_dialogue_generation += 1
	if owner_dialogue_timer != null:
		owner_dialogue_timer.stop()
	_stop_owner_dialogue_voice()
	_start_owner_dialogue_page(next_page)
	return true


func _advance_owner_dialogue_character() -> void:
	if not owner_dialogue_is_typing:
		return
	if owner_dialogue_char_seconds <= 0.0:
		_finish_owner_dialogue_line()
		return
	if owner_dialogue_character_index >= owner_dialogue_page_text.length():
		owner_dialogue_label.visible_characters = -1
		owner_dialogue_is_typing = false
		return
	var character := owner_dialogue_page_text.substr(owner_dialogue_character_index, 1)
	owner_dialogue_character_index += 1
	owner_dialogue_label.visible_characters = owner_dialogue_character_index
	if _is_dialogue_voice_character(character):
		if owner_dialogue_voiced_character_count % 2 == 0:
			_play_owner_dialogue_voice()
		owner_dialogue_voiced_character_count += 1
	if owner_dialogue_character_index >= owner_dialogue_page_text.length():
		owner_dialogue_label.visible_characters = -1
		owner_dialogue_is_typing = false
		return
	var delay := owner_dialogue_char_seconds
	if not _is_dialogue_voice_character(character):
		delay *= 1.8
	owner_dialogue_timer.start(delay)


func _finish_owner_dialogue_line() -> void:
	owner_dialogue_generation += 1
	owner_dialogue_is_typing = false
	owner_dialogue_label.visible_characters = -1
	if owner_dialogue_timer != null:
		owner_dialogue_timer.stop()
	_stop_owner_dialogue_voice()


func _cancel_owner_dialogue_playback() -> void:
	owner_dialogue_generation += 1
	owner_dialogue_is_typing = false
	if owner_dialogue_timer != null:
		owner_dialogue_timer.stop()
	_stop_owner_dialogue_voice()


func _paginate_owner_dialogue(dialogue_text: String) -> Array[String]:
	var pages: Array[String] = []
	if dialogue_text.is_empty():
		return pages
	owner_dialogue_layout_width = owner_dialogue_label.size.x
	if owner_dialogue_layout_width <= 1.0:
		pages.append(dialogue_text)
		return pages
	var remaining := dialogue_text.strip_edges()
	while not remaining.is_empty():
		var page_length := _longest_fitting_dialogue_prefix(remaining)
		if page_length <= 0:
			page_length = 1
		page_length = _prefer_dialogue_word_break(remaining, page_length)
		var page_text := remaining.substr(0, page_length).strip_edges()
		if page_text.is_empty():
			page_text = remaining.substr(0, page_length)
		pages.append(page_text)
		remaining = remaining.substr(page_length).strip_edges()
	return pages


func _longest_fitting_dialogue_prefix(text: String) -> int:
	var previous_text := owner_dialogue_label.text
	var previous_visible_characters := owner_dialogue_label.visible_characters
	var previous_max_lines := owner_dialogue_label.max_lines_visible
	owner_dialogue_label.max_lines_visible = -1
	var low := 1
	var high := text.length()
	var best := 0
	while low <= high:
		var midpoint := int((low + high) * 0.5)
		owner_dialogue_label.text = text.substr(0, midpoint)
		owner_dialogue_label.visible_characters = -1
		if owner_dialogue_label.get_line_count() <= DIALOGUE_MAX_VISIBLE_LINES:
			best = midpoint
			low = midpoint + 1
		else:
			high = midpoint - 1
	owner_dialogue_label.text = previous_text
	owner_dialogue_label.visible_characters = previous_visible_characters
	owner_dialogue_label.max_lines_visible = previous_max_lines
	return best


func _prefer_dialogue_word_break(text: String, fitting_length: int) -> int:
	if fitting_length >= text.length():
		return fitting_length
	var earliest_break := int(fitting_length * 0.5)
	for index in range(fitting_length - 1, earliest_break - 1, -1):
		if " \t\r\n".contains(text.substr(index, 1)):
			return index + 1
	return fitting_length


func _on_owner_dialogue_label_resized() -> void:
	if (
		owner_dialogue_full_text.is_empty()
		or owner_dialogue_label.size.x <= 1.0
		or is_equal_approx(owner_dialogue_label.size.x, owner_dialogue_layout_width)
		or owner_dialogue_repagination_queued
	):
		return
	owner_dialogue_repagination_queued = true
	call_deferred("_repaginate_owner_dialogue_after_resize", owner_dialogue_generation)


func _repaginate_owner_dialogue_after_resize(expected_generation: int) -> void:
	owner_dialogue_repagination_queued = false
	if expected_generation != owner_dialogue_generation or owner_dialogue_full_text.is_empty():
		return
	_present_owner_dialogue(owner_dialogue_full_text, true)


func _play_owner_dialogue_voice() -> void:
	var owner := QuestArcCatalog.owner_for_store(store_id)
	if owner == null or owner.dialogue_voice_streams.is_empty():
		return
	var player := owner_dialogue_voice_players[
		owner_dialogue_voice_index % owner_dialogue_voice_players.size()
	] as AudioStreamPlayer
	player.stream = owner.dialogue_voice_streams[
		owner_dialogue_voice_index % owner.dialogue_voice_streams.size()
	]
	player.pitch_scale = owner.dialogue_voice_pitch_scale
	player.volume_db = owner.dialogue_voice_volume_db
	player.play()
	owner_dialogue_voice_index += 1


func _stop_owner_dialogue_voice() -> void:
	for player in owner_dialogue_voice_players:
		player.stop()


func _is_dialogue_voice_character(character: String) -> bool:
	return not character.is_empty() and not DIALOGUE_SILENT_CHARACTERS.contains(character)


func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return
	accept_event()
	_on_owner_pressed()


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	if transaction == null:
		return
	for slot_id in shelf_buttons:
		var view_index := shelf_view_slot_ids.find(slot_id)
		if view_index >= 0:
			_apply_shelf_highlight(
				shelf_views[view_index], transaction.shelf_slot(slot_id)
			)


func _apply_shelf_highlight(view: Dictionary, slot: ShelfSlotState) -> void:
	if view.is_empty():
		return
	var card_view := view.card as CardHandCard
	var selection_outline := view.selection_outline as Panel
	var definition := (
		QuestArcCatalog.item_by_id(slot.item_id)
		if slot != null and not slot.is_empty()
		else null
	)
	var matches: bool = (
		highlight_rule != null
		and definition != null
		and CardRuleEvaluator.can_place(highlight_rule, definition)
	)
	card_view.apply_match_highlight(matches)
	var selected := slot != null and transaction.is_selected(slot.slot_id)
	if not selected:
		selection_outline.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color.TRANSPARENT
	selected_style.border_color = Color("f0dc9f", 0.96)
	selected_style.set_border_width_all(2)
	selected_style.set_corner_radius_all(6)
	selected_style.shadow_color = Color("f0dc9f", 0.28)
	selected_style.shadow_size = 5
	selection_outline.add_theme_stylebox_override("panel", selected_style)


func _on_checkout_pressed() -> void:
	var result := state.checkout_store(store_id)
	feedback_label.text = TranslationServer.translate(
		&"quest.ui.shop.done" if result.ok
		else &"quest.ui.shop.no_money" if result.reason == CardShopTransaction.RESULT_INSUFFICIENT_FUNDS
		else &"quest.ui.shop.empty"
	)
	if result.ok:
		checkout_completed.emit()
		_refresh_shelf()
		talk_request_dot.visible = state.owner_request_notice_visible(store_id)
	_refresh_checkout_state()


func _owner_texture() -> Texture2D:
	return QuestStoreVisuals.owner_texture(store_id)


func _owner_portrait_rect() -> Rect2:
	if OWNER_PORTRAIT_RECTS.has(store_id):
		return OWNER_PORTRAIT_RECTS[store_id] as Rect2
	return Rect2(
		0.595,
		0.18,
		0.275,
		0.92 if store_id in LOWERED_OWNER_STORES else 0.855,
	)


func _store_background_texture() -> Texture2D:
	return QuestStoreVisuals.background_texture(store_id)


func _on_locale_changed(_locale: String) -> void:
	refresh()
