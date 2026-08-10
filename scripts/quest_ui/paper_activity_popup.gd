class_name PaperActivityPopup
extends PanelContainer

signal closed

var title_label: Label
var body_margin: MarginContainer
var body_label: Label
var slots_row: HBoxContainer
var feedback_label: Label
var action_button: Button


func _ready() -> void:
	anchor_left = 0.18
	anchor_top = 0.10
	anchor_right = 0.82
	anchor_bottom = 0.82
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiPalette.paper_style())

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	title_label = Label.new()
	title_label.name = "PopupTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color("302a22"))
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 34)
	close_button.pressed.connect(closed.emit)
	header.add_child(close_button)

	body_margin = MarginContainer.new()
	column.add_child(body_margin)
	body_label = Label.new()
	body_label.name = "PopupBody"
	body_label.custom_minimum_size = Vector2(0, 72)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color("4d4437"))
	body_margin.add_child(body_label)

	slots_row = HBoxContainer.new()
	slots_row.name = "PopupSlots"
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_row.add_theme_constant_override("separation", 14)
	column.add_child(slots_row)

	feedback_label = Label.new()
	feedback_label.name = "PopupFeedback"
	feedback_label.custom_minimum_size = Vector2(0, 34)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color("76592f"))
	column.add_child(feedback_label)

	action_button = Button.new()
	action_button.name = "PopupActionButton"
	action_button.custom_minimum_size = Vector2(180, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(action_button)
