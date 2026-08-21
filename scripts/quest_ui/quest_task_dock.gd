class_name QuestTaskDock
extends Control

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

const RECEIPT_WIDTH := 264.0
const RECEIPT_COLLAPSED_HEIGHT := 192.0
const RECEIPT_EXPANDED_HEIGHT := 477.0
const TASKS_PER_PAGE := 5
const TASK_LINE_HEIGHT := 33.0
const TASK_HIT_HEIGHT := 22.0
const TASK_TEXT_MAX_WIDTH := 174.0
const TASK_HOVER_COLOR := Color("446979")
const TASK_GLOW_COLOR := Color("789cab", 0.55)
const NIGHT_VALUE_COLOR := Color("47496f")
const MONEY_VALUE_COLOR := Color("805c36")
const STATUS_FONT_SIZE := 15
const STATUS_TEXT_VERTICAL_SHIFT := -STATUS_FONT_SIZE * 1.0
const NIGHT_LABEL_RECT := Rect2(18, 39 + STATUS_TEXT_VERTICAL_SHIFT, 78, 50)
const MONEY_LABEL_RECT := Rect2(103, 39 + STATUS_TEXT_VERTICAL_SHIFT, 82, 50)
const TODO_EXPANDED_PATH := "res://resources/ui/shell/todo-expanded.png"
const TODO_COLLAPSED_PATH := "res://resources/ui/shell/todo-collapsed.png"
const PAGER_ARROW_TEXTURE := preload("res://resources/ui/quest/pager-arrow.png")

var state: QuestGameState
var receipt_host: Control
var receipt_background: TextureRect
var receipt_day_label: Label
var receipt_money_label: Label
var receipt_toggle_icon: TextureRect
var bookmark_column: Control
var page_navigation: HBoxContainer
var page_previous_button: TextureButton
var page_next_button: TextureButton
var popup_host: Control
var task_window: QuestTaskWindow
var archive_window: QuestArchiveWindow
var open_task_instance_id := 0
var open_archive_entry_id: StringName
var bookmark_buttons: Dictionary = {}
var archive_buttons: Dictionary = {}
var task_windows: Dictionary = {}
var ordered_task_instance_ids: Array[int] = []
var ordered_entry_buttons: Array[Button] = []
var task_page_index := 0
var is_expanded := false


func setup(game_state: QuestGameState, task_popup_host: Control = null) -> void:
	if state != null and state.state_delta.is_connected(_on_state_delta):
		state.state_delta.disconnect(_on_state_delta)
	state = game_state
	popup_host = task_popup_host
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)
	if is_node_ready():
		refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	receipt_host = Control.new()
	receipt_host.name = "TodoReceipt"
	receipt_host.position = Vector2.ZERO
	receipt_host.size = Vector2(RECEIPT_WIDTH, RECEIPT_EXPANDED_HEIGHT)
	receipt_host.mouse_filter = Control.MOUSE_FILTER_STOP
	receipt_host.clip_contents = false
	receipt_host.gui_input.connect(_on_receipt_gui_input)
	add_child(receipt_host)

	receipt_background = TextureRect.new()
	receipt_background.name = "TodoReceiptBackground"
	receipt_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	receipt_background.stretch_mode = TextureRect.STRETCH_SCALE
	receipt_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(receipt_background)

	receipt_day_label = Label.new()
	receipt_day_label.name = "TodoReceiptDayValue"
	receipt_day_label.position = NIGHT_LABEL_RECT.position
	receipt_day_label.size = NIGHT_LABEL_RECT.size
	receipt_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	receipt_day_label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	receipt_day_label.add_theme_color_override("font_color", NIGHT_VALUE_COLOR)
	receipt_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(receipt_day_label)

	receipt_money_label = Label.new()
	receipt_money_label.name = "TodoReceiptMoney"
	receipt_money_label.position = MONEY_LABEL_RECT.position
	receipt_money_label.size = MONEY_LABEL_RECT.size
	receipt_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	receipt_money_label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	receipt_money_label.add_theme_color_override("font_color", MONEY_VALUE_COLOR)
	receipt_money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(receipt_money_label)

	bookmark_column = Control.new()
	bookmark_column.name = "TodoTaskColumn"
	bookmark_column.position = Vector2(22, 101)
	bookmark_column.size = Vector2(TASK_TEXT_MAX_WIDTH, TASKS_PER_PAGE * TASK_LINE_HEIGHT)
	bookmark_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(bookmark_column)

	page_navigation = HBoxContainer.new()
	page_navigation.name = "TodoPageNavigation"
	page_navigation.position = Vector2(74, 298)
	page_navigation.size = Vector2(116, 49)
	page_navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	page_navigation.add_theme_constant_override("separation", 72)
	receipt_host.add_child(page_navigation)
	page_previous_button = _create_page_button(false)
	page_previous_button.name = "TodoPreviousPage"
	page_previous_button.pressed.connect(_on_previous_page_pressed)
	page_navigation.add_child(page_previous_button)
	page_next_button = _create_page_button(true)
	page_next_button.name = "TodoNextPage"
	page_next_button.pressed.connect(_on_next_page_pressed)
	page_navigation.add_child(page_next_button)

	receipt_toggle_icon = TextureRect.new()
	receipt_toggle_icon.name = "TodoToggleIcon"
	receipt_toggle_icon.texture = PAGER_ARROW_TEXTURE
	receipt_toggle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	receipt_toggle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	receipt_toggle_icon.size = Vector2(13, 49)
	receipt_toggle_icon.pivot_offset = receipt_toggle_icon.size * 0.5
	receipt_toggle_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_host.add_child(receipt_toggle_icon)

	LocaleManager.locale_changed.connect(_on_locale_changed)
	_set_expanded(false)
	refresh()


func refresh() -> void:
	if state == null or bookmark_column == null:
		return
	_refresh_money()
	var active_tasks := state.active_tasks()
	var desired_ids: Array[int] = []
	for task in active_tasks:
		desired_ids.append(task.instance_id)
	for raw_instance_id in bookmark_buttons.keys().duplicate():
		var instance_id := int(raw_instance_id)
		if desired_ids.has(instance_id):
			continue
		var obsolete := bookmark_buttons[instance_id] as Button
		bookmark_buttons.erase(instance_id)
		if obsolete != null:
			obsolete.visible = false
			obsolete.queue_free()
	for index in active_tasks.size():
		var task := active_tasks[index]
		var bookmark := bookmark_buttons.get(task.instance_id) as Button
		if bookmark == null:
			bookmark = _create_bookmark(task.instance_id)
			bookmark_buttons[task.instance_id] = bookmark
		_update_bookmark(bookmark, task)
		if bookmark.get_index() != index:
			bookmark_column.move_child(bookmark, index)
	ordered_task_instance_ids = desired_ids
	ordered_entry_buttons.clear()
	for task in active_tasks:
		var task_button := bookmark_buttons.get(task.instance_id) as Button
		if task_button != null:
			ordered_entry_buttons.append(task_button)
	_refresh_archive_buttons()
	_refresh_task_page()
	_reconcile_task_windows(desired_ids)
	if open_task_instance_id > 0:
		var open_task := state.task_instance(open_task_instance_id)
		if open_task == null or open_task.settled:
			_close_task()
		elif task_window != null:
			task_window.refresh()


func _refresh_money() -> void:
	if state == null or receipt_money_label == null:
		return
	receipt_day_label.text = (
		TranslationServer.translate(&"quest.ui.todo.night") % state.day
	)
	receipt_money_label.text = (
		TranslationServer.translate(&"quest.ui.todo.money") % state.wallet.money
	)


func _create_bookmark(instance_id: int) -> Button:
	var bookmark := _create_entry_button(true)
	bookmark.pressed.connect(_toggle_task.bind(instance_id))
	return bookmark


func _create_archive_bookmark(entry_id: StringName) -> Button:
	var bookmark := _create_entry_button(false)
	bookmark.pressed.connect(_toggle_archive.bind(entry_id))
	return bookmark


func _create_entry_button(underlined: bool) -> Button:
	var bookmark := Button.new()
	bookmark.custom_minimum_size = Vector2(0, TASK_HIT_HEIGHT)
	bookmark.mouse_filter = Control.MOUSE_FILTER_STOP
	bookmark.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bookmark.clip_text = true
	bookmark.tooltip_text = ""
	bookmark.focus_mode = Control.FOCUS_NONE
	bookmark.flat = true
	bookmark.add_theme_font_size_override("font_size", 11)
	var empty_style := StyleBoxEmpty.new()
	for style_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		bookmark.add_theme_stylebox_override(style_name, empty_style)
	_set_bookmark_hovered(bookmark, false)
	bookmark.mouse_entered.connect(_set_bookmark_hovered.bind(bookmark, true))
	bookmark.mouse_exited.connect(_set_bookmark_hovered.bind(bookmark, false))
	if underlined:
		var underline := ColorRect.new()
		underline.name = "QuestUnderline"
		underline.anchor_left = 0.0
		underline.anchor_top = 1.0
		underline.anchor_right = 1.0
		underline.anchor_bottom = 1.0
		underline.offset_left = 2.0
		underline.offset_top = -2.0
		underline.offset_right = -2.0
		underline.offset_bottom = -1.0
		underline.color = UiPalette.INK_COLOR
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bookmark.add_child(underline)
	bookmark_column.add_child(bookmark)
	return bookmark


func _update_bookmark(bookmark: Button, task: TaskInstanceState) -> void:
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	bookmark.text = TranslationServer.translate(definition.display_name_key)
	_resize_bookmark_to_text(bookmark)


func _refresh_archive_buttons() -> void:
	var entries := QuestArcCatalog.archive_entries()
	var desired_ids: Array[StringName] = []
	for entry in entries:
		desired_ids.append(entry.id)
	for raw_entry_id in archive_buttons.keys().duplicate():
		var entry_id := StringName(raw_entry_id)
		if desired_ids.has(entry_id):
			continue
		var obsolete := archive_buttons[raw_entry_id] as Button
		archive_buttons.erase(raw_entry_id)
		if obsolete != null:
			obsolete.visible = false
			obsolete.queue_free()
	for entry in entries:
		var bookmark := archive_buttons.get(entry.id) as Button
		if bookmark == null:
			bookmark = _create_archive_bookmark(entry.id)
			archive_buttons[entry.id] = bookmark
		bookmark.text = entry.localized_title()
		_resize_bookmark_to_text(bookmark)
		var desired_index := ordered_entry_buttons.size()
		if bookmark.get_index() != desired_index:
			bookmark_column.move_child(bookmark, desired_index)
		ordered_entry_buttons.append(bookmark)


func _resize_bookmark_to_text(bookmark: Button) -> void:
	var font := bookmark.get_theme_font("font")
	var font_size := bookmark.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		bookmark.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
	).x
	bookmark.size = Vector2(minf(ceilf(text_width) + 4.0, TASK_TEXT_MAX_WIDTH), TASK_HIT_HEIGHT)


func _set_bookmark_hovered(bookmark: Button, hovered: bool) -> void:
	if bookmark == null:
		return
	var text_color := TASK_HOVER_COLOR if hovered else UiPalette.INK_COLOR
	for color_name in [
		&"font_color",
		&"font_hover_color",
		&"font_pressed_color",
		&"font_focus_color",
		&"font_hover_pressed_color",
	]:
		bookmark.add_theme_color_override(color_name, text_color)
	bookmark.add_theme_color_override(
		"font_outline_color",
		TASK_GLOW_COLOR if hovered else Color.TRANSPARENT,
	)
	bookmark.add_theme_constant_override("outline_size", 3 if hovered else 0)
	var underline := bookmark.get_node_or_null("QuestUnderline") as ColorRect
	if underline != null:
		underline.color = text_color


func _create_page_button(flip_h: bool) -> TextureButton:
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


func _refresh_task_page() -> void:
	var page_count := maxi(1, ceili(float(ordered_entry_buttons.size()) / TASKS_PER_PAGE))
	task_page_index = clampi(task_page_index, 0, page_count - 1)
	var first_index := task_page_index * TASKS_PER_PAGE
	var last_index := mini(first_index + TASKS_PER_PAGE, ordered_entry_buttons.size())
	for index in ordered_entry_buttons.size():
		var bookmark := ordered_entry_buttons[index]
		if bookmark == null:
			continue
		var visible_on_page := index >= first_index and index < last_index
		bookmark.visible = visible_on_page
		if visible_on_page:
			_resize_bookmark_to_text(bookmark)
			var line_index := index - first_index
			bookmark.position = Vector2(
				0,
				line_index * TASK_LINE_HEIGHT + (TASK_LINE_HEIGHT - TASK_HIT_HEIGHT) * 0.5,
			)
	page_previous_button.disabled = task_page_index <= 0
	page_next_button.disabled = task_page_index >= page_count - 1
	page_previous_button.modulate.a = 0.34 if page_previous_button.disabled else 0.88
	page_next_button.modulate.a = 0.34 if page_next_button.disabled else 0.88


func _on_previous_page_pressed() -> void:
	if task_page_index <= 0:
		return
	task_page_index -= 1
	_refresh_task_page()


func _on_next_page_pressed() -> void:
	var page_count := maxi(1, ceili(float(ordered_entry_buttons.size()) / TASKS_PER_PAGE))
	if task_page_index >= page_count - 1:
		return
	task_page_index += 1
	_refresh_task_page()


func _toggle_receipt() -> void:
	_set_expanded(not is_expanded)


func show_drop_targets_for_card(card: CardItemState) -> void:
	if task_window != null and task_window.visible:
		task_window.show_drop_targets_for_card(card)


func clear_drop_target_highlights() -> void:
	if task_window != null:
		task_window.clear_drop_target_highlights()


func _on_receipt_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	_toggle_receipt()
	receipt_host.accept_event()


func _set_expanded(expanded: bool) -> void:
	is_expanded = expanded
	if receipt_host == null:
		return
	var receipt_height := (
		RECEIPT_EXPANDED_HEIGHT if is_expanded else RECEIPT_COLLAPSED_HEIGHT
	)
	# The interactive receipt footprint always keeps the expanded height. This lets
	# the folded receipt reopen from the otherwise invisible paper area below it.
	receipt_host.size = Vector2(RECEIPT_WIDTH, RECEIPT_EXPANDED_HEIGHT)
	receipt_background.size = Vector2(RECEIPT_WIDTH, receipt_height)
	receipt_background.texture = load(
		TODO_EXPANDED_PATH
		if is_expanded
		else TODO_COLLAPSED_PATH
	) as Texture2D
	# Both receipt states expose the same I-shaped status frame in the new art.
	receipt_day_label.visible = true
	receipt_money_label.visible = true
	bookmark_column.visible = is_expanded
	page_navigation.visible = is_expanded
	receipt_toggle_icon.position = Vector2(125.5, 399.5 if is_expanded else 113.5)
	receipt_toggle_icon.rotation = PI * 0.5 if is_expanded else -PI * 0.5


func _toggle_task(instance_id: int) -> void:
	if open_task_instance_id == instance_id:
		_close_task()
		return
	_close_archive()
	_close_task()
	open_task_instance_id = instance_id
	task_window = task_windows.get(instance_id) as QuestTaskWindow
	if task_window == null:
		task_window = QuestTaskWindow.new()
		task_window.setup(state, instance_id)
		task_window.closed.connect(_close_task)
		task_window.rule_focused.connect(rule_focused.emit)
		task_window.item_inspected.connect(item_inspected.emit)
		var host := popup_host if popup_host != null else self
		host.add_child(task_window)
		task_window.set_drag_bounds_control(host)
		task_windows[instance_id] = task_window
	else:
		task_window.refresh()
	task_window.visible = true


func _toggle_archive(entry_id: StringName) -> void:
	if open_archive_entry_id == entry_id and archive_window != null:
		_close_archive()
		return
	_close_archive()
	_close_task()
	var definition := QuestArcCatalog.archive_entry_by_id(entry_id)
	if definition == null:
		return
	open_archive_entry_id = entry_id
	archive_window = QuestArchiveWindow.new()
	archive_window.setup(definition)
	archive_window.closed.connect(_close_archive)
	var host := popup_host if popup_host != null else self
	host.add_child(archive_window)
	archive_window.set_drag_bounds_control(host)


func _close_task() -> void:
	var closing_instance_id := open_task_instance_id
	var closing_window := task_window
	open_task_instance_id = 0
	rule_focused.emit(null)
	task_window = null
	if closing_window != null and is_instance_valid(closing_window):
		closing_window.visible = false
	if state != null and closing_instance_id > 0:
		state.dismiss_claimed_gift_task(closing_instance_id)


func close_open_task() -> void:
	if open_task_instance_id > 0 or task_window != null:
		_close_task()
	if archive_window != null:
		_close_archive()


func _close_archive() -> void:
	open_archive_entry_id = &""
	var closing_window := archive_window
	archive_window = null
	if closing_window != null and is_instance_valid(closing_window):
		closing_window.visible = false
		closing_window.queue_free()


func _reconcile_task_windows(desired_ids: Array[int]) -> void:
	for raw_instance_id in task_windows.keys().duplicate():
		var instance_id := int(raw_instance_id)
		if desired_ids.has(instance_id):
			continue
		var obsolete := task_windows[instance_id] as QuestTaskWindow
		task_windows.erase(instance_id)
		if obsolete != null:
			obsolete.visible = false
			obsolete.queue_free()
		if open_task_instance_id == instance_id:
			open_task_instance_id = 0
			task_window = null
			rule_focused.emit(null)


func _on_state_delta(delta: QuestStateDelta) -> void:
	if delta == null:
		return
	if delta.full_reconcile or delta.wallet_changed:
		_refresh_money()
	if not delta.affects_tasks():
		return
	if delta.full_reconcile or delta.task_list_changed:
		refresh()
		return
	for instance_id in delta.task_instance_ids:
		var task := state.task_instance(instance_id)
		var bookmark := bookmark_buttons.get(instance_id) as Button
		if task != null and not task.settled and bookmark != null:
			_update_bookmark(bookmark, task)
	if open_task_instance_id in delta.task_instance_ids and task_window != null:
		task_window.refresh()


func _on_locale_changed(_locale: String) -> void:
	_refresh_money()
	refresh()
	call_deferred("_refresh_task_page")
