class_name PaperActivityPopup
extends PanelContainer

signal closed

const BODY_HEIGHT := 112.0
const LETTER_BODY_HEIGHT := 144.0
const BODY_FONT_SIZE := 15
const BODY_MAX_LINES := 5
const LETTER_BODY_MAX_LINES := 7
const PAPER_ANCHOR_LEFT := 0.167
const PAPER_ANCHOR_TOP := 0.064
const PAPER_ANCHOR_RIGHT := 0.652
const PAPER_ANCHOR_BOTTOM := 0.691
const PAPER_SIZE := Vector2(531, 344)
const INTERACTION_POSITION := Vector2(333, 112)
const INTERACTION_SEPARATION := 4
const ACTION_GAP_HEIGHT := 28.0
const SLOT_ART_INSET_RECT := Rect2(350, 94, 112, 138)
const PAPER_TEXTURE := preload("res://resources/ui/quest/task-paper.png")
const CLOSE_TEXTURE := preload("res://resources/ui/quest/task-close.png")
const CONFIRM_TEXTURE := preload("res://resources/ui/quest/task-confirm.png")
const COMPLETED_TEXTURE := preload("res://resources/ui/quest/task-completed.png")
const PAGER_ARROW_TEXTURE := preload("res://resources/ui/quest/pager-arrow.png")

var title_label: Label
var drag_handle: HBoxContainer
var paper_background: TextureRect
var close_button: TextureButton
var content_row: Control
var letter_panel: PanelContainer
var text_column: VBoxContainer
var interaction_column: VBoxContainer
var interaction_footer_row: HBoxContainer
var body_viewport: Control
var body_margin: MarginContainer
var body_label: Label
var footer_label: Label
var body_page_row: HBoxContainer
var body_previous_button: TextureButton
var body_page_spacer: Control
var body_next_button: TextureButton
var action_gap_spacer: Control
var lower_spacer: Control
var slots_row: HBoxContainer
var feedback_label: Label
var action_button: Button
var body_fit_queued := false
var body_max_lines := BODY_MAX_LINES
var body_requested_height := BODY_HEIGHT
var body_full_text := ""
var body_pages: Array[String] = []
var body_page_index := 0
var body_layout_width := -1.0
var dragging := false
var drag_bounds_control: Control
var drag_grab_offset := Vector2.ZERO
var applying_preferred_size := false
var preferred_position_initialized := false


func _ready() -> void:
	# Task and location popups share viewport-local anchors; their explicit
	# drag-bounds control decides which visible paper region contains them.
	anchor_left = PAPER_ANCHOR_LEFT
	anchor_top = PAPER_ANCHOR_TOP
	anchor_right = PAPER_ANCHOR_RIGHT
	anchor_bottom = PAPER_ANCHOR_BOTTOM
	custom_minimum_size = PAPER_SIZE
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_popup_gui_input)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	paper_background = TextureRect.new()
	paper_background.name = "PopupPaperArtwork"
	paper_background.texture = PAPER_TEXTURE
	paper_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_background.stretch_mode = TextureRect.STRETCH_SCALE
	paper_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper_background)

	content_row = Control.new()
	content_row.name = "PopupContent"
	content_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content_row)

	drag_handle = HBoxContainer.new()
	drag_handle.name = "PopupHeader"
	drag_handle.position = Vector2(66, 30)
	drag_handle.size = Vector2(330, 42)
	drag_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	content_row.add_child(drag_handle)
	title_label = Label.new()
	title_label.name = "PopupTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("302a22"))
	drag_handle.add_child(title_label)

	close_button = TextureButton.new()
	close_button.name = "CloseButton"
	close_button.texture_normal = CLOSE_TEXTURE
	close_button.texture_hover = CLOSE_TEXTURE
	close_button.texture_pressed = CLOSE_TEXTURE
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_button.position = Vector2(445, -1)
	close_button.size = Vector2(49, 51)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.tooltip_text = ""
	close_button.pressed.connect(closed.emit)
	content_row.add_child(close_button)

	letter_panel = PanelContainer.new()
	letter_panel.name = "PopupLetterPanel"
	letter_panel.position = Vector2(76, 95)
	letter_panel.size = Vector2(220, 180)
	letter_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	letter_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	content_row.add_child(letter_panel)
	var letter_margin := MarginContainer.new()
	letter_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	letter_margin.add_theme_constant_override("margin_left", 14)
	letter_margin.add_theme_constant_override("margin_right", 14)
	letter_margin.add_theme_constant_override("margin_top", 10)
	letter_margin.add_theme_constant_override("margin_bottom", 6)
	letter_panel.add_child(letter_margin)
	text_column = VBoxContainer.new()
	text_column.name = "PopupLetterColumn"
	text_column.mouse_filter = Control.MOUSE_FILTER_PASS
	text_column.add_theme_constant_override("separation", 4)
	letter_margin.add_child(text_column)

	body_viewport = Control.new()
	body_viewport.name = "PopupBodyViewport"
	body_viewport.custom_minimum_size = Vector2(0, BODY_HEIGHT)
	body_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_viewport.clip_contents = true
	body_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_viewport.resized.connect(_on_body_viewport_resized)
	text_column.add_child(body_viewport)
	body_margin = MarginContainer.new()
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_margin.add_theme_constant_override("margin_left", 0)
	body_margin.add_theme_constant_override("margin_right", 0)
	body_viewport.add_child(body_margin)
	body_label = Label.new()
	body_label.name = "PopupBody"
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	body_label.add_theme_color_override("font_color", Color("4d4437"))
	body_margin.add_child(body_label)
	footer_label = Label.new()
	footer_label.name = "PopupFooter"
	footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_label.custom_minimum_size = Vector2(0, 20)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_font_size_override("font_size", 11)
	footer_label.add_theme_color_override("font_color", Color("6f5d42"))
	footer_label.visible = false
	text_column.add_child(footer_label)
	body_page_row = HBoxContainer.new()
	body_page_row.name = "PopupBodyPager"
	body_page_row.position = Vector2(30, 142)
	body_page_row.size = Vector2(292, 49)
	body_page_row.mouse_filter = Control.MOUSE_FILTER_PASS
	body_page_row.add_theme_constant_override("separation", 0)
	content_row.add_child(body_page_row)
	body_previous_button = _create_pager_button(false)
	body_previous_button.name = "PreviousBodyPageButton"
	body_previous_button.pressed.connect(_on_previous_body_page_pressed)
	body_page_row.add_child(body_previous_button)
	body_page_spacer = Control.new()
	body_page_spacer.name = "BodyPageSpacer"
	body_page_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_page_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_page_row.add_child(body_page_spacer)
	body_next_button = _create_pager_button(true)
	body_next_button.name = "NextBodyPageButton"
	body_next_button.pressed.connect(_on_next_body_page_pressed)
	body_page_row.add_child(body_next_button)

	interaction_column = VBoxContainer.new()
	interaction_column.name = "PopupInteractionColumn"
	interaction_column.position = INTERACTION_POSITION
	interaction_column.size = Vector2(150, 218)
	interaction_column.mouse_filter = Control.MOUSE_FILTER_PASS
	interaction_column.add_theme_constant_override("separation", INTERACTION_SEPARATION)
	content_row.add_child(interaction_column)

	slots_row = HBoxContainer.new()
	slots_row.name = "PopupSlots"
	slots_row.custom_minimum_size = Vector2(0, QuestTaskSlot.CARD_SIZE.y)
	slots_row.mouse_filter = Control.MOUSE_FILTER_PASS
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots_row.add_theme_constant_override("separation", 14)
	interaction_column.add_child(slots_row)

	action_gap_spacer = Control.new()
	action_gap_spacer.name = "PopupActionGap"
	action_gap_spacer.custom_minimum_size = Vector2(0, ACTION_GAP_HEIGHT)
	action_gap_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_column.add_child(action_gap_spacer)

	interaction_footer_row = HBoxContainer.new()
	interaction_footer_row.name = "PopupInteractionFooter"
	interaction_footer_row.custom_minimum_size = Vector2(0, 36)
	interaction_footer_row.mouse_filter = Control.MOUSE_FILTER_PASS
	interaction_footer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_column.add_child(interaction_footer_row)
	var action_left_spacer := Control.new()
	action_left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_footer_row.add_child(action_left_spacer)

	action_button = Button.new()
	action_button.name = "PopupActionButton"
	action_button.custom_minimum_size = Vector2(81, 34)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.icon = CONFIRM_TEXTURE
	action_button.expand_icon = true
	action_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_button.text = ""
	action_button.tooltip_text = ""
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		action_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	action_button.add_theme_color_override("icon_normal_color", Color.WHITE)
	action_button.add_theme_color_override("icon_hover_color", Color(1.08, 1.08, 1.08, 1.0))
	action_button.add_theme_color_override("icon_pressed_color", Color("d8c8bd"))
	action_button.add_theme_color_override("icon_disabled_color", Color(0.46, 0.46, 0.46, 0.62))
	interaction_footer_row.add_child(action_button)
	var action_right_spacer := Control.new()
	action_right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_footer_row.add_child(action_right_spacer)

	feedback_label = Label.new()
	feedback_label.name = "PopupFeedback"
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label.custom_minimum_size = Vector2(0, 20)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("76592f"))
	feedback_label.add_theme_font_size_override("font_size", 11)
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_column.add_child(feedback_label)

	lower_spacer = Control.new()
	lower_spacer.name = "PopupLowerSpacer"
	lower_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_column.add_child(lower_spacer)
	var window := get_window()
	if window != null:
		window.focus_exited.connect(_stop_dragging)
	call_deferred("_apply_preferred_size")


func _create_pager_button(flip_h: bool) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = PAGER_ARROW_TEXTURE
	button.texture_hover = PAGER_ARROW_TEXTURE
	button.texture_pressed = PAGER_ARROW_TEXTURE
	button.texture_disabled = PAGER_ARROW_TEXTURE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.flip_h = flip_h
	button.custom_minimum_size = Vector2(13, 49)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func set_action_visual(completed: bool, enabled: bool) -> void:
	if action_button == null:
		return
	action_button.icon = COMPLETED_TEXTURE if completed else CONFIRM_TEXTURE
	action_button.custom_minimum_size = Vector2(103, 34) if completed else Vector2(81, 34)
	action_button.disabled = not enabled
	action_button.add_theme_color_override(
		"icon_disabled_color",
		Color.WHITE if completed else Color(0.46, 0.46, 0.46, 0.62),
	)


func set_drag_bounds_control(bounds: Control) -> void:
	if (
		drag_bounds_control != null
		and is_instance_valid(drag_bounds_control)
		and drag_bounds_control.resized.is_connected(_on_drag_bounds_resized)
	):
		drag_bounds_control.resized.disconnect(_on_drag_bounds_resized)
	drag_bounds_control = bounds
	if bounds != null and not bounds.resized.is_connected(_on_drag_bounds_resized):
		bounds.resized.connect(_on_drag_bounds_resized)
	if is_node_ready():
		call_deferred("_apply_preferred_size")


func _on_drag_bounds_resized() -> void:
	if is_node_ready():
		call_deferred("_apply_preferred_size")


func _apply_preferred_size() -> void:
	if applying_preferred_size or not is_inside_tree():
		return
	var bounds := _effective_drag_bounds()
	if bounds == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	applying_preferred_size = true
	var local_position := _canvas_position_in(bounds, global_position)
	if not preferred_position_initialized:
		local_position = Vector2(
			bounds.size.x * PAPER_ANCHOR_LEFT,
			bounds.size.y * PAPER_ANCHOR_TOP,
		)
		preferred_position_initialized = true
	var anchored_size := Vector2(
		bounds.size.x * (PAPER_ANCHOR_RIGHT - PAPER_ANCHOR_LEFT),
		bounds.size.y * (PAPER_ANCHOR_BOTTOM - PAPER_ANCHOR_TOP),
	)
	var minimum := get_combined_minimum_size()
	var preferred_size := Vector2(
		maxf(anchored_size.x, minimum.x),
		maxf(anchored_size.y, minimum.y),
	)
	offset_left = local_position.x - bounds.size.x * PAPER_ANCHOR_LEFT
	offset_top = local_position.y - bounds.size.y * PAPER_ANCHOR_TOP
	offset_right = offset_left + preferred_size.x - anchored_size.x
	offset_bottom = offset_top + preferred_size.y - anchored_size.y
	_set_position_in_drag_bounds(local_position, bounds)
	applying_preferred_size = false


func _on_popup_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin_dragging_at(get_global_mouse_position())
		elif dragging:
			_stop_dragging()
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion == null or not dragging:
		return
	if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_stop_dragging()
		return
	_move_to_canvas_position(get_global_mouse_position())
	accept_event()


func _begin_dragging_at(canvas_position: Vector2) -> void:
	var bounds := _effective_drag_bounds()
	if bounds == null:
		return
	dragging = true
	drag_grab_offset = (
		_canvas_position_in(bounds, canvas_position)
		- _canvas_position_in(bounds, global_position)
	)


func _move_to_canvas_position(canvas_position: Vector2) -> void:
	var bounds := _effective_drag_bounds()
	if bounds == null:
		_stop_dragging()
		return
	var target := _canvas_position_in(bounds, canvas_position) - drag_grab_offset
	_set_position_in_drag_bounds(target, bounds)


func _set_position_in_drag_bounds(target: Vector2, bounds: Control) -> void:
	var maximum := Vector2(
		maxf(0.0, bounds.size.x - size.x),
		maxf(0.0, bounds.size.y - size.y),
	)
	var clamped_target := Vector2(
		clampf(target.x, 0.0, maximum.x),
		clampf(target.y, 0.0, maximum.y),
	)
	global_position = bounds.get_global_transform_with_canvas() * clamped_target


func _canvas_position_in(control: Control, canvas_position: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas().affine_inverse() * canvas_position


func _effective_drag_bounds() -> Control:
	if drag_bounds_control != null and is_instance_valid(drag_bounds_control):
		return drag_bounds_control
	return get_parent() as Control


func _constrain_to_drag_bounds() -> void:
	if not is_inside_tree():
		return
	var bounds := _effective_drag_bounds()
	if bounds == null:
		return
	_set_position_in_drag_bounds(_canvas_position_in(bounds, global_position), bounds)


func _stop_dragging() -> void:
	dragging = false
	drag_grab_offset = Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and dragging:
		_stop_dragging()
	elif what == NOTIFICATION_RESIZED and is_node_ready() and not applying_preferred_size:
		call_deferred("_constrain_to_drag_bounds")
	elif what == NOTIFICATION_EXIT_TREE and dragging:
		_stop_dragging()


func set_body_height(height: float) -> void:
	body_requested_height = height
	if body_viewport != null:
		body_viewport.custom_minimum_size.y = height


func set_body_copy(text: String, height: float, maximum_lines: int) -> void:
	var content_changed := body_full_text != text or body_max_lines != maximum_lines
	set_body_height(height)
	body_max_lines = maximum_lines
	body_full_text = text
	body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	body_label.max_lines_visible = body_max_lines
	if content_changed:
		body_page_index = 0
	_queue_body_pagination()


func _queue_body_pagination() -> void:
	if body_fit_queued:
		return
	body_fit_queued = true
	_fit_body_copy_after_layout()


func set_footer_copy(text: String) -> void:
	if footer_label == null:
		return
	footer_label.text = text
	footer_label.visible = not text.is_empty()


func _fit_body_copy_after_layout() -> void:
	await get_tree().process_frame
	if not is_instance_valid(body_label):
		return
	body_pages = _paginate_body_copy(body_full_text)
	body_page_index = clampi(body_page_index, 0, maxi(0, body_pages.size() - 1))
	_update_body_page()
	body_fit_queued = false
	call_deferred("_apply_preferred_size")


func _paginate_body_copy(text: String) -> Array[String]:
	var pages: Array[String] = []
	var remaining := text.strip_edges()
	if remaining.is_empty():
		pages.append("")
		return pages
	if body_label.size.x <= 1.0:
		pages.append(remaining)
		return pages
	while not remaining.is_empty():
		var page_length := _longest_fitting_body_prefix(remaining)
		if page_length <= 0:
			page_length = 1
		page_length = _prefer_body_page_break(remaining, page_length)
		var page_text := remaining.substr(0, page_length).strip_edges()
		if page_text.is_empty():
			page_text = remaining.substr(0, page_length)
		pages.append(page_text)
		remaining = remaining.substr(page_length).strip_edges()
	return pages


func _longest_fitting_body_prefix(text: String) -> int:
	var previous_text := body_label.text
	var previous_max_lines := body_label.max_lines_visible
	body_label.max_lines_visible = -1
	var low := 1
	var high := text.length()
	var best := 0
	while low <= high:
		var midpoint := int((low + high) * 0.5)
		body_label.text = text.substr(0, midpoint)
		if body_label.get_line_count() <= body_max_lines:
			best = midpoint
			low = midpoint + 1
		else:
			high = midpoint - 1
	body_label.text = previous_text
	body_label.max_lines_visible = previous_max_lines
	return best


func _prefer_body_page_break(text: String, fitted_length: int) -> int:
	if fitted_length >= text.length():
		return fitted_length
	var earliest_break := maxi(1, int(fitted_length * 0.62))
	for index in range(fitted_length - 1, earliest_break - 1, -1):
		var character := text.substr(index, 1)
		if character in " \t\r\n，。！？、；：,.!?;:…—-）)":
			return index + 1
	return fitted_length


func _update_body_page() -> void:
	if body_pages.is_empty():
		body_pages = [""]
	body_page_index = clampi(body_page_index, 0, body_pages.size() - 1)
	body_label.text = body_pages[body_page_index]
	body_previous_button.disabled = body_page_index <= 0
	body_next_button.disabled = body_page_index >= body_pages.size() - 1
	body_previous_button.modulate.a = 0.28 if body_previous_button.disabled else 0.82
	body_next_button.modulate.a = 0.28 if body_next_button.disabled else 0.82


func _on_previous_body_page_pressed() -> void:
	if body_page_index <= 0:
		return
	body_page_index -= 1
	_update_body_page()


func _on_next_body_page_pressed() -> void:
	if body_page_index >= body_pages.size() - 1:
		return
	body_page_index += 1
	_update_body_page()


func _on_body_viewport_resized() -> void:
	if not is_node_ready() or is_equal_approx(body_layout_width, body_viewport.size.x):
		return
	body_layout_width = body_viewport.size.x
	_queue_body_pagination()
