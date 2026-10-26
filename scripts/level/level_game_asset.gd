extends BaseGameAsset
class_name LevelGameAsset

@export var size := Vector2i(1024, 1024)
@export var world_scene: PackedScene
@export var gravity := 9.8
@export var max_walkable_slope := 45.0
@export var placements: Array[LevelPlacement] = []
@export var spawn_points: Array[LevelSpawnData] = []
@export var settings: Dictionary = {}

func populate(data: Dictionary, source_path := "") -> void:
	super.populate(data, source_path)
	var raw_size: Array = data.get("size", [1024, 1024])
	if raw_size.size() >= 2:
		size = Vector2i(int(raw_size[0]), int(raw_size[1]))
	gravity = float(data.get("gravity", 9.8))
	max_walkable_slope = float(data.get("max_walkable_slope", 45.0))
	settings = data.get("settings", {}).duplicate(true)
	placements.clear()
	for raw_placement in data.get("placements", []):
		if not raw_placement is Dictionary:
			continue
		var placement := LevelPlacement.new()
		placement.asset_id = StringName(str(raw_placement.get("asset_id", "")))
		placement.position = _vector3_from(raw_placement.get("position", [0, 0, 0]))
		placement.rotation_degrees = _vector3_from(raw_placement.get("rotation", [0, 0, 0]))
		placement.scale = _vector3_from(raw_placement.get("scale", [1, 1, 1]))
		var raw_region: Array = raw_placement.get("region", [0, 0])
		if raw_region.size() >= 2:
			placement.region = Vector2i(int(raw_region[0]), int(raw_region[1]))
		placements.append(placement)
	spawn_points.clear()
	for raw_spawn in data.get("spawn_points", []):
		if not raw_spawn is Dictionary:
			continue
		var spawn := LevelSpawnData.new()
		spawn.spawn_type = str(raw_spawn.get("type", "player"))
		spawn.position = _vector3_from(raw_spawn.get("position", [0, 0, 0]))
		spawn.rotation_degrees = _vector3_from(raw_spawn.get("rotation", [0, 0, 0]))
		spawn.weight = maxf(0.0, float(raw_spawn.get("weight", 1.0)))
		spawn_points.append(spawn)
	var scene_path := str(data.get("scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		world_scene = load(scene_path) as PackedScene
	validate()

func validate() -> void:
	super.validate()
	if size.x <= 0 or size.y <= 0:
		validation_errors.append("Level size must be positive")

func get_spawn_points(spawn_type: String = "player") -> Array[LevelSpawnData]:
	var result: Array[LevelSpawnData] = []
	for spawn in spawn_points:
		if spawn.spawn_type == spawn_type:
			result.append(spawn)
	return result

func _vector3_from(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO