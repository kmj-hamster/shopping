class_name PolyominoGeometry
extends RefCounted


static func normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if cells.is_empty():
		return result

	var min_x := cells[0].x
	var min_y := cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for cell in cells:
		result.append(Vector2i(cell.x - min_x, cell.y - min_y))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return result


static func rotate_clockwise(cells: Array[Vector2i]) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	for cell in cells:
		rotated.append(Vector2i(-cell.y, cell.x))
	return normalize(rotated)


static func rotated(cells: Array[Vector2i], rotation_steps: int) -> Array[Vector2i]:
	var result := normalize(cells)
	for _step in range(posmod(rotation_steps, 4)):
		result = rotate_clockwise(result)
	return result


static func bounds_size(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var normalized := normalize(cells)
	var max_x := 0
	var max_y := 0
	for cell in normalized:
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Vector2i(max_x + 1, max_y + 1)


static func translated(cells: Array[Vector2i], position: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell + position)
	return result
