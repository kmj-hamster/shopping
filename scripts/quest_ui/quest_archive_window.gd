class_name QuestArchiveWindow
extends Control

signal closed

const SOURCE_SIZE := Vector2(797, 516)
const WINDOW_SIZE := Vector2(531, 344)
const ART_SCALE := WINDOW_SIZE.x / SOURCE_SIZE.x
const TITLE_RECT := Rect2(Vector2(116, 55) * ART_SCALE, Vector2(440, 76) * ART_SCALE)
const TITLE_FONT_SIZE := 19
const BODY_BORDER_RECT := Rect2(
	Vector2(116, 144) * ART_SCALE,
	Vector2(563, 269) * ART_SCALE,
)
const BODY_FONT_SIZE := 15
const BODY_EN_FONT_SIZE := 13
const BODY_HORIZONTAL_INSET := BODY_FONT_SIZE * 2
const BODY_VERTICAL_INSET := BODY_FONT_SIZE
const BODY_TEXT_RECT := Rect2(
	BODY_BORDER_RECT.position + Vector2(BODY_HORIZONTAL_INSET, BODY_VERTICAL_INSET),
	BODY_BORDER_RECT.size - Vector2(BODY_HORIZONTAL_INSET * 2, BODY_VERTICAL_INSET * 2),
)
const CLOSE_RECT := Rect2(Vector2(696, 2) * ART_SCALE, Vector2(73, 77) * ART_SCALE)
const PAPER_TEXTURE := preload("res://resources/ui/archive/archive-paper.png")
const CLOSE_TEXTURE := preload("res://resources/ui/archive/archive-close.png")
const TEXT_COLOR := Color("e3e3da")
const TITLE_COLOR := Color("d1d4ce")

var definition: ArchiveEntryDefinition
var paper_background: TextureRect
var title_label: Label
var body_viewport: Control
var body_label: Label
var close_button: TextureButton
var dragging := false
var drag_bounds_control: Control
var drag_grab_offset := Vector2.ZERO


func setup(entry_definition: ArchiveEntryDefinition) -> void:
	definition = entry_definition
	if is_node_ready():
		refresh()


func _ready() -> void:
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -WINDOW_SIZE.x * 0.5
	offset_top = -WINDOW_SIZE.y * 0.5
	offset_right = WINDOW_SIZE.x * 0.5
	offset_bottom = WINDOW_SIZE.y * 0.5
	custom_minimum_size = WINDOW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	gui_input.connect(_on_popup_gui_input)

	paper_background = TextureRect.new()
	paper_background.name = "ArchivePaperArtwork"
	paper_background.texture = PAPER_TEXTURE
	paper_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_background.stretch_mode = TextureRect.STRETCH_SCALE
	paper_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper_background)

	title_label = Label.new()
	title_label.name = "ArchiveTitle"
	title_label.position = TITLE_RECT.position
	title_label.size = TITLE_RECT.size
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.add_theme_color_override("font_color", TITLE_COLOR)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	body_viewport = Control.new()
	body_viewport.name = "ArchiveBodyViewport"
	body_viewport.position = BODY_TEXT_RECT.position
	body_viewport.size = BODY_TEXT_RECT.size
	body_viewport.clip_contents = true
	body_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body_viewport)

	body_label = Label.new()
	body_label.name = "ArchiveBody"
	body_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.add_theme_color_override("font_color", TEXT_COLOR)
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_viewport.add_child(body_label)

	close_button = TextureButton.new()
	close_button.name = "ArchiveCloseButton"
	close_button.texture_normal = CLOSE_TEXTURE
	close_button.texture_hover = CLOSE_TEXTURE
	close_button.texture_pressed = CLOSE_TEXTURE
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_button.position = CLOSE_RECT.position
	close_button.size = CLOSE_RECT.size
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.tooltip_text = ""
	close_button.pressed.connect(closed.emit)
	add_child(close_button)

	LocaleManager.locale_changed.connect(_on_locale_changed)
	var window := get_window()
	if window != null:
		window.focus_exited.connect(_stop_dragging)
	refresh()
	call_deferred("_constrain_to_drag_bounds")


func refresh() -> void:
	if definition == null or title_label == null:
		return
	title_label.text = definition.localized_title()
	body_label.text = definition.localized_body()
	body_label.add_theme_font_size_override(
		"font_size",
		BODY_EN_FONT_SIZE
		if LocaleManager.current_locale == LocaleManager.LOCALE_EN
		else BODY_FONT_SIZE,
	)


func _on_locale_changed(_locale: String) -> void:
	refresh()


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
		call_deferred("_constrain_to_drag_bounds")


func _on_drag_bounds_resized() -> void:
	if is_node_ready():
		call_deferred("_constrain_to_drag_bounds")


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
	elif what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_constrain_to_drag_bounds")
	elif what == NOTIFICATION_EXIT_TREE and dragging:
		_stop_dragging()
