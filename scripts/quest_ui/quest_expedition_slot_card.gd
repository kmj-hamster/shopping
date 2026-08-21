class_name QuestExpeditionSlotCard
extends CardHandCard


func _card_remained_at_drag_origin() -> bool:
	# Expedition slots are a presentation draft: the CardItemState deliberately
	# remains in HAND until the room is committed. Ask the owning slot whether it
	# rebound this same card during the drop; model location alone cannot tell a
	# same-slot drop from a move to another slot.
	var holder := get_parent()
	if holder == null:
		return false
	var slot := holder.get_parent() as QuestExpeditionCardSlot
	return slot != null and slot.card == card


func _animate_return_to_origin() -> void:
	# Starting a drag releases the draft back to the hand immediately. A missed
	# drop therefore belongs to the newly restored hand view, not this stale slot
	# view; restoring this node would leave a phantom duplicate in the empty slot.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
