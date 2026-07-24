extends GutTest


func test_catalog_has_twenty_normal_and_three_special_items() -> void:
	var normal_count := 0
	var special_count := 0
	for item in DemoCatalog.all_items():
		if item.is_special:
			special_count += 1
		else:
			normal_count += 1
	assert_eq(normal_count, 20)
	assert_eq(special_count, 3)


func test_catalog_ids_are_unique_and_shapes_match_attribute_values() -> void:
	var seen: Dictionary = {}
	for item in DemoCatalog.all_items():
		assert_false(seen.has(item.id), "duplicate item id: %s" % item.id)
		seen[item.id] = true
		assert_gt(item.cell_count(), 0)
		assert_gt(item.price, 0)
		assert_gt(item.daily_limit, 0)


func test_each_lab_palette_has_all_normals_and_one_large_special() -> void:
	for task in DemoCatalog.all_tasks():
		var palette := DemoCatalog.lab_palette_items(task.id)
		assert_eq(palette.size(), 21)
		var normal_count := 0
		var special_count := 0
		for item in palette:
			if item.is_special:
				special_count += 1
				assert_eq(item.id, task.required_special_item_id)
				assert_gte(item.cell_count(), 7)
			else:
				normal_count += 1
		assert_eq(normal_count, 20)
		assert_eq(special_count, 1)


func test_task_masks_have_planned_sizes() -> void:
	assert_eq(DemoCatalog.task_by_id(&"teddy").bounds_size(), Vector2i(5, 5))
	assert_eq(DemoCatalog.task_by_id(&"teddy").mask_cells.size(), 19)
	assert_eq(DemoCatalog.task_by_id(&"goldfish").bounds_size(), Vector2i(9, 5))
	assert_eq(DemoCatalog.task_by_id(&"goldfish").mask_cells.size(), 23)
	assert_eq(DemoCatalog.task_by_id(&"tape").bounds_size(), Vector2i(7, 5))
	assert_eq(DemoCatalog.task_by_id(&"tape").mask_cells.size(), 29)
	assert_eq(DemoCatalog.item_by_id(&"special_fishbone").cells_at_rotation(0).size(), 7)
	var fish_bounds := PolyominoGeometry.bounds_size(
		DemoCatalog.item_by_id(&"special_fishbone").shape_cells
	)
	assert_lte(fish_bounds.x, 4)
	assert_lte(fish_bounds.y, 4)


func test_daily_templates_form_a_seven_day_connected_hole_free_loop() -> void:
	var template_ids: Dictionary = {}
	for day in range(1, 8):
		var task := DemoCatalog.daily_task_for_day(day)
		assert_eq(task.id, DemoCatalog.DAILY_TASK_ID)
		assert_lte(task.bounds_size().x, 4)
		assert_lte(task.bounds_size().y, 4)
		assert_true(task.required_special_item_id.is_empty())
		assert_true(_is_connected(task.mask_cells))
		assert_false(_has_internal_hole(task.mask_cells, task.bounds_size()))
		template_ids[DemoCatalog.daily_template_id_for_day(day)] = true
	assert_eq(template_ids.size(), 7)
	assert_eq(DemoCatalog.daily_template_id_for_day(8), &"daily_mon")


func test_each_store_has_seven_normal_items_per_refresh() -> void:
	for store_id in [
		DemoCatalog.STORE_BOOK,
		DemoCatalog.STORE_TOY,
		DemoCatalog.STORE_FLOWER,
		DemoCatalog.STORE_RECORD,
		DemoCatalog.STORE_FAST_FOOD,
	]:
		var total_units := 0
		var sku_count := 0
		for item in DemoCatalog.all_items():
			if item.store_id == store_id and not item.is_special:
				total_units += item.daily_limit
				sku_count += 1
		assert_eq(sku_count, 4)
		assert_eq(total_units, 7)


func test_recycling_station_has_no_merchandise() -> void:
	assert_has(DemoCatalog.STORE_IDS, DemoCatalog.STORE_RECYCLING)
	assert_false(DemoCatalog.RETAIL_STORE_IDS.has(DemoCatalog.STORE_RECYCLING))
	assert_true(DemoCatalog.items_for_store(DemoCatalog.STORE_RECYCLING).is_empty())


func _is_connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var visited: Dictionary = {cells[0]: true}
	var pending: Array[Vector2i] = [cells[0]]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + direction
			if neighbor in cells and not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return visited.size() == cells.size()


func _has_internal_hole(cells: Array[Vector2i], bounds: Vector2i) -> bool:
	var outside: Dictionary = {}
	var pending: Array[Vector2i] = [Vector2i(-1, -1)]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if outside.has(cell) or cell in cells:
			continue
		if cell.x < -1 or cell.y < -1 or cell.x > bounds.x or cell.y > bounds.y:
			continue
		outside[cell] = true
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(cell + direction)
	for y in range(bounds.y):
		for x in range(bounds.x):
			var cell := Vector2i(x, y)
			if cell not in cells and not outside.has(cell):
				return true
	return false
