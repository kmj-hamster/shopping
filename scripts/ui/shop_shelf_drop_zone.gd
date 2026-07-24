class_name ShopShelfDropZone
extends PanelContainer

signal pending_purchase_return_requested(piece: PuzzlePieceState)

var transaction: ShopTransaction


func setup(shop_transaction: ShopTransaction) -> void:
	transaction = shop_transaction


func can_return_drag(data: Variant) -> bool:
	return pending_piece_from_drag(data) != null


func request_return(data: Variant) -> bool:
	var piece := pending_piece_from_drag(data)
	if piece == null:
		return false
	pending_purchase_return_requested.emit(piece)
	return true


func pending_piece_from_drag(data: Variant) -> PuzzlePieceState:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != &"puzzle_piece":
		return null
	if data.get("source") != &"board":
		return null
	var piece := data.get("original") as PuzzlePieceState
	if transaction == null or not transaction.can_remove_from_cart(piece):
		return null
	return piece


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return can_return_drag(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	request_return(data)
