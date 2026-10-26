@tool
extends Node3D
class_name WorldContentDocument

# Editable world document used by addons/world_content_editor:
#   - heightmap terrain with raise/lower/smooth/flatten brushes + runtime collision
#   - road polylines with a generated ribbon mesh
#   - spawn points (player/zombie/vehicle/...) with rotation
# Every mutating operation is undoable through WorldEditHistory, and the whole
# document round-trips to the project JSON format.
#
# This replaces the Unity Terrain/Road/spawn editor data path with a Godot-native
# format; it is not a reader for Unity's binary level files.

signal document_changed

const FORMAT := "unturned_godot_world_v1"

@export_range(2, 256, 1) var terrain_resolution := 32
@export var terrain_size := Vector2(64.0, 64.0)
@export var terrain_heights := PackedFloat32Array()
@export var road_paths: Array[PackedVector3Array] = []
@export var spawn_points: Array[Dictionary] = []
@export var terrain_material: Material
@export var road_material: Material
@export_range(0.5, 32.0, 0.5) var road_width := 4.0
@export var generate_collision := true
@export_range(1, 256, 1) var history_limit := 64

var history: WorldEditHistory

var _terrain_mesh: MeshInstance3D
var _roads_root: Node3D
var _spawns_root: Node3D
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _editing := false
var _edit_before: Dictionary = {}

func _ready() -> void:
	_ensure_history()
	_ensure_data()
	_rebuild_all()

func _ensure_history() -> void:
	if history == null:
		history = WorldEditHistory.new()
	history.limit = history_limit

# ---------------------------------------------------------------------------
# State / undo
# ---------------------------------------------------------------------------

func get_state() -> Dictionary:
	var roads: Array = []
	for road in road_paths:
		var points: Array = []
		for point in road: points.append([point.x, point.y, point.z])
		roads.append(points)
	return {
		"terrain_resolution": terrain_resolution,
		"terrain_size": [terrain_size.x, terrain_size.y],
		"terrain_heights": Array(terrain_heights),
		"roads": roads,
		"spawns": spawn_points.duplicate(true),
		"road_width": road_width,
	}

func update_state(state: Dictionary) -> void:
	terrain_resolution = clampi(int(state.get("terrain_resolution", terrain_resolution)), 2, 256)
	var size: Array = state.get("terrain_size", [terrain_size.x, terrain_size.y])
	terrain_size = Vector2(float(size[0]), float(size[1]))
	road_width = clampf(float(state.get("road_width", road_width)), 0.5, 32.0)
	var expected := (terrain_resolution + 1) * (terrain_resolution + 1)
	var raw_heights: Array = state.get("terrain_heights", [])
	terrain_heights.resize(expected)
	for index in expected:
		terrain_heights[index] = float(raw_heights[index]) if index < raw_heights.size() else 0.0
	road_paths.clear()
	for raw_road in state.get("roads", []):
		var road := PackedVector3Array()
		for point in raw_road: road.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
		road_paths.append(road)
	spawn_points.clear()
	for spawn in state.get("spawns", []):
		spawn_points.append(_spawn_from_data(spawn))
	_ensure_data()
	_rebuild_all()

func begin_edit() -> void:
	if _editing: return
	_edit_before = get_state()
	_editing = true

func end_edit(label := "") -> void:
	if not _editing: return
	_editing = false
	var before := _edit_before
	_edit_before = {}
	history.push(before, get_state(), label)

func undo() -> bool:
	_ensure_history()
	if _editing: end_edit("edit")
	var state := history.undo()
	if state.is_empty(): return false
	update_state(state)
	document_changed.emit()
	return true

func redo() -> bool:
	_ensure_history()
	if _editing: end_edit("edit")
	var state := history.redo()
	if state.is_empty(): return false
	update_state(state)
	document_changed.emit()
	return true

func can_undo() -> bool:
	_ensure_history()
	return history.can_undo()

func can_redo() -> bool:
	_ensure_history()
	return history.can_redo()

func _begin_change() -> Dictionary:
	if _editing: return {}
	_ensure_history()
	return get_state()

func _commit_change(before: Dictionary, label: String) -> void:
	if before.is_empty(): return
	history.push(before, get_state(), label)

# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func paint_height(world_position: Vector3, radius: float, strength: float) -> bool:
	if radius <= 0.0 or is_zero_approx(strength): return false
	var before := _begin_change()
	var local := to_local(world_position)
	var changed := false
	for z in terrain_resolution + 1:
		for x in terrain_resolution + 1:
			var index := z * (terrain_resolution + 1) + x
			var point := _vertex_position(x, z)
			var distance := Vector2(point.x - local.x, point.z - local.z).length()
			if distance > radius: continue
			var falloff := 1.0 - distance / radius
			terrain_heights[index] += strength * falloff
			changed = true
	if changed:
		_rebuild_terrain()
		document_changed.emit()
		_commit_change(before, "paint terrain")
	return changed

func smooth_height(world_position: Vector3, radius: float, strength := 1.0) -> bool:
	if radius <= 0.0 or strength <= 0.0: return false
	var before := _begin_change()
	var local := to_local(world_position)
	var indices: Array[int] = []
	var average := 0.0
	for z in terrain_resolution + 1:
		for x in terrain_resolution + 1:
			var index := z * (terrain_resolution + 1) + x
			var point := _vertex_position(x, z)
			if Vector2(point.x - local.x, point.z - local.z).length() <= radius:
				indices.append(index)
				average += terrain_heights[index]
	if indices.is_empty(): return false
	average /= indices.size()
	var blend := clampf(strength, 0.0, 1.0)
	for index in indices:
		terrain_heights[index] = lerpf(terrain_heights[index], average, blend)
	_rebuild_terrain()
	document_changed.emit()
	_commit_change(before, "smooth terrain")
	return true

func flatten_height(world_position: Vector3, radius: float, target_height := NAN, strength := 1.0) -> bool:
	if radius <= 0.0 or strength <= 0.0: return false
	var before := _begin_change()
	var local := to_local(world_position)
	var target := get_height_at(world_position) if is_nan(target_height) else target_height
	var blend := clampf(strength, 0.0, 1.0)
	var changed := false
	for z in terrain_resolution + 1:
		for x in terrain_resolution + 1:
			var index := z * (terrain_resolution + 1) + x
			var point := _vertex_position(x, z)
			if Vector2(point.x - local.x, point.z - local.z).length() > radius: continue
			terrain_heights[index] = lerpf(terrain_heights[index], target, blend)
			changed = true
	if changed:
		_rebuild_terrain()
		document_changed.emit()
		_commit_change(before, "flatten terrain")
	return changed

func get_height_at(world_position: Vector3) -> float:
	_ensure_data()
	var local := to_local(world_position)
	var half := terrain_size * 0.5
	var u := clampf((local.x + half.x) / maxf(terrain_size.x, 0.001), 0.0, 1.0) * terrain_resolution
	var v := clampf((local.z + half.y) / maxf(terrain_size.y, 0.001), 0.0, 1.0) * terrain_resolution
	var x0 := int(floor(u))
	var z0 := int(floor(v))
	var x1 := mini(x0 + 1, terrain_resolution)
	var z1 := mini(z0 + 1, terrain_resolution)
	var tx := u - float(x0)
	var tz := v - float(z0)
	var h00 := _height_index(x0, z0)
	var h10 := _height_index(x1, z0)
	var h01 := _height_index(x0, z1)
	var h11 := _height_index(x1, z1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func get_height_index(x: int, z: int) -> float:
	return _height_index(x, z)

# ---------------------------------------------------------------------------
# Roads
# ---------------------------------------------------------------------------

func add_road_point(world_position: Vector3, road_index := -1) -> int:
	var before := _begin_change()
	var local := to_local(world_position)
	if road_index < 0 or road_index >= road_paths.size():
		road_paths.append(PackedVector3Array())
		road_index = road_paths.size() - 1
	var points := road_paths[road_index]
	points.append(local)
	road_paths[road_index] = points
	_rebuild_roads()
	document_changed.emit()
	_commit_change(before, "add road point")
	return road_index

func move_road_point(road_index: int, point_index: int, world_position: Vector3) -> bool:
	if road_index < 0 or road_index >= road_paths.size(): return false
	var points := road_paths[road_index]
	if point_index < 0 or point_index >= points.size(): return false
	var before := _begin_change()
	points[point_index] = to_local(world_position)
	road_paths[road_index] = points
	_rebuild_roads()
	document_changed.emit()
	_commit_change(before, "move road point")
	return true

func remove_road_point(road_index: int, point_index: int) -> bool:
	if road_index < 0 or road_index >= road_paths.size(): return false
	var points := road_paths[road_index]
	if point_index < 0 or point_index >= points.size(): return false
	var before := _begin_change()
	points.remove_at(point_index)
	road_paths[road_index] = points
	_rebuild_roads()
	document_changed.emit()
	_commit_change(before, "remove road point")
	return true

func remove_road(road_index: int) -> bool:
	if road_index < 0 or road_index >= road_paths.size(): return false
	var before := _begin_change()
	road_paths.remove_at(road_index)
	_rebuild_roads()
	document_changed.emit()
	_commit_change(before, "remove road")
	return true

func set_road_width(value: float) -> bool:
	var next := clampf(value, 0.5, 32.0)
	if is_equal_approx(next, road_width): return true
	var before := _begin_change()
	road_width = next
	_rebuild_roads()
	document_changed.emit()
	_commit_change(before, "road width")
	return true

func get_road_count() -> int:
	return road_paths.size()

# ---------------------------------------------------------------------------
# Spawns
# ---------------------------------------------------------------------------

func add_spawn(world_position: Vector3, spawn_type: String = "zombie", asset_id: String = "") -> int:
	var before := _begin_change()
	spawn_points.append({"type": spawn_type, "asset_id": asset_id, "position": to_local(world_position), "rotation_y": 0.0})
	_rebuild_spawns()
	document_changed.emit()
	_commit_change(before, "add spawn")
	return spawn_points.size() - 1

func move_spawn(index: int, world_position: Vector3) -> bool:
	if index < 0 or index >= spawn_points.size(): return false
	var before := _begin_change()
	var spawn: Dictionary = spawn_points[index]
	spawn.position = to_local(world_position)
	spawn_points[index] = spawn
	_rebuild_spawns()
	document_changed.emit()
	_commit_change(before, "move spawn")
	return true

func set_spawn_rotation(index: int, yaw_degrees: float) -> bool:
	if index < 0 or index >= spawn_points.size(): return false
	var before := _begin_change()
	var spawn: Dictionary = spawn_points[index]
	spawn.rotation_y = wrapf(yaw_degrees, -180.0, 180.0)
	spawn_points[index] = spawn
	_rebuild_spawns()
	document_changed.emit()
	_commit_change(before, "rotate spawn")
	return true

func remove_spawn(index: int) -> bool:
	if index < 0 or index >= spawn_points.size(): return false
	var before := _begin_change()
	spawn_points.remove_at(index)
	_rebuild_spawns()
	document_changed.emit()
	_commit_change(before, "remove spawn")
	return true

func remove_spawn_near(world_position: Vector3, max_distance := 2.0) -> bool:
	var local := to_local(world_position)
	var closest_index := -1
	var closest_distance := max_distance
	for index in spawn_points.size():
		var distance := local.distance_to(spawn_points[index].position)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return remove_spawn(closest_index)

func get_spawns_of_type(spawn_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spawn in spawn_points:
		if str(spawn.type) == spawn_type: result.append(spawn.duplicate(true))
	return result

func get_spawn_count() -> int:
	return spawn_points.size()

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func save_document(path: String) -> Error:
	var data := get_state()
	data["format"] = FORMAT
	var spawns: Array = []
	for spawn in spawn_points:
		var position: Vector3 = spawn.position
		spawns.append({"type": str(spawn.type), "asset_id": str(spawn.asset_id), "position": [position.x, position.y, position.z], "rotation_y": float(spawn.get("rotation_y", 0.0))})
	data["spawns"] = spawns
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK

func load_document(path: String) -> Error:
	if not FileAccess.file_exists(path): return ERR_FILE_NOT_FOUND
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK or not parser.data is Dictionary: return ERR_PARSE_ERROR
	var data: Dictionary = parser.data
	if data.get("format") != FORMAT: return ERR_INVALID_DATA
	update_state(data)
	_ensure_history()
	history.clear()
	document_changed.emit()
	return OK

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _ensure_data() -> void:
	var expected := (terrain_resolution + 1) * (terrain_resolution + 1)
	if terrain_heights.size() != expected:
		var old := terrain_heights
		terrain_heights.resize(expected)
		for index in expected:
			terrain_heights[index] = old[index] if index < old.size() else 0.0
	if _terrain_mesh == null:
		_terrain_mesh = MeshInstance3D.new()
		_terrain_mesh.name = "EditableTerrain"
		add_child(_terrain_mesh)
	if _roads_root == null:
		_roads_root = Node3D.new()
		_roads_root.name = "Roads"
		add_child(_roads_root)
	if _spawns_root == null:
		_spawns_root = Node3D.new()
		_spawns_root.name = "SpawnMarkers"
		add_child(_spawns_root)

func _height_index(x: int, z: int) -> float:
	var index := z * (terrain_resolution + 1) + x
	return terrain_heights[index] if index >= 0 and index < terrain_heights.size() else 0.0

# Spawn dictionaries come either from live state (position is Vector3) or from
# JSON/undo snapshots (position is [x, y, z]).
func _spawn_from_data(spawn: Variant) -> Dictionary:
	var source: Dictionary = spawn if spawn is Dictionary else {}
	var raw_position: Variant = source.get("position", Vector3.ZERO)
	var position := Vector3.ZERO
	if raw_position is Vector3:
		position = raw_position
	elif raw_position is Array and raw_position.size() >= 3:
		position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	return {"type": str(source.get("type", "zombie")), "asset_id": str(source.get("asset_id", "")), "position": position, "rotation_y": float(source.get("rotation_y", 0.0))}

func _vertex_position(x: int, z: int) -> Vector3:
	var half := terrain_size * 0.5
	return Vector3(-half.x + terrain_size.x * x / terrain_resolution, _height_index(x, z), -half.y + terrain_size.y * z / terrain_resolution)

func _rebuild_all() -> void:
	_ensure_data()
	_rebuild_terrain()
	_rebuild_roads()
	_rebuild_spawns()

func _rebuild_terrain() -> void:
	if _terrain_mesh == null: return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in terrain_resolution:
		for x in terrain_resolution:
			var a := _vertex_position(x, z)
			var b := _vertex_position(x + 1, z)
			var c := _vertex_position(x, z + 1)
			var d := _vertex_position(x + 1, z + 1)
			tool.add_vertex(a); tool.add_vertex(c); tool.add_vertex(b)
			tool.add_vertex(b); tool.add_vertex(c); tool.add_vertex(d)
	tool.generate_normals()
	_terrain_mesh.mesh = tool.commit()
	_terrain_mesh.material_override = terrain_material
	_rebuild_collision()

func _rebuild_collision() -> void:
	if not generate_collision:
		if _collision_shape != null: _collision_shape.shape = null
		return
	if _collision_body == null:
		_collision_body = StaticBody3D.new()
		_collision_body.name = "TerrainCollision"
		add_child(_collision_body)
		_collision_shape = CollisionShape3D.new()
		_collision_body.add_child(_collision_shape)
	if _terrain_mesh != null and _terrain_mesh.mesh != null:
		_collision_shape.shape = _terrain_mesh.mesh.create_trimesh_shape()

func _rebuild_roads() -> void:
	if _roads_root == null: return
	for child in _roads_root.get_children():
		_roads_root.remove_child(child)
		child.queue_free()
	for points in road_paths:
		if points.size() < 2: continue
		var curve := Curve3D.new()
		for point in points: curve.add_point(point)
		var path := Path3D.new()
		path.curve = curve
		_roads_root.add_child(path)
		var surface := MeshInstance3D.new()
		surface.name = "RoadSurface"
		surface.mesh = _build_road_mesh(points)
		surface.material_override = road_material
		_roads_root.add_child(surface)

func _build_road_mesh(points: PackedVector3Array) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in points.size() - 1:
		var direction := (points[index + 1] - points[index]).normalized()
		var side := direction.cross(Vector3.UP).normalized() * road_width * 0.5
		var left_start := points[index] + side
		var right_start := points[index] - side
		var left_end := points[index + 1] + side
		var right_end := points[index + 1] - side
		surface_tool.add_vertex(left_start)
		surface_tool.add_vertex(right_start)
		surface_tool.add_vertex(left_end)
		surface_tool.add_vertex(left_end)
		surface_tool.add_vertex(right_start)
		surface_tool.add_vertex(right_end)
	surface_tool.generate_normals()
	return surface_tool.commit()

func _rebuild_spawns() -> void:
	if _spawns_root == null: return
	for child in _spawns_root.get_children():
		_spawns_root.remove_child(child)
		child.queue_free()
	for index in spawn_points.size():
		var spawn: Dictionary = spawn_points[index]
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		marker.mesh = sphere
		marker.position = spawn.position
		marker.rotation.y = deg_to_rad(float(spawn.get("rotation_y", 0.0)))
		marker.name = "%s_%02d" % [str(spawn.get("type", "spawn")), index]
		_spawns_root.add_child(marker)
