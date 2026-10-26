extends Node
class_name PlayerEquipment

# Equipment slots for the single-player player. U3 keeps equipped items in the
# inventory and has PlayerEquipment reference those ItemJar entries; this port
# keeps the same model: slots store item ids plus the inventory slot/state that
# they came from, and the item stays in the inventory.
#
# Firearms additionally activate a persistent UseableGun whose ammo/attachment/
# firemode state is stored in the inventory slot's `state` dictionary (the same
# place U3 stores Item.state bytes). Input entry points (primary/secondary/
# reload/firemode) are routed here from GameHUD.

signal equipped(slot: StringName, item_id: StringName)
signal unequipped(slot: StringName, item_id: StringName)
signal equipment_changed
signal item_used(slot: StringName, item_id: StringName)
signal weapon_changed(item_id: StringName)
signal ammo_changed(ammo: int, capacity: int)
signal firemode_changed(mode: int, mode_name: StringName)
signal aiming_changed(aiming: bool, zoom: float)
signal attachment_changed(kind: StringName, attachment_id: StringName)
signal weapon_state_changed(item_id: StringName, state: Dictionary)
signal recoil_applied(amount: Vector2)
signal noise_made(position: Vector3, radius: float)

const ARM_SLOTS := [&"primary", &"secondary", &"melee"]
const FIREARM_SLOT_PRIORITY := [&"primary", &"secondary"]

@export var inventory_path: NodePath = ^"../Inventory"
@export var supported_slots: PackedStringArray = ["primary", "secondary", "melee", "hat", "mask", "glasses", "shirt", "vest", "pants", "backpack"]
var slots: Dictionary = {}
var item_metadata: Dictionary = {}
var inventory: PlayerInventory

var active_useable: UseableItem = null
var active_item_id: StringName = &""
var _active_slot_index := -1

func _ready() -> void:
	_resolve_inventory()

func _resolve_inventory() -> void:
	var found := get_node_or_null(inventory_path) as PlayerInventory
	if found != null:
		bind_inventory(found)

func bind_inventory(value: PlayerInventory) -> void:
	if inventory != null and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = value
	if inventory != null and not inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.connect(_on_inventory_changed)
	_refresh_active_useable()

func equip(slot: StringName, item_id: StringName, metadata: Dictionary = {}) -> bool:
	if not supported_slots.has(String(slot)) or item_id.is_empty(): return false
	var previous := StringName(slots.get(slot, ""))
	if previous == item_id:
		return true
	if not previous.is_empty(): unequipped.emit(slot, previous)
	slots[slot] = item_id
	item_metadata[item_id] = metadata.duplicate(true)
	equipped.emit(slot, item_id)
	equipment_changed.emit()
	_refresh_active_useable()
	return true

func unequip(slot: StringName) -> StringName:
	var item_id := StringName(slots.get(slot, ""))
	if item_id.is_empty(): return &""
	slots.erase(slot)
	unequipped.emit(slot, item_id)
	equipment_changed.emit()
	_refresh_active_useable()
	return item_id

func get_item(slot: StringName) -> StringName:
	return StringName(slots.get(slot, ""))

func get_metadata(item_id: StringName) -> Dictionary:
	return item_metadata.get(item_id, {}).duplicate(true)

func get_definition(slot: StringName) -> ItemDefinition:
	if inventory == null: return null
	return inventory.definitions.get(get_item(slot)) as ItemDefinition

func get_item_state(slot: StringName) -> Dictionary:
	var item_id := get_item(slot)
	if item_id.is_empty(): return {}
	var metadata: Dictionary = item_metadata.get(item_id, {})
	return (metadata.get("state", {}) as Dictionary).duplicate(true)

func is_equipped(item_id: StringName) -> bool:
	return slots.values().has(item_id)

func is_arm_slot(slot: StringName) -> bool:
	return ARM_SLOTS.has(slot)

# U3 equipment references an inventory slot; the item is NOT removed from the
# inventory. `target_slot` overrides the item's equipment_slot (e.g. forcing a
# primary item into the secondary slot).
func equip_from_inventory(slot_index: int, target_slot: StringName = &"") -> bool:
	if inventory == null: return false
	if slot_index < 0 or slot_index >= inventory.slots.size(): return false
	var entry: Dictionary = inventory.slots[slot_index]
	var item_id := StringName(entry.get("item_id", ""))
	if item_id.is_empty(): return false
	var definition := inventory.definitions.get(item_id) as ItemDefinition
	var resolved := target_slot
	if resolved.is_empty():
		resolved = definition.equipment_slot if definition != null else &""
	if resolved.is_empty() or not supported_slots.has(String(resolved)): return false
	var state: Dictionary = (entry.get("state", {}) as Dictionary).duplicate(true)
	return equip(resolved, item_id, {"slot_index": slot_index, "state": state})

func equip_active_item() -> bool:
	if inventory == null or inventory.active_slot < 0: return false
	return equip_from_inventory(inventory.active_slot)

func equip_hotbar(hotbar_index: int) -> bool:
	if inventory == null or hotbar_index < 0 or hotbar_index >= inventory.hotbar.size(): return false
	var slot_index := int(inventory.hotbar[hotbar_index])
	if slot_index < 0: return false
	return equip_from_inventory(slot_index)

func use_equipped(slot: StringName, actor: Node) -> bool:
	var item_id := get_item(slot)
	if item_id.is_empty() or inventory == null or actor == null: return false
	if not inventory.use_item(item_id, actor): return false
	item_used.emit(slot, item_id)
	return true

func use_arm_slot(actor: Node) -> bool:
	for slot in ARM_SLOTS:
		if not get_item(slot).is_empty() and use_equipped(slot, actor): return true
	return false

# ---------------------------------------------------------------------------
# Active useable (firearms)
# ---------------------------------------------------------------------------

func get_active_useable() -> UseableItem:
	return active_useable

func get_active_gun() -> UseableGun:
	return active_useable as UseableGun

func get_active_item_id() -> StringName:
	return active_item_id

func primary_down(actor: Node3D = null) -> bool:
	var target := actor if actor != null else _default_actor()
	var gun := get_active_gun()
	if gun != null: return gun.trigger_down(target)
	if not active_item_id.is_empty() and inventory != null and target != null:
		if inventory.use_item(active_item_id, target): return true
	# Non-firearm arm slots (U3 melee useables) still fire through the inventory.
	if inventory != null and target != null:
		for slot in ARM_SLOTS:
			var item_id := get_item(slot)
			if not item_id.is_empty() and inventory.use_item(item_id, target): return true
	return false

func primary_up() -> void:
	var gun := get_active_gun()
	if gun != null: gun.trigger_up()

func secondary_down(actor: Node3D = null) -> bool:
	var gun := get_active_gun()
	if gun != null: return gun.set_aiming(true)
	return false

func secondary_up(_actor: Node3D = null) -> void:
	var gun := get_active_gun()
	if gun != null: gun.set_aiming(false)

func set_aiming(enabled: bool) -> bool:
	var gun := get_active_gun()
	return gun.set_aiming(enabled) if gun != null else false

func reload(actor: Node3D = null) -> bool:
	var gun := get_active_gun()
	return gun.reload(actor if actor != null else _default_actor()) if gun != null else false

func toggle_firemode(_actor: Node3D = null) -> bool:
	var gun := get_active_gun()
	return gun.toggle_firemode() if gun != null else false

func attach_attachment(kind: StringName, attachment_id: StringName, actor: Node3D = null) -> bool:
	var gun := get_active_gun()
	return gun.attach(kind, attachment_id, actor if actor != null else _default_actor()) if gun != null else false

func detach_attachment(kind: StringName, actor: Node3D = null) -> bool:
	var gun := get_active_gun()
	return gun.detach(kind, actor if actor != null else _default_actor()) if gun != null else false

func get_attachment(kind: StringName) -> StringName:
	var gun := get_active_gun()
	return gun.get_attachment(kind) if gun != null else &""

func get_attachments() -> Dictionary:
	var gun := get_active_gun()
	return gun.get_attachments() if gun != null else {}

func get_active_gun_state() -> Dictionary:
	var gun := get_active_gun()
	return gun.get_state() if gun != null else {}

func _refresh_active_useable() -> void:
	var slot := _resolve_active_arm_slot()
	if slot.is_empty():
		_deactivate_useable()
		return
	var item_id := get_item(slot)
	if item_id.is_empty() or inventory == null:
		_deactivate_useable()
		return
	var definition := inventory.definitions.get(item_id) as ItemDefinition
	if definition == null or definition.use_type != ItemDefinition.UseType.FIREARM:
		_deactivate_useable()
		return
	if active_item_id == item_id and active_useable != null and _active_slot_index >= 0:
		return
	_deactivate_useable()
	var slot_index := _find_inventory_slot(item_id)
	if slot_index < 0: slot_index = _active_slot_index
	var useable := inventory.get_useable(item_id)
	if useable == null: return
	var gun := useable as UseableGun
	if gun == null: return
	var actor := _default_actor()
	gun.owner_equipment = self
	gun.inventory_slot = slot_index
	if not gun.equip(actor, definition, inventory.get_slot_state(slot_index)):
		return
	active_useable = gun
	active_item_id = item_id
	_active_slot_index = slot_index
	_connect_gun_signals(gun)
	weapon_changed.emit(item_id)
	ammo_changed.emit(gun.get_ammo(), gun.get_capacity())
	firemode_changed.emit(gun.get_firemode(), gun.get_firemode_name())

func _deactivate_useable() -> void:
	if active_useable != null:
		var gun := active_useable as UseableGun
		if gun != null:
			_disconnect_gun_signals(gun)
			gun.unequip()
		active_useable = null
		active_item_id = &""
		_active_slot_index = -1
		weapon_changed.emit(&"")

func _resolve_active_arm_slot() -> StringName:
	if inventory == null:
		return &""
	for slot in FIREARM_SLOT_PRIORITY:
		var item_id := get_item(slot)
		if item_id.is_empty(): continue
		var definition := inventory.definitions.get(item_id) as ItemDefinition
		if definition != null and definition.use_type == ItemDefinition.UseType.FIREARM:
			return slot
	return &""

func _find_inventory_slot(item_id: StringName) -> int:
	if inventory == null: return -1
	var metadata: Dictionary = item_metadata.get(item_id, {})
	if metadata.has("slot_index"):
		var stored := int(metadata["slot_index"])
		if stored >= 0 and stored < inventory.slots.size() and StringName(inventory.slots[stored].get("item_id", "")) == item_id:
			return stored
	return inventory.find_slot_index(item_id)

func _default_actor() -> Node3D:
	var parent := get_parent()
	return parent as Node3D

func _connect_gun_signals(gun: UseableGun) -> void:
	gun.ammo_changed.connect(_on_gun_ammo_changed)
	gun.firemode_changed.connect(_on_gun_firemode_changed)
	gun.aim_changed.connect(_on_gun_aim_changed)
	gun.attachment_changed.connect(_on_gun_attachment_changed)
	gun.state_changed.connect(_on_gun_state_changed)
	gun.recoil_applied.connect(_on_gun_recoil)
	gun.noise.connect(_on_gun_noise)

func _disconnect_gun_signals(gun: UseableGun) -> void:
	if gun == null: return
	if gun.ammo_changed.is_connected(_on_gun_ammo_changed): gun.ammo_changed.disconnect(_on_gun_ammo_changed)
	if gun.firemode_changed.is_connected(_on_gun_firemode_changed): gun.firemode_changed.disconnect(_on_gun_firemode_changed)
	if gun.aim_changed.is_connected(_on_gun_aim_changed): gun.aim_changed.disconnect(_on_gun_aim_changed)
	if gun.attachment_changed.is_connected(_on_gun_attachment_changed): gun.attachment_changed.disconnect(_on_gun_attachment_changed)
	if gun.state_changed.is_connected(_on_gun_state_changed): gun.state_changed.disconnect(_on_gun_state_changed)
	if gun.recoil_applied.is_connected(_on_gun_recoil): gun.recoil_applied.disconnect(_on_gun_recoil)
	if gun.noise.is_connected(_on_gun_noise): gun.noise.disconnect(_on_gun_noise)

func _on_gun_ammo_changed(ammo: int, capacity: int) -> void:
	ammo_changed.emit(ammo, capacity)

func _on_gun_firemode_changed(mode: int) -> void:
	var gun := get_active_gun()
	firemode_changed.emit(mode, gun.get_firemode_name() if gun != null else &"")

func _on_gun_aim_changed(aiming: bool, zoom: float) -> void:
	aiming_changed.emit(aiming, zoom)

func _on_gun_attachment_changed(kind: StringName, attachment_id: StringName) -> void:
	attachment_changed.emit(kind, attachment_id)

func _on_gun_state_changed(state: Dictionary) -> void:
	if inventory != null and _active_slot_index >= 0:
		inventory.set_slot_state(_active_slot_index, state)
	weapon_state_changed.emit(active_item_id, state.duplicate(true))

func _on_gun_recoil(amount: Vector2) -> void:
	recoil_applied.emit(amount)

func _on_gun_noise(position: Vector3, radius: float) -> void:
	noise_made.emit(position, radius)
	if not is_inside_tree(): return
	for zombie in get_tree().get_nodes_in_group(&"zombie"):
		if zombie.has_method("alert"):
			zombie.call("alert", position)

# ---------------------------------------------------------------------------
# Persistence / inventory sync
# ---------------------------------------------------------------------------

func get_state() -> Dictionary:
	return {"version": 2, "slots": slots.duplicate(true), "metadata": item_metadata.duplicate(true)}

func update_state(state: Dictionary) -> void:
	slots.clear()
	item_metadata = state.get("metadata", {}).duplicate(true)
	var raw: Dictionary = state.get("slots", {})
	for slot in raw:
		if supported_slots.has(String(slot)) and not StringName(raw[slot]).is_empty(): slots[StringName(slot)] = StringName(raw[slot])
	equipment_changed.emit()
	_refresh_active_useable()

# U3 drops equipment when the referenced item leaves the inventory.
func _on_inventory_changed() -> void:
	if inventory == null: return
	var dropped := false
	for slot in slots.keys():
		var item_id := StringName(slots[slot])
		if inventory.count_item(item_id) <= 0:
			slots.erase(slot)
			unequipped.emit(StringName(slot), item_id)
			dropped = true
	if dropped:
		equipment_changed.emit()
		_refresh_active_useable()
