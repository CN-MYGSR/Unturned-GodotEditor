extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var inventory := PlayerInventory.new()
	inventory.name = "Inventory"
	actor.add_child(inventory)
	var berry := ItemDefinition.new()
	berry.item_id = &"berry"
	berry.display_name = "Berry"
	berry.max_stack = 2
	inventory.register_definition(berry)
	await process_frame

	_test_base_contract(actor)
	_test_pickup(actor, inventory)
	await _test_door(actor)
	_test_storage(actor)
	_test_generator(actor)
	_test_harvest(actor, inventory)
	_test_ladder(actor)
	_test_salvage(actor)

	_test_dialogue_and_note(actor)
	if failures.is_empty():
		print("Interactable tests passed")
		quit(0)
		return
	for failure in failures:
		push_error("Interactable test failed: " + failure)
	quit(1)

func _test_base_contract(actor: Node3D) -> void:
	var target := Interactable.new()
	root.add_child(target)
	target.one_shot = true
	_expect(target.can_interact(actor), "base interactable can be used")
	_expect(target.interact(actor), "base interaction succeeds")
	_expect(not target.interact(actor), "one-shot interaction cannot repeat")
	_expect(target.get_state().has("has_interacted"), "base interaction state is serializable")
	target.update_state({"has_interacted": false, "interaction_enabled": false})
	_expect(not target.can_interact(actor), "disabled interaction is rejected")
	target.queue_free()

func _test_pickup(actor: Node3D, inventory: PlayerInventory) -> void:
	inventory.slot_capacity = 1
	inventory.max_weight = 100.0
	var pickup := PickupInteractable.new()
	pickup.item_id = &"berry"
	pickup.amount = 3
	root.add_child(pickup)
	_expect(pickup.interact(actor), "pickup transfers available items")
	_expect(inventory.count_item(&"berry") == 2, "pickup respects item stack limit")
	_expect(pickup.amount == 1, "pickup keeps leftover amount")
	_expect(not pickup.interact(actor), "pickup fails when inventory has no space")
	inventory.remove_item(&"berry", 1)
	_expect(pickup.interact(actor), "pickup retries after space becomes available")
	_expect(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "fully collected pickup is removed")
	inventory.remove_item(&"berry", inventory.count_item(&"berry"))

func _test_door(actor: Node3D) -> void:
	var door := InteractableDoor.new()
	door.locked = true
	root.add_child(door)
	await process_frame
	_expect(not door.can_interact(actor), "locked door blocks interaction")
	_expect(str(door.check_hint(actor).text) == "上锁", "locked door still presents a hint")
	door.locked = false
	_expect(door.interact(actor), "unlocked door toggles")
	_expect(door.is_open, "door open state changes")
	var state := door.get_state()
	var restored := InteractableDoor.new()
	root.add_child(restored)
	await process_frame
	restored.update_state(state)
	_expect(restored.is_open, "door state restores")
	door.queue_free()
	restored.queue_free()

func _test_storage(actor: Node3D) -> void:
	var storage := InteractableStorage.new()
	storage.capacity = 1
	root.add_child(storage)
	_expect(storage.add_stack(&"wood", 5) == 0, "storage accepts item stack")
	_expect(storage.add_stack(&"stone", 1) == 1, "storage enforces slot capacity")
	var removed := storage.remove_stack(0, 2)
	_expect(removed.get("amount", 0) == 2, "storage removes partial stack")
	_expect(storage.stacks[0].amount == 3, "storage preserves remainder")
	var restored := InteractableStorage.new()
	root.add_child(restored)
	restored.update_state(storage.get_state())
	_expect(restored.stacks.size() == 1 and restored.stacks[0].amount == 3, "storage contents serialize")
	storage.queue_free()
	restored.queue_free()
	_expect(actor != null, "storage test actor is valid")

func _test_generator(actor: Node3D) -> void:
	var generator := InteractableGenerator.new()
	root.add_child(generator)
	await process_frame
	_expect(not generator.interact(actor), "empty generator cannot start")
	_expect(is_equal_approx(generator.add_fuel(10.0), 0.0), "generator accepts fuel")
	_expect(generator.interact(actor), "fueled generator starts")
	_expect(generator.is_powered, "generator power state updates")
	_expect(generator.interact(actor), "generator can stop")
	_expect(not generator.is_powered, "generator stops supplying power")
	generator.queue_free()

func _test_harvest(actor: Node3D, inventory: PlayerInventory) -> void:
	var harvestable := InteractableHarvestable.new()
	harvestable.item_id = &"berry"
	harvestable.yield_amount = 1
	root.add_child(harvestable)
	_expect(harvestable.interact(actor), "harvest transfers yield to inventory")
	_expect(harvestable.is_depleted, "harvestable depletes after collection")
	_expect(not harvestable.can_interact(actor), "depleted harvestable cannot be collected")
	_expect(inventory.count_item(&"berry") == 1, "harvest adds yielded item")
	harvestable.queue_free()
	inventory.remove_item(&"berry", inventory.count_item(&"berry"))

func _test_ladder(actor: Node3D) -> void:
	var ladder := InteractableLadder.new()
	root.add_child(ladder)
	_expect(ladder.interact(actor), "ladder interaction succeeds")
	_expect(actor.has_meta("ladder_climb_speed"), "ladder exposes climb data to actor")
	_expect(is_equal_approx(float(actor.get_meta("ladder_climb_speed")), ladder.climb_speed), "ladder climb speed is passed")
	ladder.queue_free()

func _test_salvage(actor: Node3D) -> void:
	var salvageable := InteractableSalvageable.new()
	salvageable.allow_unowned_salvage = false
	salvageable.owner_id = 42
	root.add_child(salvageable)
	_expect(not salvageable.can_salvage(actor), "owned object rejects other users")
	actor.set_meta("owner_id", 42)
	_expect(salvageable.can_salvage(actor), "owner can salvage owned object")
	salvageable.queue_free()

func _test_dialogue_and_note(actor: Node3D) -> void:
	var dialogue := InteractableDialogue.new()
	dialogue.dialogue_id = &"intro"
	dialogue.display_name = "Guard"
	dialogue.required_actor_meta = "has_pass"
	dialogue.required_actor_meta_value = true
	root.add_child(dialogue)
	_expect(not dialogue.can_interact(actor), "dialogue conditions block interaction")
	actor.set_meta("has_pass", true)
	_expect(dialogue.can_interact(actor), "dialogue conditions allow qualified actor")
	_expect(dialogue.get_dialogue_target_name() == "Guard", "dialogue exposes target display name")

	var note := InteractableNote.new()
	note.note_text = "Read me"
	note.quest_object_id = &"clue"
	root.add_child(note)
	actor.set_meta("ui_cursor_visible", true)
	_expect(not note.can_interact(actor), "note blocks interaction while UI cursor is visible")
	actor.set_meta("ui_cursor_visible", false)
	_expect(note.can_interact(actor), "note can be read when gameplay UI is closed")
	_expect(note.interact(actor), "note interaction emits readable content")
	dialogue.queue_free()
	note.queue_free()
	actor.remove_meta("has_pass")
	actor.remove_meta("ui_cursor_visible")

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


