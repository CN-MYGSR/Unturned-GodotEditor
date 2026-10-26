extends Resource
class_name LevelSpawnData

@export var spawn_type := "player"
@export var position := Vector3.ZERO
@export var rotation_degrees := Vector3.ZERO
@export var weight := 1.0
@export var tags: PackedStringArray = []