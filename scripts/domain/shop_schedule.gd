class_name ShopSchedule
extends RefCounted

const WEEKDAY_KEYS: Array[StringName] = [
	&"weekday.mon",
	&"weekday.tue",
	&"weekday.wed",
	&"weekday.thu",
	&"weekday.fri",
	&"weekday.sat",
	&"weekday.sun",
]

const OPEN_STORES: Array = [
	[DemoCatalog.STORE_BOOK, DemoCatalog.STORE_TOY, DemoCatalog.STORE_FAST_FOOD],
	[DemoCatalog.STORE_RECORD, DemoCatalog.STORE_FLOWER, DemoCatalog.STORE_BOOK],
	[DemoCatalog.STORE_TOY, DemoCatalog.STORE_FAST_FOOD, DemoCatalog.STORE_RECORD],
	[DemoCatalog.STORE_FLOWER, DemoCatalog.STORE_BOOK, DemoCatalog.STORE_TOY],
	[DemoCatalog.STORE_FAST_FOOD, DemoCatalog.STORE_RECORD, DemoCatalog.STORE_FLOWER],
	[DemoCatalog.STORE_BOOK, DemoCatalog.STORE_TOY, DemoCatalog.STORE_FAST_FOOD],
	[DemoCatalog.STORE_RECORD, DemoCatalog.STORE_FLOWER, DemoCatalog.STORE_BOOK],
]


static func weekday_index(day: int) -> int:
	return posmod(day - 1, WEEKDAY_KEYS.size())


static func weekday_key(day: int) -> StringName:
	return WEEKDAY_KEYS[weekday_index(day)]


static func open_store_ids(day: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for store_id in OPEN_STORES[weekday_index(day)]:
		result.append(store_id)
	return result


static func is_store_open(store_id: StringName, day: int) -> bool:
	return store_id in OPEN_STORES[weekday_index(day)]


static func next_open_day(store_id: StringName, day: int) -> int:
	for offset in range(1, 8):
		if is_store_open(store_id, day + offset):
			return day + offset
	return day
