extends Node
class_name VehicleBuoyancy

@export var vehicle_path: NodePath = NodePath("..")
@export var float_points: Array[NodePath] = []
@export var water_level := 0.0
@export var buoyancy_force := 18.0
@export var damping := 2.5
@export var maximum_submersion := 1.0

var _body: RigidBody3D
var _points: Array[Node3D] = []

func _ready() -> void:
	_body = get_node_or_null(vehicle_path) as RigidBody3D
	for path in float_points:
		var point := get_node_or_null(path) as Node3D
		if point != null:
			_points.append(point)

func _physics_process(_delta: float) -> void:
	if _body == null or _points.is_empty():
		return
	for point in _points:
		var depth := clampf(water_level - point.global_position.y, 0.0, maximum_submersion)
		if depth <= 0.0:
			continue
		var point_velocity := _body.linear_velocity + _body.angular_velocity.cross(point.global_position - _body.global_position)
		var force := Vector3.UP * (buoyancy_force * depth) - point_velocity * damping
		_body.apply_force(force, point.global_position - _body.global_position)
