class_name QuestExpeditionConfirmationPopup
extends Control

signal confirmed

const POPUP_SIZE := QuestArchiveWindow.WINDOW_SIZE
const PAPER_TEXTURE := preload("res://resources/ui/archive/archive-paper.png")
const TITLE_COLOR := Color("e8e3d1")
const COPY_COLOR := Color("ddd7c4")
const SECONDARY_COPY_COLOR := Color("beb8a6")
const COPY_COLUMN_RECT := Rect2(104, 105, 323, 120)
const PRIMARY_COPY_RECT := Rect2(0, 4, 323, 48)
const HINT_COPY_RECT := Rect2(0, 53, 323, 51)
const WARNING_PRIMARY_COPY_RECT := Rect2(0, 0, 323, 37)
const WARNING_HINT_COPY_RECT := Rect2(0, 38, 323, 29)
const WARNING_COPY_RECT := Rect2(0, 68, 323, 52)
const ACTIONS_RECT := Rect2(130, 229, 271, 42)
const PRIMARY_FONT_SIZE := 16
const HINT_FONT_SIZE := 12
const WARNING_FONT_SIZE := 10
const COMPACT_PRIMARY_FONT_SIZE := 14
const COMPACT_HINT_FONT_SIZE := 11

var dialog_text := ""
var hint_text := ""
var warning_text := ""
var title_label: Label
var primary_label: Label
var hint_label: Label
var warning_label: Label
var paper_panel: TextureRect
var confirm_button: Button
var cancel_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP

	paper_panel = TextureRect.new()
	paper_panel.name = "ExpeditionArchivePaper"
	paper_panel.texture = PAPER_TEXTURE
	paper_panel.anchor_left = 0.5
	paper_panel.anchor_top = 0.5
	paper_panel.anchor_right = 0.5
	paper_panel.anchor_bottom = 0.5
	paper_panel.offset_left = -POPUP_SIZE.x * 0.5
	paper_panel.offset_top = -POPUP_SIZE.y * 0.5
	paper_panel.offset_right = POPUP_SIZE.x * 0.5
	paper_panel.offset_bottom = POPUP_SIZE.y * 0.5
	paper_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_panel.stretch_mode = TextureRect.STRETCH_SCALE
	paper_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(paper_panel)

	title_label = _copy_label(23, TITLE_COLOR)
	title_label.name = "Title"
	title_label.position = Vector2(86, 34)
	title_label.size = Vector2(359, 42)
	paper_panel.add_child(title_label)

	var copy_column := Control.new()
	copy_column.name = "CenteredCopy"
	copy_column.position = COPY_COLUMN_RECT.position
	copy_column.size = COPY_COLUMN_RECT.size
	copy_column.clip_contents = true
	copy_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_panel.add_child(copy_column)

	primary_label = _copy_label(PRIMARY_FONT_SIZE, COPY_COLOR)
	primary_label.name = "PrimaryCopy"
	primary_label.position = PRIMARY_COPY_RECT.position
	primary_label.size = PRIMARY_COPY_RECT.size
	copy_column.add_child(primary_label)

	hint_label = _copy_label(HINT_FONT_SIZE, SECONDARY_COPY_COLOR)
	hint_label.name = "HintCopy"
	hint_label.position = HINT_COPY_RECT.position
	hint_label.size = HINT_COPY_RECT.size
	copy_column.add_child(hint_label)

	warning_label = _copy_label(WARNING_FONT_SIZE, Color("e2a498"))
	warning_label.name = "WarningCopy"
	warning_label.position = WARNING_COPY_RECT.position
	warning_label.size = WARNING_COPY_RECT.size
	copy_column.add_child(warning_label)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.position = ACTIONS_RECT.position
	actions.size = ACTIONS_RECT.size
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 23)
	paper_panel.add_child(actions)

	cancel_button = _action_button(false)
	cancel_button.name = "CancelButton"
	cancel_button.pressed.connect(hide)
	actions.add_child(cancel_button)
	confirm_button = _action_button(true)
	confirm_button.name = "ConfirmButton"
	confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(confirm_button)

	visible = false


func set_copy(
	title: String,
	primary: String,
	hint: String,
	warning: String,
	confirm_text: String,
	cancel_text: String,
) -> void:
	dialog_text = primary
	hint_text = hint
	warning_text = warning
	if title_label == null:
		return
	title_label.text = title
	primary_label.text = primary
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()
	warning_label.text = warning
	warning_label.visible = not warning.is_empty()
	_layout_copy(not warning.is_empty())
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text


func _layout_copy(has_warning: bool) -> void:
	primary_label.position = (
		WARNING_PRIMARY_COPY_RECT.position if has_warning else PRIMARY_COPY_RECT.position
	)
	primary_label.size = (
		WARNING_PRIMARY_COPY_RECT.size if has_warning else PRIMARY_COPY_RECT.size
	)
	primary_label.add_theme_font_size_override(
		"font_size", COMPACT_PRIMARY_FONT_SIZE if has_warning else PRIMARY_FONT_SIZE
	)
	hint_label.position = WARNING_HINT_COPY_RECT.position if has_warning else HINT_COPY_RECT.position
	hint_label.size = WARNING_HINT_COPY_RECT.size if has_warning else HINT_COPY_RECT.size
	hint_label.add_theme_font_size_override(
		"font_size", COMPACT_HINT_FONT_SIZE if has_warning else HINT_FONT_SIZE
	)


func popup_centered(_requested_size := Vector2i.ZERO) -> void:
	visible = true
	move_to_front()
	confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()


func _copy_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _action_button(is_primary: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(124, 35)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("e4deca"))
	button.add_theme_color_override("font_hover_color", Color("fffbed"))
	button.add_theme_stylebox_override(
		"normal",
		_button_style(
			Color("d9d0b5", 0.17 if is_primary else 0.09),
			Color("d9d0b5", 0.48 if is_primary else 0.30),
		),
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(Color("eee5ca", 0.25), Color("eee5ca", 0.72)),
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(Color("b8ad90", 0.22), Color("f2e8cc", 0.78)),
	)
	button.add_theme_stylebox_override(
		"focus",
		_button_style(Color("d9d0b5", 0.19), Color("e5d9b9", 0.62)),
	)
	return button


func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := UiPalette.round_button_style(color, border, 6)
	style.set_border_width_all(1)
	return style
