extends Node
class_name PlayerSkills

# Per-player skills port of U3 PlayerSkills. U3 skills are a fixed enum; this
# layer additionally registers SkillGameAsset definitions (cost/max/prereqs/
# effects) so community skill JSON can drive progression without code changes.

signal experience_changed(value: int)
signal reputation_changed(value: int)
signal skill_changed(skill_id: StringName, level: int)

@export var max_experience := 4294967295
@export var max_reputation := 1000000
var experience := 0
var reputation := 0
var skills: Dictionary = {}
var skill_assets: Dictionary = {}

func define_skill(skill_id: StringName, maximum: int, base_cost: int = 1, cost_per_level: int = 1) -> void:
	if skill_id.is_empty(): return
	var current: Dictionary = skills.get(skill_id, {})
	skills[skill_id] = {"level": mini(int(current.get("level", 0)), maxi(0, maximum)), "max": maxi(0, maximum), "base_cost": maxi(0, base_cost), "cost_per_level": maxi(0, cost_per_level)}

func register_skill_asset(asset: SkillGameAsset) -> void:
	if asset == null: return
	skill_assets[asset.asset_id] = asset
	define_skill(asset.asset_id, asset.maximum_level, asset.base_cost, asset.cost_per_level)

func get_skill_asset(skill_id: StringName) -> SkillGameAsset:
	return skill_assets.get(skill_id) as SkillGameAsset

func level(skill_id: StringName) -> int:
	return int(skills.get(skill_id, {}).get("level", 0))

func mastery(skill_id: StringName) -> float:
	var entry: Dictionary = skills.get(skill_id, {})
	var maximum := int(entry.get("max", 0))
	return 0.0 if maximum <= 0 else clampf(float(entry.get("level", 0)) / maximum, 0.0, 1.0)

func upgrade_cost(skill_id: StringName) -> int:
	var entry: Dictionary = skills.get(skill_id, {})
	var cost := int(entry.get("base_cost", 0)) + int(entry.get("level", 0)) * int(entry.get("cost_per_level", 0))
	var asset := get_skill_asset(skill_id)
	return cost if asset == null else maxi(0, int(round(cost * asset.cost_multiplier)))

# Asset-declared prerequisites require each prerequisite at required_level
# (at least level 1). Skills without an asset keep the legacy free progression.
func can_upgrade(skill_id: StringName, force := false) -> bool:
	if not skills.has(skill_id): return false
	var entry: Dictionary = skills[skill_id]
	if int(entry.level) >= int(entry.max): return false
	var asset := get_skill_asset(skill_id)
	if asset != null and not asset.prerequisites.is_empty():
		var required := maxi(1, asset.required_level)
		for prerequisite in asset.prerequisites:
			if level(prerequisite) < required: return false
	if force: return true
	return experience >= upgrade_cost(skill_id)

func upgrade(skill_id: StringName, force := false) -> bool:
	if not can_upgrade(skill_id, force): return false
	var entry: Dictionary = skills[skill_id]
	if not force: set_experience(experience - upgrade_cost(skill_id))
	entry.level = int(entry.level) + 1
	skills[skill_id] = entry
	skill_changed.emit(skill_id, entry.level)
	return true

# Total accumulated effect value, e.g. effect id "sprint_speed" with 0.05 per
# level at level 3 -> 0.15. Used by movement/health code to apply skill bonuses.
func get_effect_total(effect_id: StringName) -> float:
	var total := 0.0
	for skill_id in skills:
		var asset := get_skill_asset(StringName(skill_id))
		if asset == null: continue
		total += asset.effect_value(effect_id) * float(level(StringName(skill_id)))
	return total

func set_experience(value: int) -> void:
	var next := clampi(value, 0, max_experience)
	if next == experience: return
	experience = next
	experience_changed.emit(experience)

func modify_experience(delta: int) -> void:
	set_experience(experience + delta)

func set_reputation(value: int) -> void:
	var next := clampi(value, -max_reputation, max_reputation)
	if next == reputation: return
	reputation = next
	reputation_changed.emit(reputation)

func get_state() -> Dictionary:
	return {"experience": experience, "reputation": reputation, "skills": skills.duplicate(true)}

func update_state(state: Dictionary) -> void:
	set_experience(int(state.get("experience", experience)))
	set_reputation(int(state.get("reputation", reputation)))
	if state.get("skills") is Dictionary:
		for key in state.skills:
			if not skills.has(key): continue
			var entry: Dictionary = skills[key]
			entry.level = clampi(int(state.skills[key]), 0, int(entry.max)) if state.skills[key] is int else clampi(int(state.skills[key].get("level", entry.level)), 0, int(entry.max))
			skills[key] = entry
			skill_changed.emit(key, entry.level)

func load_skill_assets(assets: Array) -> int:
	var count := 0
	for asset in assets:
		if asset is SkillGameAsset:
			register_skill_asset(asset)
			count += 1
	return count
