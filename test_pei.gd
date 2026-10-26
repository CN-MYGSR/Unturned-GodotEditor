extends SceneTree

# PEI 原版地图：地形、碰撞、海水、原版出生点。

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(FileAccess.file_exists("res://data/maps/PEI/height.bin"), "PEI heightmap data exists")
	_check(FileAccess.file_exists("res://data/maps/PEI/map.png"), "PEI map texture exists")
	var packed := load("res://scenes/maps/pei.tscn") as PackedScene
	_check(packed != null, "PEI scene loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate() as PeiMap
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(root.get_node_or_null("PEIMap") != null, "PEI scene root exists")
	_check(scene.terrain_mesh != null and scene.terrain_mesh.mesh != null, "PEI terrain mesh is generated")
	if scene.terrain_mesh != null and scene.terrain_mesh.mesh != null:
		_check(scene.terrain_mesh.mesh.get_surface_count() > 0, "PEI terrain has a surface")
	_check(scene.water != null, "PEI sea plane exists")
	var terrain_body := scene.get_node_or_null("TerrainBody") as StaticBody3D
	_check(terrain_body != null and terrain_body.get_child_count() > 0, "PEI terrain collision exists")
	var object_meshes := 0
	var object_instances := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D:
			object_meshes += 1
			object_instances += (child as MultiMeshInstance3D).multimesh.instance_count
	_check(object_meshes > 100, "PEI object meshes are loaded")
	_check(object_instances > 3000, "PEI object placements are instanced")
	var tree_meshes := 0
	var collision_shapes := 0
	for child in scene.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Tree_"):
			tree_meshes += 1
		if child is StaticBody3D and child.name == "PEI_ObjectCollision":
			collision_shapes = child.get_child_count()
	_check(tree_meshes > 0, "PEI tree meshes are loaded")
	_check(collision_shapes > 6000, "PEI object hitboxes are built")
	var collider_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/PEI/colliders.json"))
	if collider_parsed is Dictionary:
		var collider_map: Dictionary = collider_parsed
		var object_colliders: Dictionary = collider_map.get("objects", {})
		var tree_colliders: Dictionary = collider_map.get("trees", {})
		var tent: Dictionary = object_colliders.get("Tent_0.glb", {})
		var bridge: Dictionary = object_colliders.get("Bridge_Line_0.glb", {})
		var birch: Dictionary = tree_colliders.get("Birch_0.glb", {})
		_check((tent.get("mesh_faces", []) as Array).size() > 0, "PEI tent uses mesh collider")
		_check((bridge.get("mesh_faces", []) as Array).size() > 0, "PEI bridge uses mesh collider")
		_check((birch.get("capsules", []) as Array).size() > 0, "PEI tree uses trunk capsule collider")
	else:
		_check(false, "PEI collider data parses")

	var player := scene.get_node_or_null("Player") as CharacterBody3D
	_check(player != null, "PEI player exists")
	if player != null:
		_check(player.global_position.y > PeiMap.SEA_LEVEL, "PEI player spawns above sea level")
	await process_frame
	scene.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("PEI original map tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("PEI map test failed: " + failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)




