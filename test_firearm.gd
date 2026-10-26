extends SceneTree

# Firearms / attachments / U3 Inventory equipment migration test:
#   - ItemGameAsset gun+attachment JSON compatibility (data/assets/firearms_example.json)
#   - UseableGun: fire modes, firerate, ammo, reload, spread, recoil, hitscan damage
#   - attachment mount/detach + stat modifiers + inventory round-trip
#   - inventory slot state persistence (U3 Item.state analog)
#   - InventoryScreen equipment + attachment slots wired to PlayerEquipment

var _failures: Array[String] = []
var _definition_map: Dictionary = {}
var _player: Node3D
var _inventory: PlayerInventory
var _equipment: PlayerEquipment
var _gun: UseableGun
var _target: Damageable

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_asset_compatibility()
	await _setup_player()
	_test_fire_and_reload()
	_test_attachments()
	await _test_inventory_ui()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Firearm/attachment/inventory equipment tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("Firearm test failed: " + failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

func _test_asset_compatibility() -> void:
	var entries := _load_json("res://data/assets/firearms_example.json")
	_check(entries.size() == 5, "firearms example JSON contains gun + attachments")
	for entry in entries:
		var asset := ItemGameAsset.new()
		asset.populate(entry as Dictionary)
		var definition := asset.to_definition()
		_definition_map[definition.item_id] = definition

	var gun := _definition_map.get(&"json_rifle") as GunDefinition
	_check(gun != null, "gun asset converts to GunDefinition")
	if gun != null:
		_check(is_equal_approx(gun.range, 150.0) and is_equal_approx(gun.damage, 28.0), "gun range/damage fields parsed")
		_check(gun.magazine_capacity == 30 and gun.default_magazine == &"json_magazine", "gun magazine fields parsed")
		_check(gun.has_semi and gun.has_auto and gun.has_safety, "gun fire mode flags parsed")
		_check(gun.has_sight and gun.has_grip and gun.has_barrel and gun.has_tactical, "gun attachment hooks parsed")
		_check(gun.caliber == 2 and gun.firerate == 7, "gun caliber/firerate parsed")
		_check(is_equal_approx(gun.fire_interval_seconds(), 50.0 / 8.0), "U3 firerate converts to shot interval")

	var scope := _definition_map.get(&"json_scope") as AttachmentDefinition
	_check(scope != null and scope.kind == AttachmentDefinition.Kind.SIGHT, "sight asset kind parsed")
	if scope != null:
		_check(is_equal_approx(scope.zoom, 4.0) and is_equal_approx(scope.spread_multiplier, 0.75), "sight zoom/spread modifiers parsed")
	var grip := _definition_map.get(&"json_grip") as AttachmentDefinition
	_check(grip != null and grip.kind == AttachmentDefinition.Kind.GRIP and is_equal_approx(grip.recoil_multiplier, 0.65), "grip recoil modifier parsed")
	var magazine := _definition_map.get(&"json_magazine") as AttachmentDefinition
	_check(magazine != null and magazine.kind == AttachmentDefinition.Kind.MAGAZINE and magazine.capacity == 30, "magazine capacity parsed")
	var suppressor := _definition_map.get(&"json_suppressor") as AttachmentDefinition
	_check(suppressor != null and suppressor.kind == AttachmentDefinition.Kind.BARREL and suppressor.is_silenced, "barrel suppressor flags parsed")
	_check(is_equal_approx(suppressor.gunshot_rolloff_multiplier, 0.35), "barrel gunshot rolloff parsed")

func _setup_player() -> void:
	_player = Node3D.new()
	_player.name = "Player"
	root.add_child(_player)
	var life := PlayerLife.new()
	life.name = "Life"
	_player.add_child(life)
	_inventory = PlayerInventory.new()
	_inventory.name = "Inventory"
	_player.add_child(_inventory)
	for item_id in _definition_map:
		_inventory.register_definition(_definition_map[item_id])
	_equipment = PlayerEquipment.new()
	_equipment.name = "Equipment"
	_player.add_child(_equipment)
	var stance := PlayerStance.new()
	stance.name = "Stance"
	_player.add_child(stance)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.6, 0.0)
	_player.add_child(head)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	head.add_child(camera)

	var target_body := StaticBody3D.new()
	target_body.name = "Target"
	target_body.position = Vector3(0.0, 1.5, -6.0)
	root.add_child(target_body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.0, 1.2)
	collision.shape = box
	target_body.add_child(collision)
	_target = Damageable.new()
	_target.name = "Damageable"
	_target.max_health = 100.0
	target_body.add_child(_target)
	await physics_frame
	await physics_frame

	_inventory.add_item(&"json_rifle", 1)
	_inventory.add_item(&"json_magazine", 2)
	_inventory.add_item(&"json_scope", 1)
	_inventory.add_item(&"json_grip", 1)
	_inventory.add_item(&"json_suppressor", 1)
	var rifle_slot := _inventory.find_slot_index(&"json_rifle")
	_check(rifle_slot >= 0, "rifle added to inventory")
	_check(_equipment.equip_from_inventory(rifle_slot), "rifle equips from inventory")
	await process_frame
	_gun = _equipment.get_active_gun()
	_check(_gun != null, "equipping firearm activates UseableGun")
	if _gun != null:
		_check(_gun.get_ammo() == 30 and _gun.get_capacity() == 30, "default magazine is loaded with full ammo")
		_check(_gun.get_firemode() == GunDefinition.FireMode.AUTO, "default fire mode follows asset flags")

func _test_fire_and_reload() -> void:
	if _gun == null:
		return
	var health_before := _target.health
	_check(_equipment.primary_down(_player), "trigger fires the rifle")
	_check(_gun.get_ammo() == 29, "firing consumes one round")
	_check(_target.health < health_before, "bullet hitscan damages the target")
	_check(not _equipment.primary_down(_player), "firerate cooldown blocks an immediate second shot")
	_equipment.primary_up()
	_gun.advance(_gun.get_fire_interval() + 0.01)
	_check(_equipment.primary_down(_player), "shot fires after the cooldown advances")
	_equipment.primary_up()

	_gun.set_firemode(GunDefinition.FireMode.SAFETY)
	var safety_ammo := _gun.get_ammo()
	_check(not _equipment.primary_down(_player), "safety mode blocks firing")
	_check(_gun.get_ammo() == safety_ammo, "safety mode does not consume ammo")

	_gun.advance(_gun.get_fire_interval() + 0.01)
	_gun.set_firemode(GunDefinition.FireMode.AUTO)
	var auto_start := _gun.get_ammo()
	_check(_equipment.primary_down(_player), "auto mode fires the first round")
	_check(_gun.get_ammo() == auto_start - 1, "auto mode consumes ammo")
	_gun.advance(_gun.get_fire_interval() + 0.01)
	_check(_gun.get_ammo() == auto_start - 2, "auto mode keeps firing while held")
	_equipment.primary_up()
	var released_ammo := _gun.get_ammo()
	_gun.advance(_gun.get_fire_interval() + 0.01)
	_check(_gun.get_ammo() == released_ammo, "releasing the trigger stops automatic fire")
	_check(_equipment.toggle_firemode(), "fire mode can be cycled")
	_gun.set_firemode(GunDefinition.FireMode.SEMI)

	var magazines_before := _inventory.count_item(&"json_magazine")
	_gun.set_ammo(3)
	_check(_equipment.reload(_player), "reload takes a magazine from the inventory")
	_check(_gun.get_ammo() == 30, "reload fills the magazine")
	_check(_inventory.count_item(&"json_magazine") == magazines_before, "reload swaps the previous magazine back")
	var rifle_state: Dictionary = _inventory.get_slot_state(_inventory.find_slot_index(&"json_rifle"))
	_check(int(rifle_state.get("ammo", -1)) == 30, "gun state persists into the inventory slot")

	_gun.advance(_gun.get_fire_interval() + 0.01)
	_check(_equipment.primary_down(_player), "rifle fires after reload")
	_equipment.primary_up()
	var fired_state: Dictionary = _inventory.get_slot_state(_inventory.find_slot_index(&"json_rifle"))
	_check(int(fired_state.get("ammo", -1)) == _gun.get_ammo(), "each shot persists ammo into the inventory slot")

func _test_attachments() -> void:
	if _gun == null:
		return
	_gun.set_firemode(GunDefinition.FireMode.SEMI)
	var hip_spread := _gun.get_spread_radians()
	_check(_equipment.secondary_down(_player), "aiming down sights activates")
	_check(is_equal_approx(_gun.get_zoom(), 1.0), "iron sights have no zoom")
	_check(_gun.get_spread_radians() < hip_spread, "aiming reduces spread")
	_equipment.secondary_up(_player)

	var base_recoil := _gun.get_recoil_multiplier()
	_check(_equipment.attach_attachment(&"sight", &"json_scope", _player), "sight attaches from the inventory")
	_check(is_equal_approx(_gun.get_zoom(), 4.0), "sight zoom applies when aiming")
	var scoped_spread := _gun.get_spread_radians()
	_check(is_equal_approx(scoped_spread, hip_spread * 0.75), "sight spread modifier applies")
	_check(not _equipment.attach_attachment(&"sight", &"json_scope", _player), "attaching an already mounted sight fails")

	_check(_equipment.attach_attachment(&"grip", &"json_grip", _player), "grip attaches from the inventory")
	_check(is_equal_approx(_gun.get_recoil_multiplier(), base_recoil * 0.65), "grip recoil modifier applies")
	_check(_equipment.attach_attachment(&"barrel", &"json_suppressor", _player), "barrel/suppressor attaches")
	_check(_gun.get_attachment(&"barrel") == &"json_suppressor", "suppressor is mounted")
	_check(_equipment.detach_attachment(&"sight", _player), "sight detaches")
	_check(_gun.get_attachment(&"sight").is_empty(), "sight slot is cleared after detach")
	_check(_inventory.find_slot_index(&"json_scope") >= 0, "detached sight returns to the inventory")

func _test_inventory_ui() -> void:
	if _gun == null:
		return
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	hud.toggle_inventory()
	await process_frame
	_check(hud.inventory_screen.visible, "inventory screen opens")
	_check(hud.inventory_screen.equipment_model != null and hud.inventory_screen.attachment_model != null, "equipment and attachment models bind")
	_check(hud.inventory_screen.equipment_grid.get_slot(0).has_stack(), "primary equipment slot shows the rifle")

	var scope_index := _inventory.find_slot_index(&"json_scope")
	_check(scope_index >= 0, "scope is available in the backpack")
	hud.inventory_screen.grid.get_slot(scope_index).pressed.emit()
	await process_frame
	_check(_gun.get_attachment(&"sight") == &"json_scope", "clicking an attachment item installs it on the gun")
	_check(hud.inventory_screen.attachment_model.get_stack(0) != null, "attachment slot widget shows the mounted sight")

	hud.inventory_screen.attachment_grid.get_slot(0).pressed.emit()
	await process_frame
	_check(_gun.get_attachment(&"sight").is_empty(), "clicking the attachment slot detaches it")

	hud.inventory_screen.equipment_grid.get_slot(0).pressed.emit()
	await process_frame
	_check(_equipment.get_item(&"primary").is_empty(), "clicking the equipment slot unequips the rifle")
	_check(_equipment.get_active_gun() == null, "unequipping the firearm deactivates its useable")



