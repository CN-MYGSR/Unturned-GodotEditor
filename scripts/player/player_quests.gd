extends Node
class_name PlayerQuests

# Per-player quest state port of U3 PlayerQuests, extended with tolerant
# QuestGameAsset compatibility: objective events, asset prerequisites, flags and
# reward granting (experience/items/flags/reputation).

signal quest_added(quest_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_removed(quest_id: StringName)
signal flag_changed(flag_id: StringName, value: Variant)
signal tracked_quest_changed(quest_id: StringName)
signal quest_progressed(quest_id: StringName, objective_index: int, progress: int, target: int)
signal reward_granted(quest_id: StringName, reward: Dictionary)

var active_quests: Dictionary = {}
var completed_quests: Array[StringName] = []
var flags: Dictionary = {}
var tracked_quest: StringName
var _skills: PlayerSkills
var _inventory: PlayerInventory

func bind_rewards(skills: PlayerSkills, inventory: PlayerInventory) -> void:
	_skills = skills
	_inventory = inventory

func start_quest(quest_id: StringName, data: Dictionary = {}) -> bool:
	if quest_id.is_empty() or active_quests.has(quest_id) or completed_quests.has(quest_id): return false
	active_quests[quest_id] = data.duplicate(true)
	quest_added.emit(quest_id)
	return true

func complete_quest(quest_id: StringName) -> bool:
	if not active_quests.has(quest_id): return false
	active_quests.erase(quest_id)
	completed_quests.append(quest_id)
	quest_completed.emit(quest_id)
	if tracked_quest == quest_id: track_quest(&"")
	return true

func remove_quest(quest_id: StringName) -> bool:
	if not active_quests.erase(quest_id): return false
	quest_removed.emit(quest_id)
	if tracked_quest == quest_id: track_quest(&"")
	return true

func set_flag(flag_id: StringName, value: Variant) -> void:
	if flag_id.is_empty() or flags.get(flag_id) == value: return
	flags[flag_id] = value
	flag_changed.emit(flag_id, value)

func get_flag(flag_id: StringName, default_value: Variant = null) -> Variant:
	return flags.get(flag_id, default_value)

func track_quest(quest_id: StringName) -> bool:
	if not quest_id.is_empty() and not active_quests.has(quest_id): return false
	if tracked_quest == quest_id: return true
	tracked_quest = quest_id
	tracked_quest_changed.emit(quest_id)
	return true

func get_state() -> Dictionary:
	return {"active_quests": active_quests.duplicate(true), "completed_quests": completed_quests.duplicate(), "flags": flags.duplicate(true), "tracked_quest": tracked_quest}

func update_state(state: Dictionary) -> void:
	active_quests = state.get("active_quests", {}).duplicate(true)
	completed_quests.clear()
	for quest_id in state.get("completed_quests", []): completed_quests.append(StringName(quest_id))
	flags = state.get("flags", {}).duplicate(true)
	tracked_quest = StringName(state.get("tracked_quest", ""))
	tracked_quest_changed.emit(tracked_quest)

func start_from_asset(asset: QuestGameAsset) -> bool:
	if asset == null: return false
	for prerequisite in asset.prerequisites:
		if not completed_quests.has(prerequisite): return false
	var objectives: Array[Dictionary] = []
	for objective in asset.objectives:
		objectives.append({"definition": objective.duplicate(true), "progress": 0, "complete": false})
	return start_quest(asset.asset_id, {"name": asset.asset_name, "objectives": objectives, "rewards": asset.rewards.duplicate(true), "abandonment_rewards": asset.abandonment_rewards.duplicate(true), "repeatable": asset.repeatable, "flags": asset.flags_set.duplicate(true), "level": asset.level, "npc": asset.npc_id})

func add_objective_progress(quest_id: StringName, objective_index: int, amount := 1) -> bool:
	if amount <= 0 or not active_quests.has(quest_id): return false
	var data: Dictionary = active_quests[quest_id]
	var objectives: Array = data.get("objectives", [])
	if objective_index < 0 or objective_index >= objectives.size(): return false
	var objective: Dictionary = objectives[objective_index]
	if objective.get("complete", false): return false
	var definition: Dictionary = objective.get("definition", {})
	var target := maxi(1, int(definition.get("amount", definition.get("count", 1))))
	objective.progress = mini(target, int(objective.get("progress", 0)) + amount)
	objective.complete = int(objective.progress) >= target
	objectives[objective_index] = objective
	data.objectives = objectives
	active_quests[quest_id] = data
	quest_progressed.emit(quest_id, objective_index, int(objective.progress), target)
	return true

func is_quest_objectives_complete(quest_id: StringName) -> bool:
	if not active_quests.has(quest_id): return false
	var objectives: Array = active_quests[quest_id].get("objectives", [])
	if objectives.is_empty(): return false
	for objective in objectives:
		if not objective.get("complete", false): return false
	return true

# Gameplay event entry point: "killed a zombie", "collected an item", etc.
# Progresses every matching objective and auto-completes quests whose objectives
# are all done (granting asset rewards when bound). Returns progressed count.
func notify_event(event_type: StringName, target_id: StringName = &"", amount := 1) -> int:
	if event_type.is_empty() or amount <= 0: return 0
	var progressed := 0
	var quests_to_finish: Array[StringName] = []
	for quest_id in active_quests.keys():
		var data: Dictionary = active_quests[quest_id]
		var objectives: Array = data.get("objectives", [])
		var changed := false
		for index in objectives.size():
			var objective: Dictionary = objectives[index]
			if objective.get("complete", false): continue
			var definition: Dictionary = objective.get("definition", {})
			if not objective_matches(definition, event_type, target_id): continue
			var target := maxi(1, int(definition.get("amount", definition.get("count", 1))))
			objective.progress = mini(target, int(objective.get("progress", 0)) + amount)
			objective.complete = int(objective.progress) >= target
			objectives[index] = objective
			changed = true
			progressed += 1
			quest_progressed.emit(quest_id, index, int(objective.progress), target)
		if changed:
			data.objectives = objectives
			active_quests[quest_id] = data
			if is_quest_objectives_complete(quest_id): quests_to_finish.append(quest_id)
	for quest_id in quests_to_finish:
		finish_quest(quest_id)
	return progressed

func objective_matches(definition: Dictionary, event_type: StringName, target_id: StringName = &"") -> bool:
	var objective_type := StringName(str(definition.get("type", definition.get("event", ""))).to_lower())
	if objective_type.is_empty(): return false
	var target := StringName(str(definition.get("target", definition.get("id", definition.get("item", definition.get("asset", ""))))))
	if not target.is_empty() and target != target_id: return false
	match objective_type:
		&"kill", &"kill_zombie", &"zombie", &"kill_enemy":
			return event_type in [&"kill", &"kill_zombie", &"zombie", &"kill_enemy"]
		&"collect", &"collect_item", &"item", &"pickup":
			return event_type in [&"collect", &"collect_item", &"pickup"]
		&"interact", &"use", &"use_object":
			return event_type in [&"interact", &"use"]
		&"flag":
			return event_type == &"flag"
		&"enter", &"location", &"volume":
			return event_type in [&"enter", &"location"]
		&"talk", &"npc":
			return event_type in [&"talk", &"npc"]
	return objective_type == event_type

# Complete a quest and apply its captured asset rewards/flags.
func finish_quest(quest_id: StringName) -> bool:
	if not active_quests.has(quest_id): return false
	var data: Dictionary = active_quests[quest_id]
	if not complete_quest(quest_id): return false
	var quest_flags: Variant = data.get("flags", {})
	if quest_flags is Dictionary:
		for key in quest_flags: set_flag(StringName(key), quest_flags[key])
	grant_rewards(quest_id, data.get("rewards", []))
	return true

func grant_rewards(quest_id: StringName, rewards: Array) -> Array[Dictionary]:
	var granted: Array[Dictionary] = []
	for entry in rewards:
		if not entry is Dictionary: continue
		var reward: Dictionary = (entry as Dictionary).duplicate(true)
		_apply_reward(reward)
		reward_granted.emit(quest_id, reward)
		granted.append(reward)
	return granted

func _apply_reward(reward: Dictionary) -> void:
	var reward_type := str(reward.get("type", reward.get("kind", ""))).to_lower()
	var amount := int(reward.get("amount", reward.get("count", 1)))
	match reward_type:
		"experience", "exp":
			if _skills != null: _skills.modify_experience(amount)
		"reputation":
			if _skills != null: _skills.set_reputation(_skills.reputation + amount)
		"item", "give", "collect":
			var item_id := StringName(str(reward.get("id", reward.get("item", ""))))
			if _inventory != null and not item_id.is_empty():
				_inventory.add_item(item_id, amount)
		"flag":
			set_flag(StringName(str(reward.get("id", reward.get("flag", "")))), reward.get("value", true))
