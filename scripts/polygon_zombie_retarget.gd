extends Node3D
class_name PolygonZombieRetarget

@export var civilian_character := "SM_Chr_Civilian_Male_01"
@export var animation_name := "Idle_0"
@export var material_tint := Color(0.58, 0.72, 0.52, 1.0)
@export var blood_tint := Color(0.28, 0.035, 0.025, 1.0)
@export var glowing_eyes := true
@export var zombie_atlas: Texture2D = preload("res://assets/polygon/PolygonMilitary_Zombie_01_A.png")
@export var animation_speed := 1.0
@export var loop_preview := true
@export var max_health := 100.0
@export var move_speed := 1.15
@export var detection_radius := 12.0
@export var attack_radius := 1.65
@export var attack_damage := 12.0
@export var attack_cooldown := 1.25
@export var stun_duration := 0.55
@export var target_path: NodePath

signal died(zombie: Node3D)
signal damaged(amount: float, remaining_health: float)
signal state_changed(state: String)

var health := 100.0
var current_state := 'idle'
var target: Node3D
var attack_timer := 0.0
var stun_timer := 0.0
var _active_animation := ""
var dead := false

var _target_root: Node3D
var _target_skeleton: Skeleton3D
var _source_root: Node3D
var _source_skeleton: Node3D
var _source_player: AnimationPlayer
var _source_animation: Animation
var _source_time := 0.0
var _bone_map := {
	"Skeleton": "Root",
	"Spine": "Spine_02",
	"Skull": "Head",
	"Left_Shoulder": "Shoulder_L",
	"Left_Arm": "Elbow_L",
	"Left_Hand": "Hand_L",
	"Left_Hook": "Hand_L",
	"Right_Shoulder": "Shoulder_R",
	"Right_Arm": "Elbow_R",
	"Right_Hand": "Hand_R",
	"Right_Hook": "Hand_R",
	"Left_Hip": "UpperLeg_L",
	"Left_Leg": "LowerLeg_L",
	"Left_Foot": "Ankle_L",
	"Right_Hip": "UpperLeg_R",
	"Right_Leg": "LowerLeg_R",
	"Right_Foot": "Ankle_R",
}

func _ready() -> void:
	_target_root = get_node_or_null("PolygonCharacters")
	_source_root = get_node_or_null("U3ZombieAnimation")
	if _target_root == null or _source_root == null:
		push_error("PolygonZombieRetarget: missing PolygonCharacters or U3ZombieAnimation")
		return
	_target_skeleton = _find_skeleton(_target_root)
	_source_skeleton = _source_root.find_child("Skeleton", true, false) as Node3D
	_source_player = _source_root.find_children("*", "AnimationPlayer", true, false).front()
	if _target_skeleton == null or _source_skeleton == null or _source_player == null:
		push_error("PolygonZombieRetarget: skeleton or animation player missing")
		return
	_apply_civilian_variant()
	health = max_health
	target = get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null
	_play_animation(animation_name)
	print("[ZOMBIE] POLYGON civilian variant ready; animation=", animation_name)

func _process(delta: float) -> void:
	_update_ai(delta)
	if _source_skeleton == null or _target_skeleton == null or _source_animation == null:
		return
	_source_time += delta * animation_speed
	if loop_preview and _source_animation.length > 0.0:
		_source_time = fmod(_source_time, _source_animation.length)
	_source_player.seek(_source_time, true)
	_copy_pose()

func play_zombie_animation(name: String) -> void:
	_play_animation(name)

func _play_animation(name: String) -> void:
	if _source_player == null or not _source_player.has_animation(name) or _active_animation == name:
		return
	_active_animation = name
	_source_animation = _source_player.get_animation(name)
	_source_time = 0.0
	_source_player.play(name)
func _copy_pose() -> void:
	for source_name in _bone_map:
		var source_node := _source_skeleton.find_child(source_name, true, false) as Node3D
		var target_index := _target_skeleton.find_bone(_bone_map[source_name])
		if source_node == null or target_index < 0:
			continue
		_target_skeleton.set_bone_pose_rotation(target_index, source_node.quaternion)
		if source_name == "Skeleton" or source_name.ends_with("_Hip"):
			_target_skeleton.set_bone_pose_position(target_index, source_node.position)
func _apply_civilian_variant() -> void:
	for node in _target_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.visible = String(mesh.name) == civilian_character
		if not mesh.visible:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface)
			if material == null:
				material = mesh.mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				var variant := (material as StandardMaterial3D).duplicate()
				variant.albedo_color = material_tint
				variant.albedo_texture = zombie_atlas
				variant.roughness = 0.92
				mesh.set_surface_override_material(surface, variant)

func _find_skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found.front() as Skeleton3D if not found.is_empty() else null

func apply_damage(amount: float, direction := Vector3.ZERO, stun := false) -> void:
	if dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if stun:
		_play_animation("Stun_0")
	damaged.emit(amount, health)
	if health <= 0.0:
		dead = true
		_set_state("dead")
		_play_animation("Stun_6")
		_notify_player_quests()
		died.emit(self)

# Quest asset compatibility: zombie deaths progress kill_zombie objectives for
# every local player in the "player" group (single-player scene: one player).
func _notify_player_quests() -> void:
	if not is_inside_tree(): return
	for node in get_tree().get_nodes_in_group("player"):
		var quests := node.get_node_or_null("Quests") as PlayerQuests
		if quests != null:
			quests.notify_event(&"kill_zombie", &"", 1)

func _chase_target(delta: float) -> void:
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	direction = direction.normalized()
	global_position += direction * move_speed * delta
	look_at(global_position + direction, Vector3.UP)
	_play_animation("Move_0")

func _attack_target() -> void:
	attack_timer = attack_cooldown
	_play_animation("Attack_0")
	if target.has_method("apply_damage"):
		target.apply_damage(attack_damage, global_position.direction_to(target.global_position))

func _set_state(next_state: String) -> void:
	if current_state == next_state:
		return
	current_state = next_state
	state_changed.emit(current_state)
	if current_state == "idle":
		_play_animation("Idle_0")

func alert(position: Vector3) -> void:
	if target != null and global_position.distance_to(position) <= detection_radius * 1.5:
		_set_state("chase")
func set_target(new_target: Node3D) -> void:
	target = new_target

func _update_ai(delta: float) -> void:
	if dead:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	if target == null:
		_set_state("idle")
		return
	var distance := global_position.distance_to(target.global_position)
	if distance > detection_radius:
		_set_state("idle")
	elif distance <= attack_radius:
		_set_state("attack")
		if attack_timer <= 0.0:
			_attack_target()
	else:
		_set_state("chase")
		_chase_target(delta)
