extends CharacterBody3D
class_name PlayerController

signal focused_interactable_changed(target: Node3D)

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var sprint_stamina_per_second := 12.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025
@export var interaction_distance := 3.0
@export var life_path: NodePath = ^"Life"
@export var stance_path: NodePath = ^"Stance"
@export var camera_path: NodePath = ^"Head/Camera3D"

var focused_interactable: Node3D
var _camera: Camera3D
var _life: PlayerLife
var _stance: PlayerStance
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _base_fov := 70.0
var _target_fov := 70.0

func _ready() -> void:
	add_to_group(&"player")
	_camera = get_node_or_null(camera_path) as Camera3D
	_life = get_node_or_null(life_path) as PlayerLife
	_stance = get_node_or_null(stance_path) as PlayerStance
	if _camera != null:
		_base_fov = _camera.fov
		_target_fov = _base_fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if _camera != null:
		_camera.fov = lerpf(_camera.fov, _target_fov, clampf(delta * 12.0, 0.0, 1.0))

# ADS (aim down sights): sight zoom divides the base FOV while aiming.
func set_aim(aiming: bool, zoom := 1.0) -> void:
	_target_fov = _base_fov / maxf(zoom, 1.0) if aiming else _base_fov

func get_target_fov() -> float:
	return _target_fov

# U3 applies gun recoil to the view; amounts are in degrees.
func apply_recoil(amount: Vector2) -> void:
	if _camera != null:
		_camera.rotation.x = clampf(_camera.rotation.x + deg_to_rad(amount.y), -1.45, 1.45)
	rotate_y(-deg_to_rad(amount.x))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if _camera != null:
			_camera.rotation.x = clampf(_camera.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)
	if event is InputEventKey and event.pressed and not event.echo:
		if _stance != null and event.keycode == KEY_C:
			_stance.toggle_crouch()
		if _stance != null and event.keycode == KEY_X:
			_stance.set_stance(&"prone")
		if event.keycode == KEY_F and has_meta("vehicle"):
			var vehicle: Node = get_meta("vehicle")
			if is_instance_valid(vehicle) and vehicle.has_method("exit"):
				vehicle.exit(self)
		if event.keycode == KEY_E:
			_interact()
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if (_life != null and _life.is_dead) or has_meta("vehicle"):
		velocity = Vector3.ZERO
		_clear_focused_interactable()
		return
	var input := Vector2.ZERO
	input.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	input = input.normalized()
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and _life != null and _life.stamina > 0.0 and not _life.is_broken
	if sprinting:
		_life.consume_stamina(sprint_stamina_per_second * delta)
	var speed := sprint_speed if sprinting else walk_speed
	if _stance != null and _stance.stance == &"crouching":
		speed *= 0.6
	elif _stance != null and _stance.stance == &"prone":
		speed *= 0.3
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity
	move_and_slide()
	_update_interactable_focus()

func _update_interactable_focus() -> void:
	var next: Node3D
	if _camera != null and is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(_camera.global_position, _camera.global_position - _camera.global_basis.z * interaction_distance)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var node := hit.collider as Node
			while node != null and not (node is Interactable or (node.has_method("can_interact") and node.has_method("interact"))):
				node = node.get_parent()
			if node != null and node.has_method("can_interact") and node.has_method("interact") and bool(node.get("interaction_enabled")):
				next = node as Node3D
	if next != focused_interactable:
		if focused_interactable != null and is_instance_valid(focused_interactable):
			focused_interactable.unfocus(self)
		focused_interactable = next
		if focused_interactable != null:
			focused_interactable.focus(self)
		focused_interactable_changed.emit(focused_interactable)

func _exit_tree() -> void:
	_clear_focused_interactable()

func _clear_focused_interactable() -> void:
	if focused_interactable == null or not is_instance_valid(focused_interactable):
		focused_interactable = null
		return
	focused_interactable.unfocus(self)
	focused_interactable = null
	focused_interactable_changed.emit(null)

func _interact() -> void:
	if focused_interactable != null and is_instance_valid(focused_interactable) and focused_interactable.can_interact(self):
		focused_interactable.interact(self)
