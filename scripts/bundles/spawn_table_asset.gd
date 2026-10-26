extends BaseGameAsset
class_name SpawnTableGameAsset

@export var entries: Array[Dictionary] = []

func populate(data: Dictionary, source_path := "") -> void:
	super.populate(data, source_path)
	entries.clear()
	for raw_entry in data.get("entries", []):
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry.duplicate(true)
			entry["weight"] = maxi(0, int(entry.get("weight", 1)))
			entries.append(entry)
	validate()

func pick(rng: RandomNumberGenerator = null) -> StringName:
	var total := 0
	for entry in entries:
		total += int(entry.get("weight", 0))
	if total <= 0:
		return &""
	var picker := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	var ticket := picker.randi_range(1, total)
	for entry in entries:
		ticket -= int(entry.get("weight", 0))
		if ticket <= 0:
			return StringName(str(entry.get("asset_id", "")))
	return &""

func validate() -> void:
	super.validate()
	if entries.is_empty():
		validation_errors.append("Spawn table has no entries")