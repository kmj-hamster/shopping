extends GutTest


func test_initial_shelves_use_six_independent_units_with_duplicates() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	for store_id in SlotDemoCatalog.INITIAL_SHELF_ITEMS:
		var transaction := commerce.transaction_for_store(store_id)
		assert_not_null(transaction)
		assert_eq(transaction.shelf_slots.size(), 6, String(store_id))
		assert_eq(_unique_slot_ids(transaction).size(), 6, String(store_id))
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_eq(toy.shelf_slots[0].item_id, &"toy_cloth_scraps")
	assert_eq(toy.shelf_slots[1].item_id, &"toy_cloth_scraps")
	assert_ne(toy.shelf_slots[0].slot_id, toy.shelf_slots[1].slot_id)


func test_checkout_buys_selected_shelf_units_and_creates_owned_cards() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[0].slot_id).ok)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[1].slot_id).ok)
	var result := commerce.checkout_store(SlotDemoCatalog.STORE_TOY)
	assert_true(result.ok)
	assert_eq(result.total, 24)
	assert_eq(commerce.wallet.money, 96)
	assert_true(toy.shelf_slots[0].is_empty())
	assert_true(toy.shelf_slots[1].is_empty())
	assert_eq(commerce.inventory.size(), 2)
	assert_eq(commerce.inventory[0].definition_id, &"toy_cloth_scraps")
	assert_eq(commerce.inventory[0].location, CardItemState.Location.HAND)
	assert_ne(commerce.inventory[0].instance_id, commerce.inventory[1].instance_id)


func test_insufficient_funds_checkout_is_atomic() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(10), 7)
	var flower := commerce.transaction_for_store(SlotDemoCatalog.STORE_FLOWER)
	var slot := flower.shelf_slots[0]
	assert_true(flower.select_shelf_slot(slot.slot_id).ok)
	var result := commerce.checkout_store(SlotDemoCatalog.STORE_FLOWER)
	assert_false(result.ok)
	assert_eq(result.reason, CardShopTransaction.RESULT_INSUFFICIENT_FUNDS)
	assert_eq(commerce.wallet.money, 10)
	assert_eq(slot.item_id, &"flower_sunflower")
	assert_true(commerce.inventory.is_empty())
	assert_eq(flower.cart_count(), 1)


func test_new_day_only_refills_empty_slots_and_preserves_unsold_units() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 19)
	var fast_food := commerce.transaction_for_store(SlotDemoCatalog.STORE_FAST_FOOD)
	var preserved_slot := fast_food.shelf_slots[4]
	var preserved_item := preserved_slot.item_id
	assert_true(fast_food.select_shelf_slot(fast_food.shelf_slots[0].slot_id).ok)
	assert_true(commerce.checkout_store(SlotDemoCatalog.STORE_FAST_FOOD).ok)
	assert_true(fast_food.shelf_slots[0].is_empty())
	commerce.begin_new_day(2)
	assert_false(fast_food.shelf_slots[0].is_empty())
	assert_eq(preserved_slot.item_id, preserved_item)
	assert_eq(fast_food.shelf_slots.size(), 6)


func test_balloon_level_one_expands_toy_shelf_with_clockwork_moth() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	commerce.set_owner_level(&"balloon", 1)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_eq(toy.shelf_slots.size(), 7)
	assert_eq(toy.shelf_slots[6].item_id, &"toy_windup_moth")
	assert_eq(commerce.store_shelf_capacities[SlotDemoCatalog.STORE_TOY], 7)


func test_recycling_can_be_cancelled_or_paid_at_eighty_percent() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[0].slot_id).ok)
	assert_true(commerce.checkout_store(SlotDemoCatalog.STORE_TOY).ok)
	var card := commerce.inventory[0]
	assert_true(commerce.stage_recycle_card(card).ok)
	assert_eq(card.location, CardItemState.Location.RECYCLE)
	assert_eq(commerce.recycle_transaction.cart_total(), 9)
	assert_eq(commerce.recycle_transaction.cancel(), 1)
	assert_eq(card.location, CardItemState.Location.HAND)

	assert_true(commerce.stage_recycle_card(card).ok)
	var result := commerce.checkout_recycling()
	assert_true(result.ok)
	assert_eq(result.total, 9)
	assert_eq(commerce.wallet.money, 117)
	assert_true(commerce.inventory.is_empty())


func _unique_slot_ids(transaction: CardShopTransaction) -> Dictionary:
	var ids := {}
	for slot in transaction.shelf_slots:
		ids[slot.slot_id] = true
	return ids
