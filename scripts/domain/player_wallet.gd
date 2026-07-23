class_name PlayerWallet
extends RefCounted

var money := 100


func _init(starting_money: int = 100) -> void:
	money = starting_money
