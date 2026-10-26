extends Node
class_name PlayerStance

signal stance_changed(previous: StringName, current: StringName)

@export var standing_height := 1.8
@export var crouching_height := 1.2
@export var prone_height := 0.55
@export var transition_speed := 8.0
@export var collider_path: NodePath = ^"../CollisionShape3D"
@export var camera_path: NodePath = ^"../Head"

var stance: StringName = &"standing"
var _collider: CollisionShape3D
var _camera: Node3D

func _ready() -> void:
	_collider = get_node_or_null(collider_path) as CollisionShape3D
	_camera = get_node_or_null(camera_path) as Node3D
	if _collider != null and _collider.shape is CapsuleShape3D:
		_collider.shape = _collider.shape.duplicate()

func _process(delta: float) -> void:
	if _collider != null and _collider.shape is CapsuleShape3D:
		var capsule := _collider.shape as CapsuleShape3D
		capsule.height = move_toward(capsule.height, get_height(), transition_speed * delta)
		_collider.position.y = capsule.height * 0.5
	if _camera != null:
		_camera.position.y = move_toward(_camera.position.y, get_height() - 0.2, transition_speed * delta)

func set_stance(value: StringName) -> bool:
	if not [&"standing", &"crouching", &"prone"].has(value): return false
	if stance == value: return true
	var previous := stance
	stance = value
	stance_changed.emit(previous, stance)
	return true

func toggle_crouch() -> void:
	set_stance(&"standing" if stance == &"crouching" else &"crouching")

func get_height() -> float:
	match stance:
		&"crouching": return crouching_height
		&"prone": return prone_height
		_: return standing_height

func get_state() -> Dictionary:
	return {"stance": stance}

func update_state(state: Dictionary) -> void:
	set_stance(StringName(state.get("stance", stance)))


