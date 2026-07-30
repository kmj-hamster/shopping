extends GutTest


func test_shop_scene_shows_six_independent_non_draggable_shelf_buttons() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var shop := await _spawn_shop(commerce, SlotDemoCatalog.STORE_TOY)
	assert_eq(shop.shelf_buttons.size(), 6)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_has(shop.shelf_buttons, toy.shelf_slots[0].slot_id)
	assert_has(shop.shelf_buttons, toy.shelf_slots[1].slot_id)
	assert_eq(
		(shop.shelf_buttons[toy.shelf_slots[0].slot_id] as Button).text,
		(shop.shelf_buttons[toy.shelf_slots[1].slot_id] as Button).text,
	)


func test_clicking_shelf_then_checkout_creates_card_in_bottom_hand() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var shop := await _spawn_shop(commerce, SlotDemoCatalog.STORE_TOY)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	var first_slot_id := toy.shelf_slots[0].slot_id
	shop._on_shelf_pressed(first_slot_id)
	assert_eq(toy.cart_count(), 1)
	assert_eq(commerce.inventory.size(), 0)
	shop._on_checkout_pressed()
	await get_tree().process_frame
	assert_eq(commerce.inventory.size(), 1)
	assert_eq(shop.hand_bar.card_views.size(), 1)
	assert_true(toy.shelf_slot(first_slot_id).is_empty())
	assert_eq(commerce.wallet.money, 108)


func test_recycle_scene_shows_staged_card_and_hand_accepts_it_back() -> void:
	var commerce := SlotCommerceState.new(PlayerWallet.new(120), 7)
	var toy := commerce.transaction_for_store(SlotDemoCatalog.STORE_TOY)
	assert_true(toy.select_shelf_slot(toy.shelf_slots[0].slot_id).ok)
	assert_true(commerce.checkout_store(SlotDemoCatalog.STORE_TOY).ok)
	var card := commerce.inventory[0]
	var recycle := await _spawn_recycle(commerce)
	recycle._on_card_dropped(card)
	await get_tree().process_frame
	assert_eq(recycle.staged_views.size(), 1)
	assert_true(recycle.hand_bar.card_views.is_empty())
	var drag_data := {"kind": &"card_item", "card": card, "source": &"recycle"}
	assert_true(recycle.hand_bar._can_drop_data(Vector2.ZERO, drag_data))
	recycle.hand_bar._drop_data(Vector2.ZERO, drag_data)
	await get_tree().process_frame
	assert_eq(card.location, CardItemState.Location.HAND)
	assert_eq(recycle.hand_bar.card_views.size(), 1)
	assert_true(recycle.staged_views.is_empty())


func _spawn_shop(commerce: SlotCommerceState, store_id: StringName) -> SlotShopScreen:
	var packed := load("res://scenes/slot_shop/slot_shop.tscn") as PackedScene
	var shop := packed.instantiate() as SlotShopScreen
	shop.commerce = commerce
	shop.store_id = store_id
	add_child_autoqfree(shop)
	await get_tree().process_frame
	return shop


func _spawn_recycle(commerce: SlotCommerceState) -> SlotRecycleScreen:
	var packed := load("res://scenes/slot_shop/slot_recycle.tscn") as PackedScene
	var recycle := packed.instantiate() as SlotRecycleScreen
	recycle.commerce = commerce
	add_child_autoqfree(recycle)
	await get_tree().process_frame
	return recycle
