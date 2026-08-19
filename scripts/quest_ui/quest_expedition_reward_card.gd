class_name QuestExpeditionRewardCard
extends CardHandCard


func _get_drag_data(at_position: Vector2) -> Variant:
	if card == null or definition == null or not drag_enabled:
		return null
	var grab_position := at_position if at_position.is_finite() else size * 0.5
	set_drag_preview(_build_drag_preview(grab_position))
	_begin_drag_visual(grab_position)
	return {
		"kind": &"expedition_reward",
		"reward_id": definition.id,
		"card": card,
		"grab_offset": grab_position,
	}
