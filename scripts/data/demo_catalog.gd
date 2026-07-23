class_name DemoCatalog
extends RefCounted

const STORE_BOOK := &"book"
const STORE_TOY := &"toy"
const STORE_FLOWER := &"flower"
const STORE_RECORD := &"record"
const STORE_FAST_FOOD := &"fast_food"

const ITEM_ROWS := [
	[&"book_period", &"item.book_period", STORE_BOOK, &"M1", ItemDefinition.ATTRIBUTE_FOG, 10, 3, false],
	[&"book_bookmark", &"item.book_bookmark", STORE_BOOK, &"I2", ItemDefinition.ATTRIBUTE_FOG, 12, 2, false],
	[&"book_manga", &"item.book_manga", STORE_BOOK, &"O4", ItemDefinition.ATTRIBUTE_FOG, 16, 1, false],
	[&"book_clipping", &"item.book_clipping", STORE_BOOK, &"P5", ItemDefinition.ATTRIBUTE_FOG, 18, 1, false],
	[&"toy_marble", &"item.toy_marble", STORE_TOY, &"M1", ItemDefinition.ATTRIBUTE_MIRROR, 10, 3, false],
	[&"toy_blocks", &"item.toy_blocks", STORE_TOY, &"L3", ItemDefinition.ATTRIBUTE_MIRROR, 14, 2, false],
	[&"toy_puzzle", &"item.toy_puzzle", STORE_TOY, &"S4", ItemDefinition.ATTRIBUTE_MIRROR, 16, 1, false],
	[&"toy_robot", &"item.toy_robot", STORE_TOY, &"U5", ItemDefinition.ATTRIBUTE_MIRROR, 18, 1, false],
	[&"flower_seed", &"item.flower_seed", STORE_FLOWER, &"M1", ItemDefinition.ATTRIBUTE_LAMP, 10, 3, false],
	[&"flower_lavender", &"item.flower_lavender", STORE_FLOWER, &"I3", ItemDefinition.ATTRIBUTE_FOG, 14, 2, false],
	[&"flower_sunflower", &"item.flower_sunflower", STORE_FLOWER, &"T4", ItemDefinition.ATTRIBUTE_LAMP, 16, 1, false],
	[&"flower_roots", &"item.flower_roots", STORE_FLOWER, &"Y5", ItemDefinition.ATTRIBUTE_LAMP, 18, 1, false],
	[&"record_needle", &"item.record_needle", STORE_RECORD, &"M1", ItemDefinition.ATTRIBUTE_LAMP, 10, 3, false],
	[&"record_ticket", &"item.record_ticket", STORE_RECORD, &"I2", ItemDefinition.ATTRIBUTE_MIRROR, 12, 2, false],
	[&"record_headphones", &"item.record_headphones", STORE_RECORD, &"L4", ItemDefinition.ATTRIBUTE_LAMP, 16, 1, false],
	[&"record_extension", &"item.record_extension", STORE_RECORD, &"L5", ItemDefinition.ATTRIBUTE_LAMP, 18, 1, false],
	[&"fast_sugar", &"item.fast_sugar", STORE_FAST_FOOD, &"M1", ItemDefinition.ATTRIBUTE_FLOWER, 10, 3, false],
	[&"fast_straw", &"item.fast_straw", STORE_FAST_FOOD, &"I3", ItemDefinition.ATTRIBUTE_FLOWER, 14, 2, false],
	[&"fast_hash_brown", &"item.fast_hash_brown", STORE_FAST_FOOD, &"O4", ItemDefinition.ATTRIBUTE_FLOWER, 16, 1, false],
	[&"fast_fries", &"item.fast_fries", STORE_FAST_FOOD, &"U5", ItemDefinition.ATTRIBUTE_FLOWER, 18, 1, false],
	[&"special_teddy", &"item.special_teddy", STORE_TOY, &"P5", ItemDefinition.ATTRIBUTE_MIRROR, 22, 1, true],
	[&"special_fishbone", &"item.special_fishbone", STORE_FAST_FOOD, &"X5", ItemDefinition.ATTRIBUTE_MIRROR, 20, 1, true],
	[&"special_tape", &"item.special_tape", STORE_RECORD, &"O4", ItemDefinition.ATTRIBUTE_MIRROR, 22, 1, true],
]

const LAB_ITEM_IDS := {
	&"teddy": [&"special_teddy", &"book_manga", &"toy_blocks", &"flower_sunflower", &"fast_straw"],
	&"goldfish": [&"special_fishbone", &"fast_fries", &"flower_roots", &"record_headphones", &"toy_blocks", &"book_period"],
	&"tape": [&"special_tape", &"flower_roots", &"fast_fries", &"book_clipping", &"record_extension", &"book_bookmark", &"toy_blocks"],
}


static func all_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for row in ITEM_ROWS:
		var item := ItemDefinition.new()
		item.id = row[0]
		item.display_name_key = row[1]
		item.store_id = row[2]
		item.shape_code = row[3]
		item.shape_cells = shape_cells(row[3])
		item.attribute = row[4]
		item.price = row[5]
		item.daily_limit = row[6]
		item.is_special = row[7]
		result.append(item)
	return result


static func item_by_id(item_id: StringName) -> ItemDefinition:
	for item in all_items():
		if item.id == item_id:
			return item
	return null


static func all_tasks() -> Array[TaskDefinition]:
	var tasks: Array[TaskDefinition] = []
	tasks.append(_task(
		&"teddy",
		&"task.teddy.title",
		&"task.teddy.description",
		["XX.XX", "XXXXX", ".XXX.", "XXXXX", ".X.X."],
		&"special_teddy",
		STORE_TOY,
		TaskDefinition.AttributeRule.MIRROR_STRICT
	))
	tasks.append(_task(
		&"goldfish",
		&"task.goldfish.title",
		&"task.goldfish.description",
		["...XX....", ".XXXX..X.", "XXXXXXXXX", ".XXXX..X.", "...XX...."],
		&"special_fishbone",
		STORE_FAST_FOOD,
		TaskDefinition.AttributeRule.LAMP_OR_FLOWER
	))
	tasks.append(_task(
		&"tape",
		&"task.tape.title",
		&"task.tape.description",
		["XXXXXXX", "XX.X.XX", "XX.X.XX", "XXXXXXX", ".XXXXX."],
		&"special_tape",
		STORE_RECORD,
		TaskDefinition.AttributeRule.NONE
	))
	return tasks


static func task_by_id(task_id: StringName) -> TaskDefinition:
	for task in all_tasks():
		if task.id == task_id:
			return task
	return null


static func create_lab_pieces(task_id: StringName) -> Array[PuzzlePieceState]:
	var pieces: Array[PuzzlePieceState] = []
	var uid := 1
	var ids: Array = LAB_ITEM_IDS.get(task_id, [])
	for item_id in ids:
		pieces.append(PuzzlePieceState.new(uid, item_by_id(item_id)))
		uid += 1
	return pieces


static func shape_cells(shape_code: StringName) -> Array[Vector2i]:
	match shape_code:
		&"M1":
			return [Vector2i(0, 0)]
		&"I2":
			return [Vector2i(0, 0), Vector2i(1, 0)]
		&"I3":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		&"L3":
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
		&"O4":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		&"T4":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]
		&"S4":
			return [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]
		&"L4":
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
		&"P5":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]
		&"U5":
			return [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
		&"X5":
			return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
		&"Y5":
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 1)]
		&"L5":
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)]
		_:
			return []


static func _task(
	task_id: StringName,
	title_key: StringName,
	description_key: StringName,
	mask_rows: Array[String],
	required_item_id: StringName,
	store_id: StringName,
	rule: TaskDefinition.AttributeRule
) -> TaskDefinition:
	var task := TaskDefinition.new()
	task.id = task_id
	task.display_name_key = title_key
	task.description_key = description_key
	task.mask_cells = _mask_cells(mask_rows)
	task.required_special_item_id = required_item_id
	task.submit_store_id = store_id
	task.attribute_rule = rule
	return task


static func _mask_cells(rows: Array[String]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] == "X":
				cells.append(Vector2i(x, y))
	return cells
