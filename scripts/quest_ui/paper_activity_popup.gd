class_name PaperActivityPopup
extends PanelContainer

signal closed

const BODY_HEIGHT := 112.0
const LETTER_BODY_HEIGHT := 144.0
const BODY_FONT_SIZE := 15
const BODY_MIN_FONT_SIZE := 11
const BODY_MAX_LINES := 5
const LETTER_BODY_MAX_LINES := 7

var title_label: Label
var drag_handle: HBoxContainer
var body_viewport: Control
var body_margin: MarginContainer
var body_label: Label
var lower_spacer: Control
var slots_row: HBoxContainer
var feedback_label: Label
var action_button: Button
var body_fit_queued := false
var body_max_lines := BODY_MAX_LINES
var dragging := false


func _ready() -> void:
	# This popup lives inside ContentViewport. It shares the shop shelf's left
	# edge and maps to the same fixed visual rectangle as the global task paper.
	anchor_left = 0.035
	anchor_top = 0.05
	anchor_right = 0.425
	anchor_bottom = 0.895
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiPalette.paper_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	drag_handle = HBoxContainer.new()
	drag_handle.name = "PopupHeader"
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	column.add_child(drag_handle)
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

	body_viewport = Control.new()
	body_viewport.name = "PopupBodyViewport"
	body_viewport.custom_minimum_size = Vector2(0, BODY_HEIGHT)
	body_viewport.clip_contents = true
	body_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body_viewport)
	body_margin = MarginContainer.new()
	body_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_margin.add_theme_constant_override("margin_left", 12)
	body_margin.add_theme_constant_override("margin_right", 12)
	body_viewport.add_child(body_margin)
	body_label = Label.new()
	body_label.name = "PopupBody"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	body_label.add_theme_color_override("font_color", Color("4d4437"))
	body_margin.add_child(body_label)

	lower_spacer = Control.new()
	lower_spacer.name = "PopupLowerSpacer"
	lower_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(lower_spacer)

	slots_row = HBoxContainer.new()
	slots_row.name = "PopupSlots"
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.size_flags_vertical = Control.SIZE_SHRINK_END
	slots_row.add_theme_constant_override("separation", 14)
	column.add_child(slots_row)

	feedback_label = Label.new()
	feedback_label.name = "PopupFeedback"
	feedback_label.custom_minimum_size = Vector2(0, 24)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("76592f"))
	column.add_child(feedback_label)

	action_button = Button.new()
	action_button.name = "PopupActionButton"
	action_button.custom_minimum_size = Vector2(180, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(action_button)
	set_process_input(false)


func _input(event: InputEvent) -> void:
	if not dragging:
		return
	var release := event as InputEventMouseButton
	if (
		release != null
		and release.button_index == MOUSE_BUTTON_LEFT
		and not release.pressed
	):
		_stop_dragging()
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var target := position + motion.relative
	var maximum := Vector2(
		maxf(0.0, parent_control.size.x - size.x),
		maxf(0.0, parent_control.size.y - size.y),
	)
	position = Vector2(
		clampf(target.x, 0.0, maximum.x),
		clampf(target.y, 0.0, maximum.y),
	)
	get_viewport().set_input_as_handled()


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if (
		press == null
		or press.button_index != MOUSE_BUTTON_LEFT
		or not press.pressed
	):
		return
	dragging = true
	set_process_input(true)
	drag_handle.accept_event()


func _stop_dragging() -> void:
	dragging = false
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and dragging:
		_stop_dragging()


func set_body_height(height: float) -> void:
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


func _fit_body_copy_after_layout() -> void:
	await get_tree().process_frame
	body_fit_queued = false
	ItemDetailPopup.fit_label_font(
		body_label,
		BODY_FONT_SIZE,
		BODY_MIN_FONT_SIZE,
		body_max_lines,
	)
