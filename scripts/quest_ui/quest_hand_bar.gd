class_name QuestHandBar
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)
signal card_drag_started(card: CardItemState)
signal card_drag_finished(card: CardItemState, succeeded: bool)

const RULE_MATCH_LIFT := 8.0
const NORMAL_CARD_GAP := 8.0
const HOVER_CARD_GAP := 6.0
const HOVER_Z_INDEX := 1000
const CARD_REFLOW_SECONDS := 0.12
const REORDER_DROP_MARGIN := Vector2(32, 38)
const REORDER_OVERLAP_SLOP := 12.0
const HAND_HEIGHT := CardHandCard.CARD_SIZE.y + 8.0
const TAB_ITEMS := &"items"
const TAB_MASKS := &"masks"

var state: QuestGameState
var highlight_rule: CardSlotRule
var card_highlight_predicate: Callable
var card_scroll: ScrollContainer
var card_row: Control
var active_tab: StringName = TAB_ITEMS
var mask_persona_order: Array[StringName] = PersonaMaskCatalog.MASK_PERSONAS.duplicate()
var card_views: Dictionary = {}
var card_wrappers: Dictionary = {}
var temporarily_hidden_card_ids: Dictionary = {}
var hovered_card_id := -1
var overlap_active := false
var layout_queued := false
var rebuilding_cards := false
var card_layout_tweens: Dictionary = {}
var freshly_created_card_ids: Dictionary = {}
var card_target_positions: Dictionary = {}


func setup(game_state: QuestGameState) -> void:
	if state != null and state.state_delta.is_connected(_on_state_delta):
		state.state_delta.disconnect(_on_state_delta)
	state = game_state
	if state != null and not state.state_delta.is_connected(_on_state_delta):
		state.state_delta.connect(_on_state_delta)
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(0, HAND_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	card_scroll = ScrollContainer.new()
	card_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	card_scroll.custom_minimum_size = Vector2(0, HAND_HEIGHT)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.clip_contents = false
	card_scroll.resized.connect(_queue_card_layout)
	add_child(card_scroll)
	card_row = Control.new()
	card_row.mouse_filter = Control.MOUSE_FILTER_PASS
	card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.custom_minimum_size = Vector2(0, CardHandCard.CARD_SIZE.y)
	card_scroll.add_child(card_row)
	LocaleManager.locale_changed.connect(_on_locale_changed)
	refresh()


func refresh() -> void:
	_reconcile_cards(true)


func show_tab(tab_id: StringName) -> void:
	if tab_id not in [TAB_ITEMS, TAB_MASKS]:
		return
	if active_tab == tab_id:
		return
	active_tab = tab_id
	hovered_card_id = -1


func show_tab_for_rule(rule: CardSlotRule) -> void:
	show_tab(TAB_MASKS if PersonaMaskCatalog.rule_uses_masks(rule) else TAB_ITEMS)


func _visible_card_entries() -> Array:
	var entries: Array = []
	if state == null:
		return entries
	for card in state.inventory:
		if card.location != CardItemState.Location.HAND:
			continue
		if temporarily_hidden_card_ids.has(card.instance_id):
			continue
		var definition := QuestArcCatalog.item_by_id(card.definition_id)
		if definition != null:
			entries.append([card, definition])
	PersonaMaskCatalog.sync_selection(state.synthesis_persona_id)
	for persona_id in mask_persona_order:
		var amount := int(state.protagonist_persona_counts.get(persona_id, 0))
		if amount <= 0:
			continue
		var mask_card := PersonaMaskCatalog.card_for_persona(persona_id)
		if mask_card.location != CardItemState.Location.HAND:
			continue
		entries.append([
			mask_card,
			PersonaMaskCatalog.definition_for_persona(
				persona_id,
				amount,
			),
		])
	return entries


func _reconcile_cards(refresh_existing: bool = false) -> void:
	if card_row == null:
		return
	rebuilding_cards = true
	var desired_cards: Dictionary = {}
	var entries := _visible_card_entries()
	for entry in entries:
		var card := entry[0] as CardItemState
		desired_cards[card.instance_id] = entry

	for raw_instance_id in card_views.keys().duplicate():
		var instance_id := int(raw_instance_id)
		if not desired_cards.has(instance_id):
			_remove_card_view(instance_id)

	for entry in entries:
		var card := entry[0] as CardItemState
		var definition := entry[1] as CardItemDefinition
		if not card_views.has(card.instance_id):
			_create_card_view(card, definition)
		elif refresh_existing:
			(card_views[card.instance_id] as CardHandCard).setup(card, definition)
	rebuilding_cards = false
	_refresh_card_highlights()
	_layout_cards_for_rule()
	_queue_card_layout()


func _create_card_view(card: CardItemState, definition: CardItemDefinition) -> void:
	var wrapper := Control.new()
	wrapper.name = "HandCardWrapper%d" % card.instance_id
	wrapper.custom_minimum_size = QuestTaskSlot.CARD_SIZE
	wrapper.size = QuestTaskSlot.CARD_SIZE
	wrapper.clip_contents = false
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := CardHandCard.new()
	view.setup(card, definition)
	view.inspect_requested.connect(item_inspected.emit)
	view.drag_started.connect(card_drag_started.emit)
	view.drag_finished.connect(card_drag_finished.emit)
	view.mouse_entered.connect(_on_card_hovered.bind(card.instance_id))
	view.mouse_exited.connect(_on_card_unhovered.bind(card.instance_id))
	wrapper.add_child(view)
	card_row.add_child(wrapper)
	view.size = CardHandCard.CARD_SIZE
	_apply_card_highlight(view, card, definition)
	card_views[card.instance_id] = view
	card_wrappers[card.instance_id] = wrapper
	freshly_created_card_ids[card.instance_id] = true


func _remove_card_view(instance_id: int) -> void:
	var tween := card_layout_tweens.get(instance_id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	card_layout_tweens.erase(instance_id)
	freshly_created_card_ids.erase(instance_id)
	var wrapper := card_wrappers.get(instance_id) as Control
	card_views.erase(instance_id)
	card_wrappers.erase(instance_id)
	if hovered_card_id == instance_id:
		hovered_card_id = -1
	if wrapper != null and is_instance_valid(wrapper):
		# A state mutation can occur while this card is the drag signal emitter.
		# Hide it synchronously, then let the scene tree free it safely.
		wrapper.visible = false
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.queue_free()


func set_highlight_rule(rule: CardSlotRule) -> void:
	highlight_rule = rule
	_refresh_card_highlights()
	_layout_cards_for_rule()


func set_card_highlight_predicate(predicate: Callable) -> void:
	card_highlight_predicate = predicate
	_refresh_card_highlights()
	_layout_cards_for_rule()


func clear_card_highlight_predicate() -> void:
	if not card_highlight_predicate.is_valid():
		return
	card_highlight_predicate = Callable()
	_refresh_card_highlights()
	_layout_cards_for_rule()


func _refresh_card_highlights() -> void:
	for raw_instance_id in card_views:
		var view := card_views[raw_instance_id] as CardHandCard
		if view != null:
			_apply_card_highlight(view, view.card, view.definition)


func _apply_card_highlight(
	view: CardHandCard,
	card: CardItemState,
	definition: CardItemDefinition,
) -> void:
	if view == null:
		return
	var matches := false
	if card_highlight_predicate.is_valid():
		matches = bool(card_highlight_predicate.call(card))
	elif highlight_rule != null and definition != null:
		matches = CardRuleEvaluator.can_place(highlight_rule, definition)
	view.apply_match_highlight(matches)


func _layout_cards_for_rule() -> void:
	if state == null or card_row == null:
		return
	var ordered_ids: Array[int] = []
	for entry in _visible_card_entries():
		var card := entry[0] as CardItemState
		if card_views.has(card.instance_id):
			ordered_ids.append(card.instance_id)
	for index in range(ordered_ids.size()):
		var instance_id := ordered_ids[index]
		var wrapper := card_wrappers[instance_id] as Control
		var view := card_views[instance_id] as CardHandCard
		card_row.move_child(wrapper, index)
		var lift := RULE_MATCH_LIFT if view.rule_match_highlighted else 0.0
		view.offset_top = -lift
		view.offset_bottom = CardHandCard.CARD_SIZE.y - lift
	_apply_card_spacing(ordered_ids)


func _apply_card_spacing(ordered_ids: Array[int]) -> void:
	var count := ordered_ids.size()
	card_target_positions.clear()
	if count == 0 or card_scroll == null:
		overlap_active = false
		return
	var available_width := card_scroll.size.x
	if available_width <= 0.0:
		return
	var card_width := CardHandCard.CARD_SIZE.x
	var natural_width := card_width * count + NORMAL_CARD_GAP * maxi(count - 1, 0)
	overlap_active = natural_width > available_width
	var positions: Array[float] = []
	if not overlap_active or count == 1:
		for index in count:
			positions.append(index * (card_width + NORMAL_CARD_GAP))
	else:
		var step := maxf((available_width - card_width) / float(count - 1), 0.0)
		for index in count:
			positions.append(index * step)
		var hovered_index := ordered_ids.find(hovered_card_id)
		if hovered_index >= 0:
			positions = _hovered_positions(count, hovered_index, available_width, positions)

	for index in count:
		var instance_id := ordered_ids[index]
		var wrapper := card_wrappers[instance_id] as Control
		var view := card_views[instance_id] as CardHandCard
		var allocated_width := (
			positions[index + 1] - positions[index]
			if index + 1 < count
			else card_width
		)
		wrapper.custom_minimum_size = Vector2(maxf(allocated_width, 0.0), CardHandCard.CARD_SIZE.y)
		wrapper.size = Vector2(maxf(allocated_width, 0.0), CardHandCard.CARD_SIZE.y)
		card_target_positions[instance_id] = positions[index]
		_move_wrapper(instance_id, wrapper, Vector2(positions[index], 0.0))
		view.position.x = 0.0
		view.size.x = card_width
		view.z_index = (
			HOVER_Z_INDEX
			if instance_id == hovered_card_id
			else (500 + index if view.rule_match_highlighted else index)
		)
	card_row.custom_minimum_size = Vector2(available_width, CardHandCard.CARD_SIZE.y)
	card_row.size.x = available_width
	freshly_created_card_ids.clear()


func _move_wrapper(instance_id: int, wrapper: Control, target_position: Vector2) -> void:
	var previous_tween := card_layout_tweens.get(instance_id) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	if (
		freshly_created_card_ids.has(instance_id)
		or wrapper.position.is_equal_approx(target_position)
		or not is_inside_tree()
	):
		wrapper.position = target_position
		card_layout_tweens.erase(instance_id)
		return
	var tween := wrapper.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wrapper, "position", target_position, CARD_REFLOW_SECONDS)
	card_layout_tweens[instance_id] = tween


func _hovered_positions(
	count: int,
	hovered_index: int,
	available_width: float,
	base_positions: Array[float],
) -> Array[float]:
	var positions := base_positions.duplicate()
	var card_width := CardHandCard.CARD_SIZE.x
	var last_x := maxf(available_width - card_width, 0.0)
	var hover_x := clampf(base_positions[hovered_index], 0.0, last_x)
	var cards_after := count - hovered_index - 1
	if cards_after > 0:
		hover_x = minf(hover_x, maxf(last_x - card_width - HOVER_CARD_GAP, 0.0))
	positions[hovered_index] = hover_x

	if hovered_index > 0:
		var before_step := hover_x / float(hovered_index)
		for index in hovered_index:
			positions[index] = index * before_step
	if cards_after > 0:
		var after_start := hover_x + card_width + HOVER_CARD_GAP
		if cards_after == 1:
			positions[hovered_index + 1] = last_x
		else:
			var after_step := maxf((last_x - after_start) / float(cards_after - 1), 0.0)
			for offset in range(1, cards_after + 1):
				positions[hovered_index + offset] = after_start + (offset - 1) * after_step
	return positions


func _on_card_hovered(instance_id: int) -> void:
	if rebuilding_cards or hovered_card_id == instance_id:
		return
	hovered_card_id = instance_id
	_layout_cards_for_rule()


func _on_card_unhovered(instance_id: int) -> void:
	if rebuilding_cards or hovered_card_id != instance_id:
		return
	hovered_card_id = -1
	_layout_cards_for_rule()


func _queue_card_layout() -> void:
	if layout_queued:
		return
	layout_queued = true
	call_deferred("_flush_card_layout")


func _flush_card_layout() -> void:
	layout_queued = false
	_layout_cards_for_rule()


func set_card_temporarily_hidden(card: CardItemState, hidden: bool) -> void:
	if card == null:
		return
	if hidden:
		temporarily_hidden_card_ids[card.instance_id] = true
	else:
		temporarily_hidden_card_ids.erase(card.instance_id)
	_reconcile_cards()


func clear_temporarily_hidden_cards() -> void:
	if temporarily_hidden_card_ids.is_empty():
		return
	temporarily_hidden_card_ids.clear()
	_reconcile_cards()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or typeof(data) != TYPE_DICTIONARY:
		return false
	var card := data.get("card") as CardItemState
	if data.get("kind") != &"card_item" or card == null:
		return false
	if card.activity_id == &"task_gift":
		return state.can_claim_task_gift(int(String(card.slot_id)))
	var persona_id := PersonaMaskCatalog.persona_for_card(card)
	if not persona_id.is_empty():
		return (
			card.location == CardItemState.Location.HAND
			or state.synthesis_persona_id == persona_id
		)
	return card in state.inventory


func _has_point(point: Vector2) -> bool:
	return Rect2(-REORDER_DROP_MARGIN, size + REORDER_DROP_MARGIN * 2.0).has_point(point)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var card := data.get("card") as CardItemState
	if card == null:
		return
	if card.activity_id == &"task_gift":
		show_tab(TAB_ITEMS)
		state.claim_task_gift(int(String(card.slot_id)))
		return
	var persona_id := PersonaMaskCatalog.persona_for_card(card)
	if not persona_id.is_empty():
		if state.synthesis_persona_id == persona_id:
			state.select_synthesis_persona(persona_id)
			show_tab(TAB_MASKS)
			return
		var mask_grab_offset: Vector2 = data.get(
			"grab_offset", CardHandCard.CARD_SIZE * 0.5
		)
		var mask_target_index := _hand_insertion_index(
			at_position,
			card,
			mask_grab_offset,
		)
		_reorder_mask_card(persona_id, mask_target_index)
		return
	var grab_offset: Vector2 = data.get("grab_offset", CardHandCard.CARD_SIZE * 0.5)
	var target_index := _hand_insertion_index(at_position, card, grab_offset)
	state.move_card_to_hand(card, target_index)


func _hand_insertion_index(
	at_position: Vector2,
	dragged_card: CardItemState,
	grab_offset: Vector2 = CardHandCard.CARD_SIZE * 0.5,
) -> int:
	var pointer_global_x := get_global_rect().position.x + at_position.x
	var dragged_left := pointer_global_x - grab_offset.x
	var dragged_right := dragged_left + CardHandCard.CARD_SIZE.x
	var dragged_center := (dragged_left + dragged_right) * 0.5
	var candidate_centers: Array[float] = []
	var overlapping_indices: Array[int] = []
	for entry in _visible_card_entries():
		var card := entry[0] as CardItemState
		if card == dragged_card or not card_views.has(card.instance_id):
			continue
		var view := card_views[card.instance_id] as CardHandCard
		var rect := view.get_global_rect()
		var candidate_index := candidate_centers.size()
		candidate_centers.append(rect.get_center().x)
		if (
			dragged_right >= rect.position.x - REORDER_OVERLAP_SLOP
			and dragged_left <= rect.end.x + REORDER_OVERLAP_SLOP
		):
			overlapping_indices.append(candidate_index)

	if overlapping_indices.size() >= 2:
		var best_insertion_index := overlapping_indices[0] + 1
		var best_distance := INF
		for overlap_index in range(overlapping_indices.size() - 1):
			var left_index := overlapping_indices[overlap_index]
			var right_index := overlapping_indices[overlap_index + 1]
			if right_index != left_index + 1:
				continue
			var gap_center := (
				candidate_centers[left_index] + candidate_centers[right_index]
			) * 0.5
			var distance := absf(dragged_center - gap_center)
			if distance < best_distance:
				best_distance = distance
				best_insertion_index = right_index
		return best_insertion_index
	if overlapping_indices.size() == 1:
		var overlapped_index := overlapping_indices[0]
		return (
			overlapped_index
			if dragged_center <= candidate_centers[overlapped_index]
			else overlapped_index + 1
		)
	for candidate_index in candidate_centers.size():
		if dragged_center < candidate_centers[candidate_index]:
			return candidate_index
	return candidate_centers.size()


func _reorder_mask_card(persona_id: StringName, target_index: int) -> void:
	var current_index := mask_persona_order.find(persona_id)
	if current_index < 0:
		return
	mask_persona_order.remove_at(current_index)
	mask_persona_order.insert(clampi(target_index, 0, mask_persona_order.size()), persona_id)
	_layout_cards_for_rule()


func _card_view_for_row_child(child: Node) -> CardHandCard:
	if child is CardHandCard:
		return child as CardHandCard
	if child != null and child.get_child_count() > 0:
		return child.get_child(0) as CardHandCard
	return null


func _on_state_delta(delta: QuestStateDelta) -> void:
	if delta == null:
		return
	if delta.affects_hand() or delta.synthesis_persona_changed:
		# Persona levels can change without a physical inventory mutation. The
		# unified hand must still add or update the corresponding mask cards.
		_reconcile_cards(true)


func _on_locale_changed(_locale: String) -> void:
	refresh()
