class_name QuestExpeditionRewardTarget
extends Control

signal reward_collected


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("kind") == &"expedition_reward"


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	reward_collected.emit()
