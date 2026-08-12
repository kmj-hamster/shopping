class_name QuestLocationPopup
extends PaperActivityPopup

signal unlock_confirmed(store_id: StringName, card: CardItemState)
signal staging_changed(card: CardItemState, staged: bool)
signal rule_focused(rule: CardSlotRule)
signal item_inspected(definition: CardItemDefinition)

var state: QuestGameState
var store_id: StringName
var unlock_definition: StoreUnlockDefinition
var unlock_slot: QuestLocationUnlockSlot


func setup(game_state: QuestGameState, selected_store_id: StringName) -> void:
	state = game_state
	store_id = selected_store_id
	unlock_definition = QuestArcCatalog.store_unlock_for_store(store_id)
	if is_node_ready():
		refresh()


func _ready() -> void:
	super._ready()
	action_button.pressed.connect(_on_action_pressed)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	unlock_slot = QuestLocationUnlockSlot.new()
	unlock_slot.name = "LocationUnlockSlot"
	unlock_slot.setup_unlock(
		state,
		store_id,
		unlock_definition.slot_rule if unlock_definition != null else null,
	)
	unlock_slot.staging_changed.connect(_on_staging_changed)
	unlock_slot.rule_focused.connect(rule_focused.emit)
	unlock_slot.item_inspected.connect(item_inspected.emit)
	slots_row.add_child(unlock_slot)
	refresh()


func refresh() -> void:
	if title_label == null:
		return
	var store := QuestArcCatalog.store_by_id(store_id)
	if store == null or unlock_definition == null:
		closed.emit()
		return
	title_label.text = TranslationServer.translate(store.display_name_key)
	set_body_copy(
		TranslationServer.translate(unlock_definition.prompt_text_key),
		BODY_HEIGHT,
		BODY_MAX_LINES,
	)
	action_button.text = TranslationServer.translate(&"demo.ui.confirm")
	action_button.disabled = unlock_slot == null or unlock_slot.pending_card == null
	feedback_label.text = (
		TranslationServer.translate(&"demo.ui.location.ready")
		if not action_button.disabled
		else TranslationServer.translate(&"demo.ui.location.place_item")
	)


func release_pending_card() -> void:
	if unlock_slot != null:
		unlock_slot.release_card()


func show_feedback(message_key: StringName) -> void:
	feedback_label.text = TranslationServer.translate(message_key)


func _on_staging_changed(card: CardItemState, staged: bool) -> void:
	staging_changed.emit(card, staged)
	refresh()


func _on_action_pressed() -> void:
	if unlock_slot != null and unlock_slot.pending_card != null:
		unlock_confirmed.emit(store_id, unlock_slot.pending_card)


func _on_locale_changed(_locale: String) -> void:
	if unlock_slot != null:
		unlock_slot.refresh()
	refresh()
