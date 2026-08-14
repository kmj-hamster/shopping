class_name QuestSynthesisBackgroundInput
extends Control

const PASSTHROUGH_MARGIN := 12.0

var passthrough_controls: Array[Control] = []


func set_passthrough_controls(controls: Array) -> void:
	passthrough_controls.clear()
	for raw_control in controls:
		var control := raw_control as Control
		if control != null:
			passthrough_controls.append(control)


func _has_point(point: Vector2) -> bool:
	var global_point := get_global_transform_with_canvas() * point
	for control in passthrough_controls:
		if (
			is_instance_valid(control)
			and control.visible
			and control.get_global_rect().grow(PASSTHROUGH_MARGIN).has_point(global_point)
		):
			return false
	return Rect2(Vector2.ZERO, size).has_point(point)
