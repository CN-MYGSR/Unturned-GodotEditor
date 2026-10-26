extends Resource
class_name BaseGameAsset

@export var asset_id: StringName
@export var guid := ""
@export var asset_name := ""
@export var asset_type := ""
@export var origin_path := ""
@export var source_data: Dictionary = {}
@export var validation_errors: PackedStringArray = []

func populate(data: Dictionary, source_path := "") -> void:
	source_data = data.duplicate(true)
	asset_id = StringName(str(data.get("id", "")))
	guid = str(data.get("guid", "")).to_lower()
	asset_name = str(data.get("name", data.get("asset_name", "")))
	asset_type = str(data.get("type", "" )).to_lower()
	origin_path = source_path


func validate() -> void:
	validation_errors.clear()
	if asset_id.is_empty() and guid.is_empty():
		validation_errors.append("Asset requires id or guid")

func is_valid() -> bool:
	return validation_errors.is_empty()