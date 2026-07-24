class_name DailyGoalState
extends RefCounted

var day: int
var template_id: StringName
var submitted := false
var result_key: StringName = &""
var attribute_totals: Dictionary = {}


func _init(goal_day: int = 1, goal_template_id: StringName = &"") -> void:
	day = goal_day
	template_id = goal_template_id


func mark_submitted(dominant_result_key: StringName, totals: Dictionary) -> void:
	submitted = true
	result_key = dominant_result_key
	attribute_totals = totals.duplicate(true)
