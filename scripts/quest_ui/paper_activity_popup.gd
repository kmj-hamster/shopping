class_name PaperActivityPopup
extends PanelContainer

signal closed

const BODY_HEIGHT := 112.0
const LETTER_BODY_HEIGHT := 144.0
const BODY_FONT_SIZE := 15
const BODY_MIN_FONT_SIZE := 11
const BODY_MAX_LINES := 5
const LETTER_BODY_MAX_LINES := 7
const PAPER_ANCHOR_LEFT := 0.035
const PAPER_ANCHOR_TOP := 0.05
const PAPER_ANCHOR_RIGHT := 0.91
const PAPER_ANCHOR_BOTTOM := 0.58

var title_label: Label
var drag_handle: HBoxContainer
var content_row: HBoxContainer
var text_column: VBoxContainer
var interaction_column: VBoxContainer
var interaction_footer_row: HBoxContainer
var body_viewport: Control
var body_margin: MarginContainer
var body_label: Label
var footer_label: Label
var lower_spacer: Control
var slots_row: HBoxContainer
var feedback_label: Label
var action_button: Button
var body_fit_queued := false
var body_max_lines := BODY_MAX_LINES
var body_requested_height := BODY_HEIGHT
var dragging := false
var drag_bounds_control: Control
var drag_grab_offset := Vector2.ZERO
var applying_preferred_size := false


func _ready() -> void:
	# Task and location popups share viewport-local anchors; their explicit
	# drag-bounds control decides which visible paper region contains them.
	anchor_left = PAPER_ANCHOR_LEFT
	anchor_top = PAPER_ANCHOR_TOP
	anchor_right = PAPER_ANCHOR_RIGHT
	anchor_bottom = PAPER_ANCHOR_BOTTOM
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_popup_gui_input)
	add_theme_stylebox_override("panel", UiPalette.paper_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var paper_column := VBoxContainer.new()
	paper_column.name = "PopupPaperColumn"
	paper_column.mouse_filter = Control.MOUSE_FILTER_PASS
	paper_column.add_theme_constant_override("separation", 8)
	margin.add_child(paper_column)

	drag_handle = HBoxContainer.new()
	drag_handle.name = "PopupHeader"
	drag_handle.mouse_filter = Control.MOUSE_FILTER_PASS
	paper_column.add_child(drag_handle)
	var title_balance := Control.new()
	title_balance.name = "TitleBalance"
	title_balance.custom_minimum_size = Vector2(38, 34)
	title_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_handle.add_child(title_balance)
	title_label = Label.new()
	title_label.name = "PopupTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color("302a22"))
	drag_handle.add_child(title_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 34)
	close_button.pressed.connect(closed.emit)
	drag_handle.add_child(close_button)

	content_row = HBoxContainer.new()
	content_row.name = "PopupContentRow"
	content_row.mouse_filter = Control.MOUSE_FILTER_PASS
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	paper_column.add_child(content_row)

	text_column = VBoxContainer.new()
	text_column.name = "PopupLetterColumn"
	text_column.mouse_filter = Control.MOUSE_FILTER_PASS
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_stretch_ratio = 1.35
	text_column.add_theme_constant_override("separation", 6)
	content_row.add_child(text_column)

	body_viewport = Control.new()
	body_viewport.name = "PopupBodyViewport"
	body_viewport.custom_minimum_size = Vector2(0, BODY_HEIGHT)
	body_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_viewport.clip_contents = true
	body_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(body_viewport)
	body_margin = MarginContainer.new()
	body_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_margin.add_theme_constant_override("margin_left", 12)
	body_margin.add_theme_constant_override("margin_right", 12)
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

	var divider := ColorRect.new()
	divider.name = "PopupColumnDivider"
	divider.color = Color("8d7654", 0.34)
	divider.custom_minimum_size = Vector2(1, 0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(divider)

	interaction_column = VBoxContainer.new()
	interaction_column.name = "PopupInteractionColumn"
	interaction_column.mouse_filter = Control.MOUSE_FILTER_PASS
	interaction_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_column.add_theme_constant_override("separation", 8)
	content_row.add_child(interaction_column)

	slots_row = HBoxContainer.new()
	slots_row.name = "PopupSlots"
	slots_row.mouse_filter = Control.MOUSE_FILTER_PASS
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots_row.add_theme_constant_override("separation", 14)
	interaction_column.add_child(slots_row)

	lower_spacer = Control.new()
	lower_spacer.name = "PopupLowerSpacer"
	lower_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_column.add_child(lower_spacer)

	interaction_footer_row = HBoxContainer.new()
	interaction_footer_row.name = "PopupInteractionFooter"
	interaction_footer_row.mouse_filter = Control.MOUSE_FILTER_PASS
	interaction_footer_row.add_theme_constant_override("separation", 10)
	interaction_column.add_child(interaction_footer_row)

	feedback_label = Label.new()
	feedback_label.name = "PopupFeedback"
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label.custom_minimum_size = Vector2(0, 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("76592f"))
	feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_footer_row.add_child(feedback_label)

	action_button = Button.new()
	action_button.name = "PopupActionButton"
	action_button.custom_minimum_size = Vector2(180, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	interaction_footer_row.add_child(action_button)
	var window := get_window()
	if window != null:
		window.focus_exited.connect(_stop_dragging)
	call_deferred("_apply_preferred_size")


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
	set_body_height(height)
	body_max_lines = maximum_lines
	body_label.text = text
	body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
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
	ItemDetailPopup.fit_label_font(
		body_label,
		BODY_FONT_SIZE,
		BODY_MIN_FONT_SIZE,
		body_max_lines,
	)
	await get_tree().process_frame
	var font_size := body_label.get_theme_font_size("font_size")
	var font := body_label.get_theme_font("font")
	var overflow_lines := maxi(0, body_label.get_line_count() - body_max_lines)
	body_viewport.custom_minimum_size.y = (
		body_requested_height + ceilf(overflow_lines * font.get_height(font_size))
	)
	body_fit_queued = false
	call_deferred("_apply_preferred_size")
