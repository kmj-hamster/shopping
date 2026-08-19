class_name QuestTaskWindow
extends PaperActivityPopup

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
var state: QuestGameState
var task_instance_id: int
var slot_views: Dictionary = {}
var submission_slot: QuestTaskSlot
var gift_slot: QuestTaskGiftSlot


func setup(game_state: QuestGameState, instance_id: int) -> void:
	state = game_state
	task_instance_id = instance_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	super._ready()
	# QuestTaskDock owns the window state, while TaskPopupLayer owns its layout.
	# The shared PaperActivityPopup anchors now stay viewport-local, matching
	# QuestLocationPopup instead of approximating that rectangle in full-HUD space.
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
	var footer_copy := ""
	if not definition.footer_text_key.is_empty():
		footer_copy = TranslationServer.translate(definition.footer_text_key)
	elif definition.selection_pool == TaskDefinition.SelectionPool.DAILY:
		footer_copy = (
			TranslationServer.translate(&"task.daily.reward.footer")
			% definition.reward_money()
		)
	set_footer_copy(footer_copy)
	if definition.settlement_mode == TaskDefinition.SettlementMode.GIFT_PICKUP:
		set_body_copy(
			TranslationServer.translate(definition.body_text_key),
			LETTER_BODY_HEIGHT,
			LETTER_BODY_MAX_LINES,
		)
		_ensure_gift_slot()
		gift_slot.setup(state, task.instance_id)
		feedback_label.text = ""
		if not task.gift_claimed:
			var feedback_key := (
				&"demo.ui.synthesis.drag_result"
				if task.gift_revealed
				else &"demo.ui.synthesis.flip_result"
			)
			feedback_label.text = TranslationServer.translate(feedback_key)
		action_button.visible = false
		return
	set_body_copy(
		TranslationServer.translate(definition.body_text_key),
		BODY_HEIGHT,
		BODY_MAX_LINES,
	)
	action_button.visible = true
	_ensure_slot_views(task, definition)
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
	var effective_rules: Array[CardSlotRule] = []
	for raw_rule in definition.slot_rules:
		var rule := state.effective_task_rule(task, raw_rule as CardSlotRule)
		if rule == null:
			continue
		effective_rules.append(rule)
	if submission_slot == null:
		submission_slot = QuestTaskSlot.new()
		submission_slot.name = "TaskSubmissionSlot"
		submission_slot.rule_focused.connect(rule_focused.emit)
		submission_slot.item_inspected.connect(item_inspected.emit)
		slots_row.add_child(submission_slot)
	submission_slot.setup_choices(state, task, effective_rules)
	slot_views.clear()
	for rule in effective_rules:
		slot_views[rule.id] = submission_slot


func _update_action_state(
	task: TaskInstanceState,
	_definition: TaskDefinition,
	evaluation: Dictionary,
) -> void:
	set_action_visual(task.confirmed, not task.confirmed and evaluation.is_ready)
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
	if task.confirmed:
		return
	else:
		state.confirm_task(task.instance_id)
	rule_focused.emit(null)
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
