class_name PersonaMaskCatalog
extends RefCounted

const MASK_PERSONAS: Array[StringName] = [
	CardPropertySet.PERSONA_NIGHTWALKER,
	CardPropertySet.PERSONA_MOURNER,
	CardPropertySet.PERSONA_DREAMWALKER,
	CardPropertySet.PERSONA_HOMECOMER,
]

const MASK_IDS := {
	CardPropertySet.PERSONA_NIGHTWALKER: &"mask_nightwalker",
	CardPropertySet.PERSONA_MOURNER: &"mask_mourner",
	CardPropertySet.PERSONA_DREAMWALKER: &"mask_dreamwalker",
	CardPropertySet.PERSONA_HOMECOMER: &"mask_homecomer",
}

const MASK_NAME_KEYS := {
	CardPropertySet.PERSONA_NIGHTWALKER: &"demo.mask.nightwalker.name",
	CardPropertySet.PERSONA_MOURNER: &"demo.mask.mourner.name",
	CardPropertySet.PERSONA_DREAMWALKER: &"demo.mask.dreamwalker.name",
	CardPropertySet.PERSONA_HOMECOMER: &"demo.mask.homecomer.name",
}

const MASK_DESCRIPTION_KEYS := {
	CardPropertySet.PERSONA_NIGHTWALKER: &"demo.mask.nightwalker.description",
	CardPropertySet.PERSONA_MOURNER: &"demo.mask.mourner.description",
	CardPropertySet.PERSONA_DREAMWALKER: &"demo.mask.dreamwalker.description",
	CardPropertySet.PERSONA_HOMECOMER: &"demo.mask.homecomer.description",
}

static var _definitions: Dictionary = {}
static var _cards: Dictionary = {}


static func definition_for_persona(persona_id: StringName, amount: int) -> CardItemDefinition:
	if persona_id not in MASK_PERSONAS:
		return null
	var definition := _definitions.get(persona_id) as CardItemDefinition
	if definition == null:
		definition = CardItemDefinition.new()
		definition.id = StringName(MASK_IDS[persona_id])
		definition.display_name_key = StringName(MASK_NAME_KEYS[persona_id])
		definition.description_key = StringName(MASK_DESCRIPTION_KEYS[persona_id])
		definition.is_crafted = true
		definition.can_recycle = false
		definition.can_be_synthesis_base = false
		definition.property_set = CardPropertySet.new()
		definition.image = ItemDetailPopup.property_icon_texture(persona_id)
		_definitions[persona_id] = definition
	definition.property_set.tags = [CardPropertySet.PROPERTY_PERSONA]
	definition.property_set.values = {
		persona_id: maxi(amount, 0),
	}
	return definition


static func card_for_persona(persona_id: StringName) -> CardItemState:
	if persona_id not in MASK_PERSONAS:
		return null
	var card := _cards.get(persona_id) as CardItemState
	if card == null:
		var order_index := MASK_PERSONAS.find(persona_id)
		card = CardItemState.new(
			-(order_index + 1),
			StringName(MASK_IDS[persona_id]),
			1,
			&"persona_mask",
			0,
		)
		_cards[persona_id] = card
	return card


static func persona_for_card(card: CardItemState) -> StringName:
	if card == null:
		return &""
	for persona_id in MASK_PERSONAS:
		if card.definition_id == StringName(MASK_IDS[persona_id]):
			return persona_id
	return &""


static func definition_for_card(
	card: CardItemState,
	protagonist_counts: Dictionary,
) -> CardItemDefinition:
	var persona_id := persona_for_card(card)
	if persona_id.is_empty():
		return null
	return definition_for_persona(
		persona_id,
		int(protagonist_counts.get(persona_id, 0)),
	)


static func sync_selection(selected_persona_id: StringName) -> void:
	for persona_id in MASK_PERSONAS:
		var card := card_for_persona(persona_id)
		if persona_id == selected_persona_id:
			card.assign_to(&"synthesis", &"persona")
		else:
			card.return_to_hand()


static func rule_uses_masks(rule: CardSlotRule) -> bool:
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
	for persona_id in MASK_PERSONAS:
		if StringName(MASK_IDS[persona_id]) in rule.accepted_item_ids:
			return true
	return false
