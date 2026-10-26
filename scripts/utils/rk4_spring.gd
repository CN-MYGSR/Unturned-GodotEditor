extends RefCounted
class_name Rk4Spring

var current_position := 0.0
var target_position := 0.0
var velocity := 0.0
var stiffness := 100.0
var damping := 15.0

func update(delta: float) -> float:
	if delta <= 0.0: return current_position
	var remaining := minf(delta, 0.25)
	var steps := maxi(1, ceili(remaining / (1.0 / 120.0)))
	var step := remaining / steps
	for _index in steps:
		var a1 := _acceleration(current_position, velocity)
		var p2 := current_position + velocity * step * 0.5
		var v2 := velocity + a1 * step * 0.5
		var a2 := _acceleration(p2, v2)
		var p3 := current_position + v2 * step * 0.5
		var v3 := velocity + a2 * step * 0.5
		var a3 := _acceleration(p3, v3)
		var p4 := current_position + v3 * step
		var v4 := velocity + a3 * step
		var a4 := _acceleration(p4, v4)
		current_position += step / 6.0 * (velocity + 2.0 * v2 + 2.0 * v3 + v4)
		velocity += step / 6.0 * (a1 + 2.0 * a2 + 2.0 * a3 + a4)
	return current_position

func _acceleration(position: float, speed: float) -> float:
	return stiffness * (target_position - position) - damping * speed
