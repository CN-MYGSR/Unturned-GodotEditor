extends RefCounted
class_name TransformMath

static func interpolate_transform(from: Transform3D, to: Transform3D, weight: float) -> Transform3D:
	var amount := clampf(weight, 0.0, 1.0)
	return Transform3D(Basis(from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), amount)).scaled(from.basis.get_scale().lerp(to.basis.get_scale(), amount)), from.origin.lerp(to.origin, amount))

static func rotate_toward(current: Vector3, target: Vector3, max_radians: float) -> Vector3:
	if current.is_zero_approx() or target.is_zero_approx(): return target.normalized()
	return current.normalized().slerp(target.normalized(), minf(1.0, max_radians / current.angle_to(target)))

static func find_descendant(root: Node, node_name: StringName) -> Node:
	if root == null: return null
	for child in root.get_children():
		if child.name == node_name: return child
		var nested := find_descendant(child, node_name)
		if nested != null: return nested
	return null
