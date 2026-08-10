class_name QuestTaskWindow
extends PaperActivityPopup

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
signal owner_result_presented(store_id: StringName, text_key: StringName)

var state: QuestGameState
var task_instance_id: int
var current_store_id: StringName


func setup(game_state: QuestGameState, instance_id: int, store_id: StringName = &"") -> void:
	state = game_state
	task_instance_id = instance_id
	current_store_id = store_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	super._ready()
	# Center this global popup over the content viewport rather than the full HUD.
	anchor_left = 0.32
	anchor_top = 0.10
	anchor_right = 0.83
	anchor_bottom = 0.70
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_margin.add_theme_constant_override("margin_left", 36)
	body_margin.add_theme_constant_override("margin_right", 36)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_button.pressed.connect(_on_action_pressed)
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
	for rule_index in definition.slot_rules.size():
		if rule_index > 0 and definition.slot_mode == TaskDefinition.SlotMode.ANY:
			var or_label := Label.new()
			or_label.text = TranslationServer.translate(&"demo.ui.or")
			or_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			or_label.add_theme_font_size_override("font_size", 14)
			or_label.add_theme_color_override("font_color", Color("6d5a3d"))
			slots_row.add_child(or_label)
		var raw_rule := definition.slot_rules[rule_index]
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
		action_button.tooltip_text = ""
		if current_store_id != definition.store_id:
			feedback_label.text = TranslationServer.translate(&"quest.ui.task.owner_elsewhere")
			action_button.tooltip_text = feedback_label.text
	else:
		action_button.text = TranslationServer.translate(
			&"quest.ui.task.enjoy_tonight"
			if definition.category == TaskDefinition.Category.SELF_CARE
			else &"quest.ui.task.deliver_tomorrow"
		)
		action_button.disabled = task.confirmed or not evaluation.is_ready
		action_button.tooltip_text = ""
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
		return
	else:
		state.confirm_task(task.instance_id)
	rule_focused.emit(null)
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
