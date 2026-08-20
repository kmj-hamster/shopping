class_name PersonaCardCatalog
extends RefCounted

const PERSONA_SHAPES: Array[StringName] = [
	CardPropertySet.SHAPE_LIGHT,
	CardPropertySet.SHAPE_TEAR,
	CardPropertySet.SHAPE_DREAM,
	CardPropertySet.SHAPE_SLEEP,
]

const PERSONA_CARD_IDS := {
	CardPropertySet.SHAPE_LIGHT: &"persona_lamplighter",
	CardPropertySet.SHAPE_TEAR: &"persona_nightwatcher",
	CardPropertySet.SHAPE_DREAM: &"persona_dreamwalker",
	CardPropertySet.SHAPE_SLEEP: &"persona_homecomer",
}

const PERSONA_NAME_KEYS := {
	CardPropertySet.SHAPE_LIGHT: &"demo.persona.lamplighter.name",
	CardPropertySet.SHAPE_TEAR: &"demo.persona.nightwatcher.name",
	CardPropertySet.SHAPE_DREAM: &"demo.persona.dreamwalker.name",
	CardPropertySet.SHAPE_SLEEP: &"demo.persona.homecomer.name",
}

const PERSONA_DESCRIPTION_KEYS := {
	CardPropertySet.SHAPE_LIGHT: &"demo.persona.lamplighter.description",
	CardPropertySet.SHAPE_TEAR: &"demo.persona.nightwatcher.description",
	CardPropertySet.SHAPE_DREAM: &"demo.persona.dreamwalker.description",
	CardPropertySet.SHAPE_SLEEP: &"demo.persona.homecomer.description",
}

static var _definitions: Dictionary = {}
static var _cards: Dictionary = {}


static func definition_for_shape(shape_id: StringName, amount: int) -> CardItemDefinition:
	if shape_id not in PERSONA_SHAPES:
		return null
	var definition := _definitions.get(shape_id) as CardItemDefinition
	if definition == null:
		definition = CardItemDefinition.new()
		definition.id = StringName(PERSONA_CARD_IDS[shape_id])
		definition.display_name_key = StringName(PERSONA_NAME_KEYS[shape_id])
		definition.description_key = StringName(PERSONA_DESCRIPTION_KEYS[shape_id])
		definition.is_crafted = true
		definition.can_recycle = false
		definition.can_be_synthesis_base = false
		definition.property_set = CardPropertySet.new()
		definition.image = ItemDetailPopup.property_icon_texture(shape_id)
		_definitions[shape_id] = definition
	definition.property_set.tags = [CardPropertySet.PROPERTY_PERSONA]
	definition.property_set.values = {
		shape_id: maxi(amount, 0),
	}
	return definition


static func card_for_shape(shape_id: StringName) -> CardItemState:
	if shape_id not in PERSONA_SHAPES:
		return null
	var card := _cards.get(shape_id) as CardItemState
	if card == null:
		var order_index := PERSONA_SHAPES.find(shape_id)
		card = CardItemState.new(
			-(order_index + 1),
			StringName(PERSONA_CARD_IDS[shape_id]),
			1,
			&"persona_card",
			0,
		)
		_cards[shape_id] = card
	return card


static func shape_for_card(card: CardItemState) -> StringName:
	if card == null:
		return &""
	for shape_id in PERSONA_SHAPES:
		if card.definition_id == StringName(PERSONA_CARD_IDS[shape_id]):
			return shape_id
	return &""


static func definition_for_card(
	card: CardItemState,
	protagonist_shape_levels: Dictionary,
) -> CardItemDefinition:
	var shape_id := shape_for_card(card)
	if shape_id.is_empty():
		return null
	return definition_for_shape(
		shape_id,
		int(protagonist_shape_levels.get(shape_id, 0)),
	)


static func sync_selection(selected_shape_id: StringName) -> void:
	for shape_id in PERSONA_SHAPES:
		var card := card_for_shape(shape_id)
		if shape_id == selected_shape_id:
			card.assign_to(&"synthesis", &"persona")
		else:
			card.return_to_hand()


static func rule_uses_persona_cards(rule: CardSlotRule) -> bool:
	if rule == null:
		return false
	if (
		CardPropertySet.PROPERTY_PERSONA in rule.required_all
		or CardPropertySet.PROPERTY_PERSONA in rule.allowed_any
	):
		return true
	for raw_requirement in rule.value_requirements:
		var requirement := raw_requirement as SlotValueRequirement
		if requirement != null and CardPropertySet.PROPERTY_PERSONA in requirement.tags:
			return true
	for shape_id in PERSONA_SHAPES:
		if StringName(PERSONA_CARD_IDS[shape_id]) in rule.accepted_item_ids:
			return true
	return false
