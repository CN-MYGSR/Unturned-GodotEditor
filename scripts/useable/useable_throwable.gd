extends UseableItem
class_name UseableThrowable

signal projectile_spawned(actor: Node3D, projectile: Node3D)

@export var throw_force := 12.0
@export var upward_force := 2.5
@export var throw_origin_path: NodePath = ^"Head/Camera3D"
@export var projectile_scene: PackedScene

func _init() -> void:
	consumes_item = true

func can_use(actor: Node, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	return super.can_use(actor, definition, state) and actor is Node3D and (projectile_scene != null or definition.projectile_scene != null)

func use_item(actor: Node, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	if not can_use(actor, definition, state): return false
	var scene := projectile_scene if projectile_scene != null else definition.projectile_scene
	var projectile := scene.instantiate() as Node3D
	if projectile == null: return false
	var player := actor as Node3D
	var origin := player.get_node_or_null(throw_origin_path) as Node3D
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(projectile)
	projectile.global_transform = origin.global_transform if origin != null else player.global_transform
	var direction := -projectile.global_basis.z
	var force := direction * throw_force + Vector3.UP * upward_force
	if projectile is RigidBody3D: (projectile as RigidBody3D).apply_central_impulse(force)
	elif projectile.has_method("launch"): projectile.call("launch", force, player)
	_next_use_msec = Time.get_ticks_msec() + int(maxf(cooldown, definition.use_cooldown) * 1000.0)
	play_presentation(player, &"throw", definition.voice_event)
	projectile_spawned.emit(player, projectile)
	use_started.emit(player, definition.item_id)
	use_finished.emit(player, definition.item_id, true)
	return true

