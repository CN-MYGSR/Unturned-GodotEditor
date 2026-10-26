extends RefCounted
class_name DamageContext

var amount := 0.0
var source: Node
var target: Node
var hit_position := Vector3.ZERO
var hit_normal := Vector3.UP
var limb: StringName
var cause: StringName
var is_critical := false
var is_explosion := false

func to_dictionary() -> Dictionary:
	return {"amount": amount, "source": source.get_path() if is_instance_valid(source) else NodePath(), "target": target.get_path() if is_instance_valid(target) else NodePath(), "hit_position": hit_position, "hit_normal": hit_normal, "limb": limb, "cause": cause, "is_critical": is_critical, "is_explosion": is_explosion}
