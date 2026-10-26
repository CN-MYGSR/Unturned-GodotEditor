extends RefCounted
class_name PhysicsQuery

static func raycast(world: World3D, origin: Vector3, direction: Vector3, distance: float, exclude: Array[RID] = [], mask := 0xFFFFFFFF) -> Dictionary:
	if world == null or distance <= 0.0 or direction.is_zero_approx(): return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance)
	query.exclude = exclude
	query.collision_mask = mask
	return world.direct_space_state.intersect_ray(query)

static func sphere_query(world: World3D, center: Vector3, radius: float, mask := 0xFFFFFFFF, maximum_results := 32) -> Array[Dictionary]:
	if world == null or radius <= 0.0: return []
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = mask
	var results: Array[Dictionary] = []
	for hit in world.direct_space_state.intersect_shape(query, maximum_results): results.append(hit)
	return results
