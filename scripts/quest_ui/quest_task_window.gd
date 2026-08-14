class_name QuestTaskWindow
extends PaperActivityPopup

signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)
var state: QuestGameState
var task_instance_id: int
var slot_views: Dictionary = {}
var owner_slot_labels: Dictionary = {}
var or_labels: Array[Label] = []
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
	for label in or_labels:
		label.text = TranslationServer.translate(&"demo.ui.or")
	for raw_rule in definition.slot_rules:
		var rule := state.effective_task_rule(task, raw_rule as CardSlotRule)
		var owner_slot_label := owner_slot_labels.get(rule.id) as Label
		if owner_slot_label != null:
			owner_slot_label.text = TranslationServer.translate(rule.display_name_key)
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
		var rule := state.effective_task_rule(task, raw_rule as CardSlotRule)
		slot.setup(state, task, rule)
		slot.rule_focused.connect(rule_focused.emit)
		slot.item_inspected.connect(item_inspected.emit)
		if definition.category == TaskDefinition.Category.OWNER_REQUEST:
			var slot_column := VBoxContainer.new()
			slot_column.name = "%sOwnerSlot" % String(rule.id).to_pascal_case()
			slot_column.mouse_filter = Control.MOUSE_FILTER_PASS
			slot_column.alignment = BoxContainer.ALIGNMENT_CENTER
			slot_column.add_theme_constant_override("separation", 5)
			slots_row.add_child(slot_column)
			var slot_label := Label.new()
			slot_label.name = "OwnerSlotLabel"
			slot_label.custom_minimum_size = Vector2(112, 20)
			slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot_label.clip_text = true
			slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			slot_label.add_theme_font_size_override("font_size", 13)
			slot_label.add_theme_color_override("font_color", Color("594a36"))
			slot_label.text = TranslationServer.translate(rule.display_name_key)
			slot_column.add_child(slot_label)
			slot_column.add_child(slot)
			owner_slot_labels[rule.id] = slot_label
		else:
			slots_row.add_child(slot)
		slot_views[rule.id] = slot


func _update_action_state(
	task: TaskInstanceState,
	definition: TaskDefinition,
	evaluation: Dictionary,
) -> void:
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
	if task.confirmed:
		return
	else:
		state.confirm_task(task.instance_id)
	rule_focused.emit(null)
	refresh()


func _on_locale_changed(_locale: String) -> void:
	refresh()
