extends Node3D
class_name PeiMap

# PEI 原版地图运行时：读取 data/maps/PEI 的 Unreal/Unturned 高度图，
# 生成 Godot 地形网格 + 碰撞 + 海水，并把玩家放到原版出生点。
# 地形数据来源：Unturned/Maps/PEI/Landscape/Heightmaps/*.heightmap（257×257 大端 uint16）。

const MAP_DIR := "res://data/maps/PEI"
const HEIGHT_RESOLUTION := 1025
const HEIGHT_WORLD_UNIT := 4.0
const MAP_MIN := -2048.0
const TILE_HEIGHT := 2048.0
const SEA_LEVEL := 25.6
const TERRAIN_STEP := 8.0

var heights: PackedFloat32Array
var meta: Dictionary = {}
var spawns: Array = []
var player: CharacterBody3D
var terrain_mesh: MeshInstance3D
var water: MeshInstance3D

func _ready() -> void:
	var ok := _load_map_data()
	if not ok:
		push_error("PEI map data failed to load")
		return
	_load_colliders()
	_collision_body = StaticBody3D.new()
	_collision_body.name = "PEI_ObjectCollision"
	add_child(_collision_body)
	_build_environment()
	var bounds := _map_bounds()
	_build_terrain(bounds)
	_build_water()
	_build_objects()
	_build_trees()
	_spawn_player()

func _load_map_data() -> bool:
	var height_bytes := FileAccess.get_file_as_bytes(MAP_DIR + "/height.bin")
	if height_bytes.is_empty():
		return false
	heights = height_bytes.to_float32_array()
	if heights.size() != HEIGHT_RESOLUTION * HEIGHT_RESOLUTION:
		push_error("PEI heightmap size mismatch: %d" % heights.size())
		return false
	var meta_text := FileAccess.get_file_as_string(MAP_DIR + "/meta.json")
	var meta_parsed: Variant = JSON.parse_string(meta_text)
	if meta_parsed is Dictionary:
		meta = meta_parsed
	var spawn_text := FileAccess.get_file_as_string(MAP_DIR + "/spawns.json")
	var spawn_parsed: Variant = JSON.parse_string(spawn_text)
	if spawn_parsed is Array:
		spawns = spawn_parsed
	player = get_node_or_null("Player") as CharacterBody3D
	return true

func _map_bounds() -> Dictionary:
	return {
		"min_x": float(meta.get("min_x", -2048.0)),
		"max_x": float(meta.get("max_x", 2048.0)),
		"min_z": float(meta.get("min_z", -2048.0)),
		"max_z": float(meta.get("max_z", 2048.0)),
	}

func _cartography_bounds() -> Dictionary:
	var cartography: Dictionary = {}
	var raw_cartography: Variant = meta.get("cartography", {})
	if raw_cartography is Dictionary:
		cartography = raw_cartography
	return {
		"min_x": float(cartography.get("min_x", -966.0)),
		"max_x": float(cartography.get("max_x", 956.0)),
		"min_z": float(cartography.get("min_z", -954.0)),
		"max_z": float(cartography.get("max_z", 971.0)),
	}

func _height_at(world_x: float, world_z: float) -> float:
	var grid_x := clampi(int(round((world_x - MAP_MIN) / HEIGHT_WORLD_UNIT)), 0, HEIGHT_RESOLUTION - 1)
	var grid_z := clampi(int(round((world_z - MAP_MIN) / HEIGHT_WORLD_UNIT)), 0, HEIGHT_RESOLUTION - 1)
	var height_01 := heights[grid_z * HEIGHT_RESOLUTION + grid_x]
	return -TILE_HEIGHT * 0.5 + height_01 * TILE_HEIGHT

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.34, 0.52)
	sky_material.sky_horizon_color = Color(0.62, 0.70, 0.78)
	sky_material.ground_bottom_color = Color(0.12, 0.16, 0.18)
	sky_material.ground_horizon_color = Color(0.45, 0.50, 0.52)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.70, 0.78)
	environment.fog_density = 0.00015
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)

func _build_terrain(bounds: Dictionary) -> void:
	var min_x := float(bounds["min_x"])
	var max_x := float(bounds["max_x"])
	var min_z := float(bounds["min_z"])
	var max_z := float(bounds["max_z"])
	var columns := int(ceil((max_x - min_x) / TERRAIN_STEP)) + 1
	var rows := int(ceil((max_z - min_z) / TERRAIN_STEP)) + 1

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var collision_heights := PackedFloat32Array()
	positions.resize(columns * rows)
	normals.resize(columns * rows)
	uvs.resize(columns * rows)
	indices.resize((columns - 1) * (rows - 1) * 6)
	collision_heights.resize(columns * rows)

	var texture := load(MAP_DIR + "/map.png") as Texture2D
	var uv_bounds := _cartography_bounds()
	var uv_min_x := float(uv_bounds["min_x"])
	var uv_max_x := float(uv_bounds["max_x"])
	var uv_min_z := float(uv_bounds["min_z"])
	var uv_max_z := float(uv_bounds["max_z"])
	for row in rows:
		for column in columns:
			var world_x := min_x + column * TERRAIN_STEP
			var world_z := min_z + row * TERRAIN_STEP
			var height := _height_at(world_x, world_z)
			var index := row * columns + column
			positions[index] = Vector3(world_x, height, world_z)
			collision_heights[index] = height
			var height_left := _height_at(world_x - TERRAIN_STEP, world_z)
			var height_right := _height_at(world_x + TERRAIN_STEP, world_z)
			var height_back := _height_at(world_x, world_z - TERRAIN_STEP)
			var height_front := _height_at(world_x, world_z + TERRAIN_STEP)
			normals[index] = Vector3(height_left - height_right, 2.0 * TERRAIN_STEP, height_back - height_front).normalized()
			var u := clampf((world_x - uv_min_x) / (uv_max_x - uv_min_x), 0.0, 1.0)
			var v := 1.0 - clampf((world_z - uv_min_z) / (uv_max_z - uv_min_z), 0.0, 1.0)
			uvs[index] = Vector2(u, v)

	var index_cursor := 0
	for row in rows - 1:
		for column in columns - 1:
			var top_left := row * columns + column
			var top_right := top_left + 1
			var bottom_left := top_left + columns
			var bottom_right := bottom_left + 1
			indices[index_cursor] = top_left
			indices[index_cursor + 1] = bottom_left
			indices[index_cursor + 2] = top_right
			indices[index_cursor + 3] = top_right
			indices[index_cursor + 4] = bottom_left
			indices[index_cursor + 5] = bottom_right
			index_cursor += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.name = "Terrain"
	terrain_mesh.mesh = mesh
	terrain_mesh.material_override = material
	add_child(terrain_mesh)

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainBody"
	var collision := CollisionShape3D.new()
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = columns
	height_shape.map_depth = rows
	height_shape.map_data = collision_heights
	collision.shape = height_shape
	collision.position = Vector3(min_x + (columns - 1) * TERRAIN_STEP * 0.5, 0.0, min_z + (rows - 1) * TERRAIN_STEP * 0.5)
	collision.scale = Vector3(TERRAIN_STEP, 1.0, TERRAIN_STEP)
	terrain_body.add_child(collision)
	add_child(terrain_body)

func _build_water() -> void:
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(4200, 4200)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.08, 0.30, 0.45, 0.72)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.08
	water_material.metallic = 0.15
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water = MeshInstance3D.new()
	water.name = "Sea"
	water.mesh = water_mesh
	water.material_override = water_material
	water.position = Vector3(0.0, SEA_LEVEL, 0.0)
	add_child(water)

func _build_objects() -> void:
	var text := FileAccess.get_file_as_string(MAP_DIR + "/object_placements.json")
	var groups := _group_placements(text)
	if groups.is_empty():
		return
	for asset_name in groups:
		_add_instanced_asset(str(asset_name), groups[asset_name], "res://assets/unturned/pei_objects/", true, "Object_")


func _build_trees() -> void:
	var text := FileAccess.get_file_as_string(MAP_DIR + "/tree_placements.json")
	var groups := _group_placements(text)
	if groups.is_empty():
		return
	for asset_name in groups:
		_add_instanced_asset(str(asset_name), groups[asset_name], "res://assets/unturned/pei_trees/", true, "Tree_")


func _group_placements(text: String) -> Dictionary:
	var groups: Dictionary = {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return groups
	var placements: Array = parsed.get("placements", [])
	for placement in placements:
		var asset_name := str(placement.get("asset", ""))
		if asset_name.is_empty():
			continue
		if not groups.has(asset_name):
			groups[asset_name] = []
		groups[asset_name].append(placement)
	return groups


func _add_instanced_asset(asset_name: String, instances: Array, base_path: String, collide: bool, prefix: String) -> void:
	var scene_path := base_path + asset_name
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	var temp := packed.instantiate()
	var mesh_instance := _find_mesh_instance(temp)
	if mesh_instance == null or mesh_instance.mesh == null:
		temp.free()
		return
	var mesh := mesh_instance.mesh
	var asset_aabb := mesh.get_aabb()
	if not is_finite(asset_aabb.size.x) or not is_finite(asset_aabb.size.y) or not is_finite(asset_aabb.size.z):
		temp.free()
		return
	if absf(asset_aabb.size.x) > 100000.0 or absf(asset_aabb.size.y) > 100000.0 or absf(asset_aabb.size.z) > 100000.0:
		temp.free()
		return
	var transforms: Array[Transform3D] = []
	for placement in instances:
		var basis := Basis(Quaternion(
			float(placement.get("qx", 0.0)),
			float(placement.get("qy", 0.0)),
			float(placement.get("qz", 0.0)),
			float(placement.get("qw", 1.0))))
		basis = basis * Basis.from_scale(Vector3(
			float(placement.get("sx", 1.0)),
			float(placement.get("sy", 1.0)),
			float(placement.get("sz", 1.0))))
		var origin := Vector3(
			float(placement.get("x", 0.0)),
			float(placement.get("y", 0.0)),
			float(placement.get("z", 0.0)))
		transforms.append(Transform3D(basis, origin))

	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var surface_mesh := ArrayMesh.new()
		surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = surface_mesh
		multimesh.instance_count = transforms.size()
		var min_corner := Vector3(1e9, 1e9, 1e9)
		var max_corner := Vector3(-1e9, -1e9, -1e9)
		for index in transforms.size():
			var placement_transform := transforms[index]
			multimesh.set_instance_transform(index, placement_transform)
			min_corner = min_corner.min(placement_transform.origin - Vector3(40, 40, 40))
			max_corner = max_corner.max(placement_transform.origin + Vector3(40, 40, 40))
		var multimesh_instance := MultiMeshInstance3D.new()
		multimesh_instance.name = prefix + asset_name.get_basename() + "_" + str(surface_index)
		multimesh_instance.multimesh = multimesh
		multimesh_instance.material_override = mesh.surface_get_material(surface_index)
		multimesh_instance.custom_aabb = AABB(min_corner, max_corner - min_corner)
		add_child(multimesh_instance)
	temp.free()

	if collide:
		_add_asset_collision(asset_name, transforms, base_path.contains("pei_trees"))


var _collider_data: Dictionary = {}
var _collision_body: StaticBody3D
var _shape_cache: Dictionary = {}


func _load_colliders() -> void:
	var text := FileAccess.get_file_as_string(MAP_DIR + "/colliders.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_collider_data = parsed


func _add_asset_collision(asset_name: String, transforms: Array[Transform3D], is_tree: bool) -> void:
	var section_name := "trees" if is_tree else "objects"
	var section: Dictionary = _collider_data.get(section_name, {})
	var collider: Dictionary = section.get(asset_name, {})
	if collider.is_empty():
		return
	var faces: Array = collider.get("mesh_faces", [])
	if not faces.is_empty():
		var mesh_key := "mesh|" + section_name + "|" + asset_name
		var mesh_shape: ConcavePolygonShape3D = _shape_cache.get(mesh_key) as ConcavePolygonShape3D
		if mesh_shape == null:
			mesh_shape = ConcavePolygonShape3D.new()
			mesh_shape.backface_collision = true
			var points := PackedVector3Array()
			points.resize(faces.size() * 3)
			var point_index := 0
			for face in faces:
				for vertex_index in 3:
					var base_index := vertex_index * 3
					points[point_index] = Vector3(
						float(face[base_index]),
						float(face[base_index + 1]),
						float(face[base_index + 2]))
					point_index += 1
			mesh_shape.set_faces(points)
			_shape_cache[mesh_key] = mesh_shape
		for placement_transform in transforms:
			var collision := CollisionShape3D.new()
			collision.shape = mesh_shape
			collision.transform = placement_transform
			_collision_body.add_child(collision)
	var boxes: Array = collider.get("boxes", [])
	for box_index in boxes.size():
		var box: Dictionary = boxes[box_index]
		var box_key := "box|" + section_name + "|" + asset_name + "|" + str(box_index)
		var box_shape: BoxShape3D = _shape_cache.get(box_key) as BoxShape3D
		if box_shape == null:
			box_shape = BoxShape3D.new()
			var size_data: Array = box.get("size", [1, 1, 1])
			box_shape.size = Vector3(float(size_data[0]), float(size_data[1]), float(size_data[2]))
			_shape_cache[box_key] = box_shape
		var basis_data: Array = box.get("basis", [1, 0, 0, 0, 1, 0, 0, 0, 1])
		var local_basis := Basis(
			Vector3(float(basis_data[0]), float(basis_data[1]), float(basis_data[2])),
			Vector3(float(basis_data[3]), float(basis_data[4]), float(basis_data[5])),
			Vector3(float(basis_data[6]), float(basis_data[7]), float(basis_data[8])))
		var origin_data: Array = box.get("origin", [0, 0, 0])
		var local_transform := Transform3D(local_basis, Vector3(float(origin_data[0]), float(origin_data[1]), float(origin_data[2])))
		for placement_transform in transforms:
			var collision := CollisionShape3D.new()
			collision.shape = box_shape
			collision.transform = placement_transform * local_transform
			_collision_body.add_child(collision)
	var capsules: Array = collider.get("capsules", [])
	for capsule_index in capsules.size():
		var capsule: Dictionary = capsules[capsule_index]
		var capsule_key := "capsule|" + section_name + "|" + asset_name + "|" + str(capsule_index)
		var capsule_shape: CapsuleShape3D = _shape_cache.get(capsule_key) as CapsuleShape3D
		if capsule_shape == null:
			capsule_shape = CapsuleShape3D.new()
			capsule_shape.radius = float(capsule.get("radius", 0.5))
			capsule_shape.height = maxf(float(capsule.get("height", 2.0)), capsule_shape.radius * 2.0)
			_shape_cache[capsule_key] = capsule_shape
		var basis_data: Array = capsule.get("basis", [1, 0, 0, 0, 1, 0, 0, 0, 1])
		var local_basis := Basis(
			Vector3(float(basis_data[0]), float(basis_data[1]), float(basis_data[2])),
			Vector3(float(basis_data[3]), float(basis_data[4]), float(basis_data[5])),
			Vector3(float(basis_data[6]), float(basis_data[7]), float(basis_data[8])))
		var direction := int(capsule.get("direction", 1))
		if direction == 0:
			local_basis = local_basis * Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5))
		elif direction == 2:
			local_basis = local_basis * Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
		var origin_data: Array = capsule.get("origin", [0, 0, 0])
		var local_transform := Transform3D(local_basis, Vector3(float(origin_data[0]), float(origin_data[1]), float(origin_data[2])))
		for placement_transform in transforms:
			var collision := CollisionShape3D.new()
			collision.shape = capsule_shape
			collision.transform = placement_transform * local_transform
			_collision_body.add_child(collision)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null

func _spawn_player() -> void:
	if player == null or spawns.is_empty():
		return
	var chosen: Dictionary = spawns[0]
	# PEI 西海岸出生点（Unturned 原版 Players.dat 中第 6 个点），视野较开阔。
	if spawns.size() > 5:
		chosen = spawns[5]
	for candidate in spawns:
		var candidate_x := float(candidate.get("x", 0.0))
		var candidate_z := float(candidate.get("z", 0.0))
		if _height_at(candidate_x, candidate_z) > SEA_LEVEL + 1.0:
			chosen = candidate
			break
	var spawn_x := float(chosen.get("x", 0.0))
	var spawn_z := float(chosen.get("z", 0.0))
	var ground := _height_at(spawn_x, spawn_z)
	player.global_position = Vector3(spawn_x, maxf(ground + 1.0, SEA_LEVEL + 1.0), spawn_z)
	player.rotation.y = deg_to_rad(float(chosen.get("angle", 0.0)))

















