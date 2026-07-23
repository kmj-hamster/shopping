extends GutTest


func test_normalize_removes_offset_and_orders_cells() -> void:
	var cells: Array[Vector2i] = [Vector2i(7, 5), Vector2i(6, 4), Vector2i(6, 5)]
	assert_eq(
		PolyominoGeometry.normalize(cells),
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	)


func test_four_rotations_return_to_original_shape() -> void:
	var shape := DemoCatalog.shape_cells(&"L3")
	assert_eq(PolyominoGeometry.rotated(shape, 4), PolyominoGeometry.normalize(shape))


func test_shape_bounds_follow_rotation() -> void:
	var shape := DemoCatalog.shape_cells(&"I3")
	assert_eq(PolyominoGeometry.bounds_size(shape), Vector2i(3, 1))
	assert_eq(PolyominoGeometry.bounds_size(PolyominoGeometry.rotated(shape, 1)), Vector2i(1, 3))

