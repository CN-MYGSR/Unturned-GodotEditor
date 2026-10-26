extends Node
class_name GameAssetDatabase

signal asset_registered(asset: BaseGameAsset)
signal asset_database_loaded(loaded_count: int, error_count: int)

var by_id: Dictionary = {}
var by_guid: Dictionary = {}
var by_type: Dictionary = {}
var errors: PackedStringArray = []

func clear() -> void:
	by_id.clear()
	by_guid.clear()
	by_type.clear()
	errors.clear()

func register_asset(asset: BaseGameAsset) -> bool:
	if asset == null or not asset.is_valid():
		if asset != null:
			_errors_from_asset(asset)
		return false
	if not asset.asset_id.is_empty() and by_id.has(asset.asset_id):
		errors.append("Duplicate asset id: " + str(asset.asset_id))
		return false
	if not asset.guid.is_empty() and by_guid.has(asset.guid):
		errors.append("Duplicate asset guid: " + asset.guid)
		return false
	if not asset.asset_id.is_empty():
		by_id[asset.asset_id] = asset
	if not asset.guid.is_empty():
		by_guid[asset.guid] = asset
	if not by_type.has(asset.asset_type):
		by_type[asset.asset_type] = []
	by_type[asset.asset_type].append(asset)
	asset_registered.emit(asset)
	return true

func find_by_id(asset_id: StringName) -> BaseGameAsset:
	return by_id.get(asset_id) as BaseGameAsset

func find_by_guid(guid: String) -> BaseGameAsset:
	return by_guid.get(guid.to_lower()) as BaseGameAsset

func find_all_of_type(asset_type: String) -> Array:
	return by_type.get(asset_type.to_lower(), []).duplicate()

func load_directory(path: String) -> int:
	var loaded := _scan_directory(path)
	asset_database_loaded.emit(loaded, errors.size())
	return loaded

func load_json_file(path: String) -> BaseGameAsset:
	var loaded := load_json_file_entries(path)
	return loaded[0] if not loaded.is_empty() else null

func load_json_file_entries(path: String) -> Array[BaseGameAsset]:
	var loaded: Array[BaseGameAsset] = []
	if not FileAccess.file_exists(path):
		errors.append("Asset file not found: " + path)
		return loaded
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		errors.append("Invalid asset JSON in %s: %s (line %d)" % [path, parser.get_error_message(), parser.get_error_line()])
		return loaded
	var parsed: Variant = parser.data
	var entries: Array = []
	if parsed is Dictionary:
		entries.append(parsed)
	elif parsed is Array:
		entries = parsed
	else:
		errors.append("Asset JSON root must be an object or array: " + path)
		return loaded
	for data in entries:
		if not data is Dictionary:
			errors.append("Asset entry must be an object: " + path)
			continue
		var asset := _create_asset(str(data.get("type", "")))
		if asset == null:
			errors.append("Unsupported asset type in " + path + ": " + str(data.get("type", "")))
			continue
		asset.populate(data, path)
		if register_asset(asset):
			loaded.append(asset)
	return loaded

func _scan_directory(path: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		errors.append("Cannot open asset directory: " + path)
		return 0
	var loaded := 0
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var child := path.path_join(entry)
		if directory.current_is_dir():
			loaded += _scan_directory(child)
		elif entry.get_extension().to_lower() == "json":
			loaded += load_json_file_entries(child).size()
		entry = directory.get_next()
	directory.list_dir_end()
	return loaded
func _create_asset(asset_type: String) -> BaseGameAsset:
	match asset_type.to_lower():
		"item":
			return ItemGameAsset.new()
		"object":
			return ObjectGameAsset.new()
		"spawn_table":
			return SpawnTableGameAsset.new()
		"skill", "skillset":
			return SkillGameAsset.new()
		"quest", "npc_quest":
			return QuestGameAsset.new()
		"level":
			return LevelGameAsset.new()
	return null

func _errors_from_asset(asset: BaseGameAsset) -> void:
	for message in asset.validation_errors:
		errors.append("%s: %s" % [asset.asset_name, message])
