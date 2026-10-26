extends BaseGameAsset
class_name ObjectGameAsset

@export var scene: PackedScene
@export var collision_enabled := true
@export var interactable := false
@export var health := 0.0
@export var tags: PackedStringArray = []

func populate(data: Dictionary, source_path := "") -> void:
	super.populate(data, source_path)
	collision_enabled = bool(data.get("collision", true))
	interactable = bool(data.get("interactable", false))
	health = maxf(0.0, float(data.get("health", 0.0)))
	tags.clear()
	for tag in data.get("tags", []):
		tags.append(str(tag))
	var scene_path := str(data.get("scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		scene = load(scene_path) as PackedScene
	validate()

func validate() -> void:
	super.validate()
	if not scene:
		validation_errors.append("Object asset has no loadable scene")