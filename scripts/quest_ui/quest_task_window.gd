class_name QuestTaskWindow
extends PaperActivityPopup

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
signal owner_result_presented(store_id: StringName, text_key: StringName)

var state: QuestGameState
var task_instance_id: int
var current_store_id: StringName
var slot_views: Dictionary = {}
var or_labels: Array[Label] = []
var gift_slot: QuestTaskGiftSlot


func setup(game_state: QuestGameState, instance_id: int, store_id: StringName = &"") -> void:
	state = game_state
	task_instance_id = instance_id
	current_store_id = store_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	super._ready()
	# The content viewport begins at 19% of the full HUD; this maps its shelf's
	# 3.5% left edge into global coordinates. QuestLocationPopup uses the
	# equivalent viewport-local rectangle.
	anchor_left = 0.217
	anchor_top = 0.08
	anchor_right = 0.517
	anchor_bottom = 0.68
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
	if definition.settlement_mode == TaskDefinition.SettlementMode.GIFT_PICKUP:
		set_body_copy(
			TranslationServer.translate(definition.body_text_key),
			LETTER_BODY_HEIGHT,
			LETTER_BODY_MAX_LINES,
		)
		_ensure_gift_slot()
		gift_slot.setup(state, task.instance_id)
		feedback_label.text = (
			""
			if task.gift_claimed
			else TranslationServer.translate(
				&"demo.ui.synthesis.drag_result"
				if task.gift_revealed
				else &"demo.ui.synthesis.flip_result"
			)
		)
		action_button.visible = false
		return
	set_body_copy(
		TranslationServer.translate(definition.body_text_key),
		BODY_HEIGHT,
		BODY_MAX_LINES,
	)
	action_button.visible = true
	_ensure_slot_views(task, definition)
	for label in or_labels:
		label.text = TranslationServer.translate(&"demo.ui.or")
	for raw_rule in definition.slot_rules:
		var rule := raw_rule as CardSlotRule
		var slot := slot_views.get(rule.id) as QuestTaskSlot
		if slot != null:
			slot.setup(state, task, rule)
	var evaluation := state.task_evaluation(task.instance_id)
	feedback_label.text = ""
	_update_action_state(task, definition, evaluation)


func _ensure_gift_slot() -> void:
	if gift_slot != null:
		return
	gift_slot = QuestTaskGiftSlot.new()
	gift_slot.item_inspected.connect(item_inspected.emit)
	slots_row.add_child(gift_slot)


func _ensure_slot_views(task: TaskInstanceState, definition: TaskDefinition) -> void:
	if not slot_views.is_empty():
		return
	for rule_index in definition.slot_rules.size():
		if rule_index > 0 and definition.slot_mode == TaskDefinition.SlotMode.ANY:
			var or_label := Label.new()
			or_label.text = TranslationServer.translate(&"demo.ui.or")
			or_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			or_label.add_theme_font_size_override("font_size", 14)
			or_label.add_theme_color_override("font_color", Color("6d5a3d"))
			slots_row.add_child(or_label)
			or_labels.append(or_label)
		var raw_rule := definition.slot_rules[rule_index]
		var slot := QuestTaskSlot.new()
		var rule := raw_rule as CardSlotRule
		slot.setup(state, task, rule)
		slot.rule_focused.connect(rule_focused.emit)
		slot.item_inspected.connect(item_inspected.emit)
		slots_row.add_child(slot)
		slot_views[rule.id] = slot


func _update_action_state(
	task: TaskInstanceState,
	definition: TaskDefinition,
	evaluation: Dictionary,
) -> void:
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
	if definition.settlement_mode == TaskDefinition.SettlementMode.GIFT_PICKUP:
		return
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
