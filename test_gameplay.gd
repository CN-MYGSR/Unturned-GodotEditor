extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var inventory := PlayerInventory.new()
	inventory.name = "Inventory"
	actor.add_child(inventory)
	var life := PlayerLife.new()
	life.name = "Life"
	actor.add_child(life)
	await process_frame

	var medkit := ItemDefinition.new()
	medkit.item_id = &"medkit"
	medkit.display_name = "Medkit"
	medkit.max_stack = 3
	medkit.weight = 1.0
	medkit.heal_amount = 25.0
	inventory.register_definition(medkit)
	_expect(inventory.add_item(&"medkit", 5) == 0, "add item remainder")
	_expect(inventory.count_item(&"medkit") == 5, "stack count")
	_expect(inventory.slots.size() == 2, "stack split")
	_expect(is_equal_approx(inventory.current_weight(), 5.0), "weight calculation")
	_expect(inventory.remove_item(&"medkit", 2), "remove item")
	_expect(inventory.count_item(&"medkit") == 3, "remove count")

	life.take_damage(50.0)
	_expect(inventory.use_item(&"medkit", life), "use consumable")
	_expect(is_equal_approx(life.health, 75.0), "healing effect")
	_expect(inventory.count_item(&"medkit") == 2, "consumable decrement")

	var pickup := PickupInteractable.new()
	pickup.item_id = &"medkit"
	pickup.amount = 2
	root.add_child(pickup)
	_expect(pickup.interact(actor), "pickup interaction")
	_expect(inventory.count_item(&"medkit") == 4, "pickup inventory transfer")

	life.take_damage(100.0)
	_expect(life.is_dead, "death state")
	_expect(inventory.add_item(&"missing", 1) == 1, "unknown item rejected")
	print("Gameplay tests passed")
	quit(0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		push_error("Gameplay test failed: " + label)
		quit(1)