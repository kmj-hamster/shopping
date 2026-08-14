class_name PlayerWallet
extends RefCounted

var money := 0


func _init(starting_money: int = 0) -> void:
	money = starting_money
