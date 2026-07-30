class_name ActiveSynthesisState
extends RefCounted

var recipe_id: StringName
var input_instance_ids: Array[int] = []
var output_id: StringName
var preview_key: StringName
var duration_seconds := 0.0
var remaining_seconds := 0.0


func _init(
	selected_recipe_id: StringName = &"",
	selected_input_ids: Array[int] = [],
	selected_output_id: StringName = &"",
	selected_preview_key: StringName = &"",
	selected_duration: float = 0.0,
) -> void:
	recipe_id = selected_recipe_id
	input_instance_ids = selected_input_ids.duplicate()
	output_id = selected_output_id
	preview_key = selected_preview_key
	duration_seconds = maxf(0.0, selected_duration)
	remaining_seconds = duration_seconds


func progress_ratio() -> float:
	if duration_seconds <= 0.0:
		return 1.0
	return clampf(1.0 - remaining_seconds / duration_seconds, 0.0, 1.0)


func advance(delta: float) -> bool:
	remaining_seconds = maxf(0.0, remaining_seconds - maxf(0.0, delta))
	return remaining_seconds <= 0.0
