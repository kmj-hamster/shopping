class_name QuestTaskWindow
extends PanelContainer

signal closed
signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
signal owner_result_presented(store_id: StringName, text_key: StringName)

var state: QuestGameState
var task_instance_id: int
var current_store_id: StringName
var title_label: Label
var body_label: Label
var slots_row: HBoxContainer
var action_button: Button
var feedback_label: Label


func setup(game_state: QuestGameState, instance_id: int, store_id: StringName = &"") -> void:
	state = game_state
	task_instance_id = instance_id
	current_store_id = store_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	position = Vector2(176, 116)
	size = Vector2(690, 440)
	add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("050d11", 0.985), Color("887b5a", 0.92))
	)
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
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color("dccb94"))
	header.add_child(title_label)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 34)
	close_button.pressed.connect(closed.emit)
	header.add_child(close_button)
	body_label = Label.new()
	body_label.custom_minimum_size = Vector2(0, 72)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color("bdc9c3"))
	column.add_child(body_label)
	slots_row = HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 14)
	column.add_child(slots_row)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(0, 34)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color("d4ad70"))
	column.add_child(feedback_label)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(180, 42)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_button.pressed.connect(_on_action_pressed)
	column.add_child(action_button)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func refresh() -> void:
	if state == null or title_label == null:
		return
	var task := state.task_instance(task_instance_id)
	if task == null or task.settled:
		closed.emit()
		return
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	title_label.text = TranslationServer.translate(definition.display_name_key)
	body_label.text = TranslationServer.translate(definition.body_text_key)
	for child in slots_row.get_children():
		child.free()
	for raw_rule in definition.slot_rules:
		var slot := QuestTaskSlot.new()
		slot.setup(state, task, raw_rule as CardSlotRule)
		slot.rule_focused.connect(rule_focused.emit)
		slot.item_inspected.connect(item_inspected.emit)
		slots_row.add_child(slot)
	var evaluation := state.task_evaluation(task.instance_id)
	feedback_label.text = ""
	if definition.settlement_mode == TaskDefinition.SettlementMode.OWNER_IMMEDIATE:
		action_button.text = TranslationServer.translate(&"quest.ui.task.deliver")
		action_button.disabled = not evaluation.is_ready or current_store_id != definition.store_id
		if current_store_id != definition.store_id:
			feedback_label.text = TranslationServer.translate(&"quest.ui.task.owner_elsewhere")
	elif task.confirmed:
		action_button.text = TranslationServer.translate(&"quest.ui.task.cancel_confirm")
		action_button.disabled = false
		feedback_label.text = TranslationServer.translate(&"quest.ui.task.confirmed")
	else:
		action_button.text = TranslationServer.translate(&"quest.ui.task.confirm")
		action_button.disabled = not evaluation.is_ready
		if not evaluation.is_ready and not task.assignments.is_empty():
			feedback_label.text = TranslationServer.translate(&"quest.ui.task.not_ready")


func _on_action_pressed() -> void:
	var task := state.task_instance(task_instance_id)
	if task == null:
		return
	var definition := QuestArcCatalog.task_by_id(task.definition_id)
	if definition.settlement_mode == TaskDefinition.SettlementMode.OWNER_IMMEDIATE:
		var result := state.submit_owner_task(task.instance_id, current_store_id)
		if result.ok:
			feedback_label.text = TranslationServer.translate(StringName(result.result_text_key))
			owner_result_presented.emit(definition.store_id, StringName(result.result_text_key))
			closed.emit()
	elif task.confirmed:
		state.cancel_task_confirmation(task.instance_id)
	else:
		state.confirm_task(task.instance_id)
	rule_focused.emit(null)
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
