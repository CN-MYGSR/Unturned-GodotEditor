extends BaseGameAsset
class_name SkillGameAsset

# Godot-side port of a U3-style skill definition. U3 skills are enum-driven, so
# this asset layer mirrors the common JSON fields used by community skill packs
# (max level / cost progression / difficulty / prerequisites / effects) and feeds
# PlayerSkills without hard-coding the skill list.

@export var maximum_level := 7
@export var base_cost := 10
@export var cost_per_level := 5
@export var max_unlockable_level := -1
@export var cost_multiplier := 1.0
@export var difficulty := 0
@export var required_level := 0
@export var prerequisites: Array[StringName] = []
@export var boost := 1.0
@export var group_id: StringName
@export var icon_path := ""
@export var effects: Dictionary = {}

func populate(data: Dictionary, source_path := "") -> void:
	super.populate(data, source_path)
	maximum_level = maxi(0, int(data.get("maximum_level", data.get("max_level", data.get("max", data.get("MaxLevel", 7))))))
	base_cost = maxi(0, int(data.get("base_cost", data.get("cost", data.get("Cost", 10)))))
	cost_per_level = maxi(0, int(data.get("cost_per_level", data.get("perLevelCostIncrease", data.get("cost_increment", data.get("CostIncrease", 5))))))
	max_unlockable_level = int(data.get("maxUnlockableLevel", data.get("max_unlockable_level", -1)))
	cost_multiplier = maxf(0.0, float(data.get("costMultiplier", data.get("cost_multiplier", 1.0))))
	difficulty = _to_difficulty(data.get("difficulty", data.get("Difficulty", 0)))
	required_level = maxi(0, int(data.get("required_level", data.get("RequiredLevel", 0))))
	boost = maxf(0.0, float(data.get("boost", data.get("Boost", 1.0))))
	group_id = StringName(str(data.get("group", data.get("skillset", data.get("SkillSet", "")))))
	icon_path = str(data.get("icon", ""))
	effects = data.get("effects", {}).duplicate(true) if data.get("effects", {}) is Dictionary else {}
	prerequisites.clear()
	var raw: Variant = data.get("prerequisites", data.get("required_skills", data.get("RequiredSkills", [])))
	if raw is Array:
		for entry in raw:
			prerequisites.append(StringName(str(entry.get("id", "")) if entry is Dictionary else str(entry)))

func effect_value(effect_id: StringName) -> float:
	return float(effects.get(effect_id, effects.get(String(effect_id), 0.0)))

func _to_difficulty(value: Variant) -> int:
	if value is int or value is float: return int(value)
	match str(value).to_lower():
		"easy", "trivial": return 0
		"normal", "medium": return 1
		"hard", "difficult": return 2
		"expert", "extreme": return 3
	return int(str(value)) if str(value).is_valid_int() else 0
