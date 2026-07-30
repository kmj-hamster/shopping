extends GutTest


func test_three_retail_stores_and_recycling_are_open_each_day() -> void:
	for day in range(1, 22):
		var open_stores := ShopSchedule.open_store_ids(day)
		assert_eq(open_stores.size(), 4, "day %d" % day)
		assert_has(open_stores, DemoCatalog.STORE_RECYCLING)
		var unique: Dictionary = {}
		for store_id in open_stores:
			unique[store_id] = true
		assert_eq(unique.size(), 4, "day %d has duplicate stores" % day)


func test_first_three_nights_match_slot_card_demo_routes() -> void:
	assert_eq(ShopSchedule.open_store_ids(1), [
		DemoCatalog.STORE_TOY,
		DemoCatalog.STORE_FLOWER,
		DemoCatalog.STORE_FAST_FOOD,
		DemoCatalog.STORE_RECYCLING,
	])
	assert_eq(ShopSchedule.open_store_ids(2), [
		DemoCatalog.STORE_TOY,
		DemoCatalog.STORE_RECORD,
		DemoCatalog.STORE_BOOK,
		DemoCatalog.STORE_RECYCLING,
	])
	assert_eq(ShopSchedule.open_store_ids(3), [
		DemoCatalog.STORE_TOY,
		DemoCatalog.STORE_FLOWER,
		DemoCatalog.STORE_FAST_FOOD,
		DemoCatalog.STORE_RECYCLING,
	])


func test_no_store_rests_for_two_consecutive_days() -> void:
	for store_id in DemoCatalog.STORE_IDS:
		for day in range(1, 22):
			assert_true(
				ShopSchedule.is_store_open(store_id, day)
				or ShopSchedule.is_store_open(store_id, day + 1),
				"%s rests on days %d and %d" % [store_id, day, day + 1]
			)


func test_weekday_and_next_open_day_wrap_after_sunday() -> void:
	assert_eq(ShopSchedule.weekday_key(1), &"weekday.mon")
	assert_eq(ShopSchedule.weekday_key(8), &"weekday.mon")
	assert_eq(ShopSchedule.next_open_day(DemoCatalog.STORE_TOY, 2), 3)
	assert_eq(ShopSchedule.next_open_day(DemoCatalog.STORE_TOY, 7), 8)
