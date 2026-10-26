extends Area3D
class_name VehicleBumper

@export var damage_per_speed := 1.5
@export var minimum_impact_speed := 2.0
@export var maximum_damage := 80.0
@export var cooldown := 0.25

var _last_hit_usec := 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var vehicle := _find_vehicle()
	if vehicle == null or body == vehicle:
		return
	var now := Time.get_ticks_usec()
	if now - _last_hit_usec < int(cooldown * 1000000.0):
		return
	var impact_speed := vehicle.linear_velocity.length()
	if impact_speed < minimum_impact_speed:
		return
	_last_hit_usec = now
	var damage := minf(maximum_damage, (impact_speed - minimum_impact_speed) * damage_per_speed)
	vehicle.apply_damage(damage, body)
	if body.has_method("apply_damage"):
		body.apply_damage(damage, vehicle)

func _find_vehicle() -> VehicleController:
	var current := get_parent()
	while current != null:
		if current is VehicleController:
			return current as VehicleController
		current = current.get_parent()
	return null
