extends Node3D
class_name LevelRuntime

signal level_built(level: LevelGameAsset, placed_count: int, errors: PackedStringArray)

var current_level: LevelGameAsset
var spawned_nodes: Array[Node] = []
var build_errors: PackedStringArray = []

func build(level: LevelGameAsset, database: GameAssetDatabase) -> bool:
	if level == null or database == null or not level.is_valid():
		return false
	clear_level()
	current_level = level
	if level.world_scene != null:
		var world := level.world_scene.instantiate()
		add_child(world)
		spawned_nodes.append(world)
	for placement in level.placements:
		var asset := database.find_by_id(placement.asset_id) as ObjectGameAsset
		if asset == null:
			build_errors.append("Missing object asset: " + str(placement.asset_id))
			continue
		if asset.scene == null:
			build_errors.append("Object has no scene: " + str(placement.asset_id))
			continue
		var instance := asset.scene.instantiate() as Node3D
		if instance == null:
			build_errors.append("Object root must be Node3D: " + str(placement.asset_id))
			continue
		instance.position = placement.position
		instance.rotation_degrees = placement.rotation_degrees
		instance.scale = placement.scale
		instance.add_to_group("level_region_%d_%d" % [placement.region.x, placement.region.y])
		add_child(instance)
		spawned_nodes.append(instance)
	for spawn in level.spawn_points:
		var marker := Marker3D.new()
		marker.name = "%sSpawn" % spawn.spawn_type.capitalize()
		marker.position = spawn.position
		marker.rotation_degrees = spawn.rotation_degrees
		marker.add_to_group("spawn_%s" % spawn.spawn_type)
		add_child(marker)
		spawned_nodes.append(marker)
	level_built.emit(level, spawned_nodes.size(), build_errors)
	return build_errors.is_empty()

func get_spawn_markers(spawn_type := "player") -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for node in get_tree().get_nodes_in_group("spawn_%s" % spawn_type):
		if node is Marker3D and node.get_parent() == self:
			result.append(node)
	return result

func get_region_nodes(region: Vector2i) -> Array[Node]:
	return get_tree().get_nodes_in_group("level_region_%d_%d" % [region.x, region.y]).filter(func(node: Node) -> bool: return node.get_parent() == self)

func clear_level() -> void:
	for node in spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	spawned_nodes.clear()
	build_errors.clear()
	current_level = null