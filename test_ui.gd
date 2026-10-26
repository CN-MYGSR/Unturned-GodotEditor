extends SceneTree

# UI/Sleek migration tests.
# Run headless:
#   D:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path D:\Rust2\UnturnedGodot --script res://test_ui.gd
#
# Coverage:
#   1. ported Sleek widgets (progress rounding, quality colours, factory)
#   2. reusable inventory grid + hotbar sharing one view model
#   3. architecture guard: scripts/sleek/* must not depend on gameplay classes
#   4. full HUD/screen integration: bars, inventory open/close, item use,
#      pause, death, respawn

var _failures: Array[String] = []
var _activated_slot := -1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_sleek_widgets()
	await _test_reusable_inventory_grid()
	_test_sleek_layer_is_decoupled()
	await _test_hud_integration()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("UI/Sleek tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("UI/Sleek test failed: " + failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _on_grid_activated(slot_index: int) -> void:
	_activated_slot = slot_index

func _test_sleek_widgets() -> void:
	var progress := SleekProgress.new()
	root.add_child(progress)
	progress.state = 0.5
	_check(progress.get_label_text() == "50%", "progress renders a percentage label")
	progress.set_rounding_mode(SleekProgress.RoundingMode.FLOOR)
	progress.state = 0.999
	_check(progress.get_label_text() == "99%", "progress supports floor rounding")
	progress.set_rounding_mode(SleekProgress.RoundingMode.CEIL)
	_check(progress.get_label_text() == "100%", "progress supports ceil rounding")

	var bad := SleekTheme.quality_color(0.0)
	var good := SleekTheme.quality_color(1.0)
	_check(bad.r > good.r and good.g > bad.g, "quality colour interpolates red to green")

	var button := Sleek.create_button("测试")
	root.add_child(button)
	_check(button.text == "测试", "Sleek factory creates buttons like Glazier.Get().CreateButton()")
	_check(button.is_clickable(), "Sleek buttons start clickable")
	button.set_clickable(false)
	_check(button.disabled, "Sleek button clickable flag maps to disabled")

	var box := Sleek.create_box("标题")
	root.add_child(box)
	_check(box.text == "标题", "Sleek box stores its text")
	await process_frame

	progress.free()
	button.free()
	box.free()

func _test_reusable_inventory_grid() -> void:
	var model := SleekInventoryModel.new(4)
	var grid := SleekInventory.new()
	grid.columns = 2
	root.add_child(grid)
	grid.bind_model(model)
	await process_frame
	_check(grid.get_slot_count() == 4, "grid builds one slot per model slot")
	_check(grid.get_slot(0) != null, "grid exposes its slots")

	var stack := SleekItemStack.new(&"bandage", "绷带", 3)
	model.set_stack(0, stack)
	await process_frame
	_check(grid.get_slot(0).has_stack(), "grid slot reflects model changes")
	_check(grid.get_slot(0).get_amount_text() == "×3", "slot shows the stack amount")

	grid.slot_activated.connect(_on_grid_activated)
	grid.get_slot(0).pressed.emit()
	await process_frame
	_check(_activated_slot == 0, "clicking a slot emits activation with its index")
	_check(grid.get_selected_index() == 0, "clicking a slot selects it")

	var hotbar := SleekHotbar.new()
	root.add_child(hotbar)
	hotbar.bind_model(model)
	await process_frame
	_check(hotbar.get_slot_count() == 10, "hotbar clamps to ten hotkeys regardless of model capacity")
	_check(hotbar.get_slot(0).has_stack(), "hotbar reuses the same model")
	_check(hotbar.get_slot(0).get_hotkey_text() == "1", "hotbar shows hotkey 1 for slot 0")
	_check(hotbar.get_slot(4).get_hotkey_text() == "5", "hotbar shows hotkey 5 for slot 4")
	_check(hotbar.get_slot(9).get_hotkey_text() == "0", "hotbar shows hotkey 0 for slot 9")

	grid.bind_model(null)
	hotbar.bind_model(null)
	grid.free()
	hotbar.free()

func _test_sleek_layer_is_decoupled() -> void:
	var grid_source := FileAccess.get_file_as_string("res://scripts/sleek/sleek_inventory.gd")
	_check(not grid_source.contains("PlayerInventory"), "reusable grid does not reference PlayerInventory")
	_check(not grid_source.contains("ItemDefinition"), "reusable grid does not reference ItemDefinition")
	var slot_source := FileAccess.get_file_as_string("res://scripts/sleek/sleek_slot.gd")
	_check(not slot_source.contains("PlayerInventory"), "reusable slot does not reference PlayerInventory")
	var model_source := FileAccess.get_file_as_string("res://scripts/sleek/sleek_inventory_model.gd")
	_check(not model_source.contains("PlayerInventory"), "sleek model layer does not reference PlayerInventory")
	var hud_source := FileAccess.get_file_as_string("res://scripts/ui/game_hud.gd")
	_check(not hud_source.contains("SleekSlot.new"), "HUD does not construct inventory slots")
	_check(not hud_source.contains("GridContainer"), "HUD does not build an inventory grid")

func _test_hud_integration() -> void:
	var actor := Node.new()
	root.add_child(actor)
	var life := PlayerLife.new()
	actor.add_child(life)
	var inventory := PlayerInventory.new()
	actor.add_child(inventory)
	var bandage := ItemDefinition.new()
	bandage.item_id = &"bandage"
	bandage.display_name = "绷带"
	bandage.max_stack = 3
	bandage.heal_amount = 25.0
	inventory.register_definition(bandage)

	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	hud.bind_player(life, inventory)
	await process_frame

	_check(hud.hud.health_bar.state == 1.0, "HUD health bar reflects life on bind")
	_check(hud.hud.stamina_bar.state == 1.0, "HUD stamina bar reflects life on bind")
	_check(hud.hud.hotbar.get_slot_count() == 10, "HUD hotbar uses the reusable hotbar widget")

	life.take_damage(50.0)
	await process_frame
	_check(is_equal_approx(hud.hud.health_bar.state, 0.5), "HUD health bar updates from the life signal")

	inventory.add_item(&"bandage", 1)
	await process_frame
	_check(hud.get_active_screen().is_empty(), "no screen is open by default")

	hud.toggle_inventory()
	await process_frame
	_check(hud.get_active_screen() == &"inventory", "inventory screen opens through the UI manager")
	_check(hud.inventory_screen.visible, "inventory screen becomes visible")
	_check(hud.inventory_screen.grid.get_slot(0).has_stack(), "inventory grid shows the picked up item")
	_check(hud.inventory_screen.grid.get_slot(0).stack.display_name == "绷带", "inventory grid uses definition names")
	_check(hud.inventory_screen.capacity_label.text.contains("重量"), "inventory screen shows the weight summary")

	hud.inventory_screen.grid.get_slot(0).pressed.emit()
	await process_frame
	_check(is_equal_approx(life.health, 75.0), "using an item through the inventory screen heals the player")
	_check(inventory.count_item(&"bandage") == 0, "used item is removed from the inventory")

	hud.toggle_inventory()
	await process_frame
	_check(hud.get_active_screen().is_empty(), "inventory screen closes again")

	hud.open_pause()
	await process_frame
	_check(hud.get_active_screen() == &"pause", "pause screen opens")
	_check(paused, "opening pause pauses the tree")
	hud.close_pause()
	await process_frame
	_check(hud.get_active_screen().is_empty(), "resume closes the pause screen")
	_check(not paused, "resume unpauses the tree")

	life.take_damage(999.0)
	await process_frame
	_check(hud.get_active_screen() == &"death", "death opens the death screen")
	hud.respawn()
	await process_frame
	_check(not life.is_dead, "respawn revives the player")
	_check(is_equal_approx(life.health, life.max_health), "respawn restores health")
	_check(hud.get_active_screen().is_empty(), "respawn closes the death screen")
	_check(hud.hud.health_bar.state == 1.0, "HUD updates after respawn")
	_check(hud.inventory_model.get_display_summary().contains("重量"), "player inventory model exposes a weight summary")

	if hud.inventory_model != null:
		hud.inventory_model.bind(null)
	if hud.inventory_screen != null:
		hud.inventory_screen.bind_model(null)
	if hud.hud != null and hud.hud.hotbar != null:
		hud.hud.hotbar.bind_model(null)
	await process_frame








