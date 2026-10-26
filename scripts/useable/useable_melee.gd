extends UseableItem
class_name UseableMelee

signal attack_hit(actor: Node3D, target: Node3D, damage: float)

@export var range := 2.0
@export var damage := 25.0
@export var collision_mask := 0xFFFFFFFF

func can_use(actor: Node, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	return super.can_use(actor, definition, state) and actor is Node3D

func use_item(actor: Node, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	if not can_use(actor, definition, state): return false
	var attacker := actor as Node3D
	var camera := attacker.get_node_or_null("Head/Camera3D") as Camera3D
	var origin := camera.global_position if camera != null else attacker.global_position + Vector3.UP
	var direction := -camera.global_basis.z if camera != null else -attacker.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range)
	query.exclude = [attacker.get_rid()]
	query.collision_mask = collision_mask
	var hit := attacker.get_world_3d().direct_space_state.intersect_ray(query)
	_next_use_msec = Time.get_ticks_msec() + int(maxf(cooldown, definition.use_cooldown) * 1000.0)
	play_presentation(attacker, &"melee", definition.voice_event)
	if not hit.is_empty():
		var target := hit.collider as Node3D
		var applied := float(state.get("damage", damage if definition.damage <= 0.0 else definition.damage))
		if target.has_method("take_damage"): target.call("take_damage", applied)
		elif target.has_method("apply_damage"): target.call("apply_damage", applied, attacker)
		attack_hit.emit(attacker, target, applied)
	use_started.emit(attacker, definition.item_id)
	use_finished.emit(attacker, definition.item_id, true)
	return true
