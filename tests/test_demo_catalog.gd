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


func test_task_masks_have_planned_sizes() -> void:
	assert_eq(DemoCatalog.task_by_id(&"teddy").bounds_size(), Vector2i(5, 5))
	assert_eq(DemoCatalog.task_by_id(&"teddy").mask_cells.size(), 19)
	assert_eq(DemoCatalog.task_by_id(&"goldfish").bounds_size(), Vector2i(9, 5))
	assert_eq(DemoCatalog.task_by_id(&"goldfish").mask_cells.size(), 23)
	assert_eq(DemoCatalog.task_by_id(&"tape").bounds_size(), Vector2i(7, 5))
	assert_eq(DemoCatalog.task_by_id(&"tape").mask_cells.size(), 29)


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
