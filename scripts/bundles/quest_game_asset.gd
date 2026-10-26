extends BaseGameAsset
class_name QuestGameAsset

# Godot-side port of U3 QuestAsset (conditions/rewards) with tolerant field
# aliases for community JSON exports. PlayerQuests evaluates objective progress
# and grants rewards decorated with this data.

@export var description := ""
@export var level := 0
@export var npc_id: StringName
@export var objectives: Array[Dictionary] = []
@export var prerequisites: Array[StringName] = []
@export var rewards: Array[Dictionary] = []
@export var abandonment_rewards: Array[Dictionary] = []
@export var flags_set: Dictionary = {}
@export var repeatable := false

func populate(data: Dictionary, source_path := "") -> void:
	super.populate(data, source_path)
	description = str(data.get("description", data.get("questDescription", data.get("text", ""))))
	level = int(data.get("level", data.get("Level", 0)))
	npc_id = StringName(str(data.get("npc", data.get("npc_id", data.get("npcID", "")))))
	objectives = _dictionary_entries(data.get("objectives", data.get("conditions", data.get("Conditions", []))))
	rewards = _dictionary_entries(data.get("rewards", data.get("Rewards", [])))
	abandonment_rewards = _dictionary_entries(data.get("abandonment_rewards", data.get("AbandonmentRewards", [])))
	var raw_flags: Variant = data.get("flags", data.get("set_flags", data.get("Flags", {})))
	flags_set = raw_flags.duplicate(true) if raw_flags is Dictionary else {}
	repeatable = bool(data.get("repeatable", data.get("can_repeat", false)))
	prerequisites.clear()
	var raw: Variant = data.get("prerequisites", data.get("required_quests", data.get("RequiredQuests", [])))
	if raw is Array:
		for entry in raw: prerequisites.append(StringName(str(entry.get("id", "")) if entry is Dictionary else str(entry)))

func _dictionary_entries(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary: result.append(entry.duplicate(true))
	return result
