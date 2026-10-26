extends UseableItem
class_name UseableGun

# Godot-side port of U3 UseableGun core (single-player subset):
#   fire modes (safety/semi/burst/auto), firerate cooldown, magazines + ammo,
#   attachment mounting (sight/grip/tactical/barrel/magazine), spread/recoil,
#   pellet hitscan, damage falloff, reload, and inventory-backed gun state.
# Firearm item state lives in the owning inventory slot's `state` dictionary
# (U3 stores the same data in Item.state byte[]): snapshot keys
# {"ammo", "firemode", "attachments", "quality"}.

signal fired(actor: Node3D, pellets: int)
signal hit(actor: Node3D, target: Node, damage: float, position: Vector3)
signal dry_fire(actor: Node3D)
signal reloaded(actor: Node3D, ammo: int)
signal attachment_changed(kind: StringName, attachment_id: StringName)
signal firemode_changed(mode: int)
signal aim_changed(aiming: bool, zoom: float)
signal ammo_changed(ammo: int, capacity: int)
signal state_changed(state: Dictionary)
signal noise(position: Vector3, radius: float)
signal recoil_applied(amount: Vector2)

var gun: GunDefinition
var actor: Node3D
var inventory = null
var owner_equipment: Node = null
var inventory_slot := -1
var attachments: Dictionary = {}
var ammo := 0
var fire_mode := GunDefinition.FireMode.SEMI
var aiming := false
var quality := 100.0

var _equipped := false
var _cooldown := 0.0
var _trigger_held := false
var _burst_remaining := 0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()
	consumes_item = false

func _process(delta: float) -> void:
	advance(delta)

func equip(new_actor: Node3D, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	gun = definition as GunDefinition
	if gun == null:
		return false
	actor = new_actor
	inventory = _find_inventory(new_actor)
	_equipped = true
	_trigger_held = false
	_burst_remaining = 0
	_cooldown = 0.0
	if state.is_empty():
		set_state(_default_state())
	else:
		set_state(state)
	ammo_changed.emit(ammo, get_capacity())
	firemode_changed.emit(fire_mode)
	return true

func unequip() -> void:
	_equipped = false
	_trigger_held = false
	_burst_remaining = 0
	aiming = false
	actor = null
	inventory = null
	owner_equipment = null

func is_equipped() -> bool:
	return _equipped

func get_gun() -> GunDefinition:
	return gun

func get_actor() -> Node3D:
	return actor

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

func get_state() -> Dictionary:
	return {
		"ammo": ammo,
		"firemode": fire_mode,
		"attachments": attachments.duplicate(true),
		"quality": quality,
	}

func set_state(state: Dictionary) -> void:
	attachments.clear()
	var raw_attachments: Variant = state.get("attachments", {})
	if raw_attachments is Dictionary:
		for kind in raw_attachments:
			attachments[StringName(kind)] = StringName(str(raw_attachments[kind]))
	quality = clampf(float(state.get("quality", 100.0)), 0.0, 100.0)
	ammo = clampi(int(state.get("ammo", _default_ammo())), 0, get_capacity())
	var mode := int(state.get("firemode", int(gun.default_fire_mode)))
	fire_mode = mode if gun.allowed_fire_modes().has(mode) else int(gun.default_fire_mode)
	_emit_weapon_state()

func _default_state() -> Dictionary:
	var state := {"ammo": 0, "firemode": int(gun.default_fire_mode), "attachments": {}, "quality": 100.0}
	var attachment_state: Dictionary = state["attachments"]
	if not gun.default_magazine.is_empty():
		attachment_state["magazine"] = gun.default_magazine
		state["ammo"] = gun.magazine_capacity
	if gun.has_sight and not gun.default_sight.is_empty(): attachment_state["sight"] = gun.default_sight
	if gun.has_grip and not gun.default_grip.is_empty(): attachment_state["grip"] = gun.default_grip
	if gun.has_tactical and not gun.default_tactical.is_empty(): attachment_state["tactical"] = gun.default_tactical
	if gun.has_barrel and not gun.default_barrel.is_empty(): attachment_state["barrel"] = gun.default_barrel
	return state

func _default_ammo() -> int:
	return get_capacity()

func _emit_weapon_state() -> void:
	ammo_changed.emit(ammo, get_capacity())
	state_changed.emit(get_state())

# ---------------------------------------------------------------------------
# Ammo / magazines / attachments
# ---------------------------------------------------------------------------

func get_attachment(kind: StringName) -> StringName:
	return StringName(attachments.get(kind, ""))

func get_attachments() -> Dictionary:
	return attachments.duplicate(true)

func get_attachment_definition(kind: StringName) -> AttachmentDefinition:
	if inventory == null:
		return null
	var attachment_id := get_attachment(kind)
	if attachment_id.is_empty(): return null
	return inventory.definitions.get(attachment_id) as AttachmentDefinition

func get_capacity() -> int:
	if gun == null: return 0
	var magazine := get_attachment_definition(&"magazine")
	if magazine != null and magazine.capacity > 0: return magazine.capacity
	return maxi(0, gun.magazine_capacity)

func get_ammo() -> int:
	return ammo

func set_ammo(value: int) -> void:
	ammo = clampi(value, 0, get_capacity())
	_emit_weapon_state()

func get_firemode() -> int:
	return fire_mode

func get_firemode_name() -> StringName:
	match fire_mode:
		GunDefinition.FireMode.SAFETY: return &"safety"
		GunDefinition.FireMode.SEMI: return &"semi"
		GunDefinition.FireMode.AUTO: return &"auto"
		GunDefinition.FireMode.BURST: return &"burst"
	return &"semi"

func set_firemode(mode: int) -> bool:
	if not gun.allowed_fire_modes().has(mode): return false
	if fire_mode == mode: return true
	fire_mode = mode
	_trigger_held = false
	_burst_remaining = 0
	firemode_changed.emit(fire_mode)
	_emit_weapon_state()
	return true

func toggle_firemode() -> bool:
	var modes := gun.allowed_fire_modes()
	if modes.is_empty(): return false
	var index := modes.find(fire_mode)
	var next := int(modes[(index + 1) % modes.size()])
	return set_firemode(next)

func reload(new_actor: Node3D = null) -> bool:
	if not _equipped or gun == null: return false
	var inv = inventory if inventory != null else _find_inventory(new_actor)
	if inv == null: return false
	var magazine_slot := _find_magazine_slot(inv)
	if magazine_slot < 0: return false
	var taken: Dictionary = inv.take_item_at(magazine_slot, 1)
	if taken.is_empty(): return false
	var magazine_id := StringName(taken.get("item_id", ""))
	var magazine := inv.definitions.get(magazine_id) as AttachmentDefinition
	var capacity := gun.magazine_capacity
	if magazine != null: capacity = magazine.capacity_or(capacity)
	var taken_state: Dictionary = taken.get("state", {})
	var loaded_ammo := int(taken_state.get("ammo", capacity))
	var previous := get_attachment(&"magazine")
	if not previous.is_empty():
		_return_attachment(inv, &"magazine", previous, {"ammo": ammo})
	attachments[&"magazine"] = magazine_id
	ammo = mini(maxi(0, loaded_ammo), maxi(0, capacity))
	_cooldown = maxf(_cooldown, gun.reload_time)
	reloaded.emit(actor, ammo)
	attachment_changed.emit(&"magazine", magazine_id)
	_emit_weapon_state()
	return true

func attach(kind: StringName, attachment_id: StringName, new_actor: Node3D = null) -> bool:
	if not _equipped or gun == null or attachment_id.is_empty(): return false
	var inv = inventory if inventory != null else _find_inventory(new_actor)
	if inv == null: return false
	var definition := inv.definitions.get(attachment_id) as AttachmentDefinition
	if definition == null or definition.kind_name() != kind: return false
	if not _can_accept(kind, definition): return false
	var index: int = inv.find_slot_index(attachment_id)
	if index < 0: return false
	var taken: Dictionary = inv.take_item_at(index, 1)
	if taken.is_empty(): return false
	var previous := get_attachment(kind)
	if not previous.is_empty():
		var previous_state: Dictionary = {}
		if kind == &"magazine": previous_state = {"ammo": ammo}
		_return_attachment(inv, kind, previous, previous_state)
	attachments[kind] = attachment_id
	if kind == &"magazine":
		var capacity := definition.capacity_or(gun.magazine_capacity)
		var taken_state: Dictionary = taken.get("state", {})
		ammo = mini(maxi(0, int(taken_state.get("ammo", capacity))), maxi(0, capacity))
	attachment_changed.emit(kind, attachment_id)
	_emit_weapon_state()
	return true

func detach(kind: StringName, new_actor: Node3D = null) -> bool:
	if not _equipped or gun == null: return false
	var attachment_id := get_attachment(kind)
	if attachment_id.is_empty(): return false
	var inv = inventory if inventory != null else _find_inventory(new_actor)
	if inv == null: return false
	var state: Dictionary = {}
	if kind == &"magazine": state = {"ammo": ammo}
	if not _return_attachment(inv, kind, attachment_id, state): return false
	attachments.erase(kind)
	if kind == &"magazine": ammo = 0
	attachment_changed.emit(kind, &"")
	_emit_weapon_state()
	return true

func _return_attachment(inv, _kind: StringName, attachment_id: StringName, state: Dictionary) -> bool:
	return inv.add_item(attachment_id, 1, state) == 0

func _find_magazine_slot(inv) -> int:
	if not gun.default_magazine.is_empty():
		var preferred: int = inv.find_slot_index(gun.default_magazine)
		if preferred >= 0: return preferred
	for index in inv.slots.size():
		var item_id := StringName(inv.slots[index].get("item_id", ""))
		var definition := inv.definitions.get(item_id) as AttachmentDefinition
		if definition != null and definition.kind == AttachmentDefinition.Kind.MAGAZINE:
			return index
	return -1

func _can_accept(kind: StringName, definition: AttachmentDefinition) -> bool:
	match kind:
		&"sight":
			if not gun.has_sight: return false
		&"grip":
			if not gun.has_grip: return false
		&"tactical":
			if not gun.has_tactical: return false
		&"barrel":
			if not gun.has_barrel: return false
		&"magazine":
			pass
		_:
			return false
	if definition.caliber != 0 and gun.caliber != 0 and definition.caliber != gun.caliber:
		return false
	return true

# ---------------------------------------------------------------------------
# Aim / firing
# ---------------------------------------------------------------------------

func set_aiming(enabled: bool) -> bool:
	if gun == null: return false
	if aiming == enabled: return true
	aiming = enabled
	aim_changed.emit(aiming, get_zoom())
	return true

func is_aiming() -> bool:
	return aiming

func get_zoom() -> float:
	var sight := get_attachment_definition(&"sight")
	return maxf(1.0, sight.zoom) if sight != null else 1.0

func get_fire_interval() -> float:
	if gun == null: return 0.2
	if gun.fire_interval > 0.0: return gun.fire_interval
	var offset := 0
	for kind in attachments:
		var definition := get_attachment_definition(StringName(kind))
		if definition != null: offset += definition.firerate_offset
	return 50.0 / float(maxi(1, gun.firerate + 1 - offset))

func get_pellets() -> int:
	var magazine := get_attachment_definition(&"magazine")
	if magazine != null and magazine.pellets > 1: return magazine.pellets
	return maxi(1, gun.pellets)

func get_damage() -> float:
	if gun == null: return 0.0
	var multiplier := 1.0
	for kind in attachments:
		var definition := get_attachment_definition(StringName(kind))
		if definition != null: multiplier *= definition.ballistic_damage_multiplier
	return gun.damage * multiplier

func get_recoil_multiplier() -> float:
	var multiplier := 1.0
	if aiming: multiplier *= gun.aiming_recoil_multiplier
	var stance := _stance_name()
	match stance:
		&"crouching": multiplier *= gun.recoil_crouch
		&"prone": multiplier *= gun.recoil_prone
	for kind in attachments:
		var definition := get_attachment_definition(StringName(kind))
		if definition != null: multiplier *= definition.recoil_multiplier
	return multiplier

func get_spread_radians() -> float:
	if gun == null: return 0.0
	var spread := gun.get_base_spread_radians()
	if aiming: spread *= gun.spread_aim
	var stance := _stance_name()
	match stance:
		&"crouching": spread *= gun.spread_crouch
		&"prone": spread *= gun.spread_prone
	for kind in attachments:
		var definition := get_attachment_definition(StringName(kind))
		if definition != null: spread *= definition.spread_multiplier
	spread *= 1.0 + (1.0 - clampf(quality / 100.0, 0.0, 1.0)) * 0.5
	return spread

func can_fire() -> bool:
	return _equipped and gun != null and _cooldown <= 0.0 and (gun.infinite_ammo or ammo >= gun.ammo_per_shot)

func trigger_down(new_actor: Node3D = null) -> bool:
	if not _equipped or gun == null: return false
	if new_actor != null: actor = new_actor
	if fire_mode == GunDefinition.FireMode.SAFETY:
		return false
	_trigger_held = true
	if fire_mode == GunDefinition.FireMode.BURST:
		if _burst_remaining > 0: return false
		if _cooldown > 0.0: return false
		_burst_remaining = maxi(1, gun.bursts)
		return _try_fire_once()
	if _cooldown > 0.0: return false
	return _try_fire_once()

func trigger_up() -> void:
	_trigger_held = false

func advance(delta: float) -> void:
	if delta <= 0.0: return
	_cooldown = maxf(0.0, _cooldown - delta)
	if not _equipped or gun == null: return
	if _cooldown > 0.0: return
	if _burst_remaining > 0:
		if _try_fire_once():
			_burst_remaining -= 1
		else:
			_burst_remaining = 0
	elif fire_mode == GunDefinition.FireMode.AUTO and _trigger_held:
		_try_fire_once()

func _try_fire_once() -> bool:
	if gun == null or actor == null or _cooldown > 0.0: return false
	if not gun.infinite_ammo and ammo < gun.ammo_per_shot:
		dry_fire.emit(actor)
		_cooldown = 0.15
		return false
	if not gun.infinite_ammo:
		ammo -= gun.ammo_per_shot
	_cooldown = get_fire_interval()
	var spread := get_spread_radians()
	var pellets := get_pellets()
	var damage := get_damage()
	var forward := _aim_direction()
	for _pellet in pellets:
		var direction := _spread_direction(forward, spread)
		_resolve_pellet(direction, damage)
	ammo_changed.emit(ammo, get_capacity())
	fired.emit(actor, pellets)
	state_changed.emit(get_state())
	noise.emit(actor.global_position, gun.alert_radius)
	recoil_applied.emit(_roll_recoil())
	return true

func _roll_recoil() -> Vector2:
	var amount := Vector2(
		_rng.randf_range(minf(gun.recoil_min.x, gun.recoil_max.x), maxf(gun.recoil_min.x, gun.recoil_max.x)),
		_rng.randf_range(minf(gun.recoil_min.y, gun.recoil_max.y), maxf(gun.recoil_min.y, gun.recoil_max.y))
	)
	return amount * get_recoil_multiplier()

func _aim_direction() -> Vector3:
	var camera := _get_camera()
	if camera != null:
		return -camera.global_basis.z
	return -actor.global_basis.z

func _muzzle_origin() -> Vector3:
	var camera := _get_camera()
	if camera != null:
		return camera.global_position
	return actor.global_position + Vector3.UP * 1.5

func _get_camera() -> Camera3D:
	if actor == null: return null
	var camera := actor.get_node_or_null("Head/Camera3D") as Camera3D
	if camera != null: return camera
	for child in actor.get_children():
		if child is Camera3D: return child as Camera3D
	return null

func _spread_direction(forward: Vector3, spread: float) -> Vector3:
	if spread <= 0.0: return forward
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = forward.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(forward).normalized()
	var angle := _rng.randf_range(0.0, TAU)
	var radius := tan(spread) * sqrt(_rng.randf())
	return (forward + right * cos(angle) * radius + up * sin(angle) * radius).normalized()

func _resolve_pellet(direction: Vector3, damage: float) -> void:
	if gun == null or actor == null or not actor.is_inside_tree(): return
	var origin := _muzzle_origin()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * gun.range)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var result := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty(): return
	var collider := result.collider as Node
	if collider == null: return
	var distance := origin.distance_to(result.position)
	var applied := _falloff_damage(damage, distance)
	var damageable := _find_damageable(collider)
	if damageable != null:
		var context := DamageContext.new()
		context.amount = applied
		context.source = actor
		context.target = damageable.get_parent() if damageable.get_parent() != null else damageable
		context.hit_position = result.position
		context.hit_normal = result.normal
		context.limb = &"spine"
		context.cause = &"gun"
		damageable.apply_damage(context)
		hit.emit(actor, damageable, applied, result.position)
		return
	if collider.has_method("apply_damage"):
		collider.call("apply_damage", applied, direction)
		hit.emit(actor, collider, applied, result.position)
	elif collider.has_method("take_damage"):
		collider.call("take_damage", applied)
		hit.emit(actor, collider, applied, result.position)

func _falloff_damage(damage: float, distance: float) -> float:
	if gun == null: return damage
	var start := gun.range * clampf(gun.damage_falloff_range, 0.0, 1.0)
	var end := gun.range * clampf(gun.damage_falloff_max_range, 0.0, 1.0)
	if gun.damage_falloff_multiplier >= 1.0 or end <= start or distance <= start:
		return damage
	var weight := clampf((distance - start) / maxf(end - start, 0.001), 0.0, 1.0)
	var multiplier := lerpf(1.0, gun.damage_falloff_multiplier, weight)
	return damage * multiplier

func _find_damageable(node: Node) -> Damageable:
	var current := node
	while current != null:
		if current is Damageable: return current as Damageable
		var found := current.get_node_or_null("Damageable")
		if found is Damageable: return found as Damageable
		for child in current.get_children():
			if child is Damageable: return child as Damageable
		current = current.get_parent()
	return null

func _stance_name() -> StringName:
	if actor == null: return &"standing"
	var stance := actor.get_node_or_null("Stance") as PlayerStance
	return stance.stance if stance != null else &"standing"

func _find_inventory(node: Node) -> Node:
	if node == null: return null
	var found := node.get_node_or_null("Inventory")
	if found != null: return found
	for child in node.get_children():
		if child.has_method("add_item") and child.has_method("get_slot_state"): return child
	return null

# Inventory click-use must not fire the gun; firing goes through PlayerEquipment.
func can_use(_actor: Node, _definition: ItemDefinition, _state: Dictionary = {}) -> bool:
	return false

func use_item(_actor: Node, _definition: ItemDefinition, _state: Dictionary = {}) -> bool:
	return false


