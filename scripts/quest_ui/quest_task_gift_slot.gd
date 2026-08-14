class_name QuestTaskGiftSlot
extends PanelContainer

signal item_inspected(definition: CardItemDefinition)

const CARD_SIZE := CardHandCard.CARD_SIZE

var state: QuestGameState
var task_instance_id: int
var holder: CenterContainer
var back_button: Button
var card_view: CardHandCard
var virtual_card: CardItemState
var money_face: PanelContainer
var money_label: Label


func setup(game_state: QuestGameState, instance_id: int) -> void:
	state = game_state
	task_instance_id = instance_id
	if is_node_ready():
		refresh()


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder = CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	back_button = Button.new()
	back_button.name = "GiftCardBack"
	back_button.custom_minimum_size = CARD_SIZE
	back_button.text = "◇\n◇\n◇"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 24)
	back_button.add_theme_color_override("font_color", Color("b9c7bd"))
	back_button.add_theme_stylebox_override(
		"normal", UiPalette.panel_style(Color("071013", 0.99), Color("71867f", 0.88))
	)
	back_button.add_theme_stylebox_override(
		"hover", UiPalette.panel_style(Color("0c1c20", 0.99), Color("b3c7bc", 0.96))
	)
	back_button.pressed.connect(_on_back_pressed)
	holder.add_child(back_button)

	card_view = CardHandCard.new()
	card_view.name = "GiftCardFace"
	card_view.inspect_requested.connect(item_inspected.emit)
	card_view.drag_finished.connect(_on_card_drag_finished)
	holder.add_child(card_view)
	card_view.visible = false
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_face = PanelContainer.new()
	money_face.name = "MoneyGiftFace"
	money_face.custom_minimum_size = CARD_SIZE
	money_face.add_theme_stylebox_override(
		"panel", UiPalette.panel_style(Color("f2ead5"), Color("a58b55"))
	)
	holder.add_child(money_face)
	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 32)
	money_label.add_theme_color_override("font_color", Color("8b6730"))
	money_face.add_child(money_label)
	money_face.visible = false
	refresh()


func refresh() -> void:
	if holder == null or state == null:
		return
	var task := state.task_instance(task_instance_id)
	var definition := (
		QuestArcCatalog.task_by_id(task.definition_id) if task != null else null
	)
	if task == null or definition == null or task.settled:
		visible = false
		back_button.visible = false
		card_view.visible = false
		money_face.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	if task.gift_claimed and definition.gift_money <= 0:
		visible = false
		back_button.visible = false
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		money_face.visible = false
		return
	visible = true
	if not task.gift_revealed:
		back_button.visible = true
		card_view.visible = false
		money_face.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	back_button.visible = false
	if definition.gift_money > 0:
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		money_face.visible = true
		money_label.text = "+%d" % definition.gift_money
		return
	money_face.visible = false
	if task.gift_claimed:
		card_view.visible = false
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	if virtual_card == null or virtual_card.definition_id != definition.gift_item_id:
		virtual_card = CardItemState.new(
			-100_000 - task_instance_id,
			definition.gift_item_id,
			task.activation_day,
			&"task_gift_preview",
			0,
		)
	virtual_card.assign_to(&"task_gift", StringName(str(task_instance_id)))
	card_view.setup(virtual_card, QuestArcCatalog.item_by_id(definition.gift_item_id), true)
	card_view.visible = true
	card_view.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_back_pressed() -> void:
	if state != null:
		state.reveal_task_gift(task_instance_id)


func _on_card_drag_finished(_card: CardItemState, succeeded: bool) -> void:
	if not succeeded or state == null:
		return
	var task := state.task_instance(task_instance_id)
	if task == null or not task.gift_claimed:
		return
	# The preview card is virtual and keeps its ACTIVITY_SLOT location. Override
	# the generic same-origin restoration after the hand accepts the real reward.
	card_view.drag_origin_visible = false
	card_view.drag_origin_mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()
