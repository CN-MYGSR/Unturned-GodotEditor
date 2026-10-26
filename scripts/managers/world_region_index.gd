extends Node
class_name WorldRegionIndex

@export var region_size := 64.0
var _regions: Dictionary = {}
var _node_regions: Dictionary = {}

func register_node(node: Node3D) -> Vector2i:
	if node == null: return Vector2i.ZERO
	unregister_node(node)
	var coordinate := _coordinate(node.global_position)
	if not _regions.has(coordinate): _regions[coordinate] = []
	_regions[coordinate].append(weakref(node))
	_node_regions[node.get_instance_id()] = coordinate
	return coordinate

func unregister_node(node: Node) -> void:
	if node == null: return
	var instance_id := node.get_instance_id()
	if not _node_regions.has(instance_id): return
	var coordinate: Vector2i = _node_regions[instance_id]
	_node_regions.erase(instance_id)
	if not _regions.has(coordinate): return
	var kept: Array[WeakRef] = []
	for reference in _regions[coordinate]:
		var item: Object = reference.get_ref()
		if item != null and item != node: kept.append(reference)
	if kept.is_empty(): _regions.erase(coordinate)
	else: _regions[coordinate] = kept

func refresh_node(node: Node3D) -> Vector2i:
	return register_node(node)

func query_radius(center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var min_cell := _coordinate(center - Vector3(radius, 0.0, radius))
	var max_cell := _coordinate(center + Vector3(radius, 0.0, radius))
	for x in range(min_cell.x, max_cell.x + 1):
		for z in range(min_cell.y, max_cell.y + 1):
			var coordinate := Vector2i(x, z)
			if not _regions.has(coordinate): continue
			for reference in _regions[coordinate]:
				var node := reference.get_ref() as Node3D
				if node != null and node.global_position.distance_squared_to(center) <= radius * radius:
					result.append(node)
	return result

func _coordinate(position: Vector3) -> Vector2i:
	var size := maxf(region_size, 0.01)
	return Vector2i(floori(position.x / size), floori(position.z / size))

