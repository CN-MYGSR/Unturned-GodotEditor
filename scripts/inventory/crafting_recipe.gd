extends Resource
class_name CraftingRecipe

@export var recipe_id: StringName
@export var display_name := ""
@export var inputs: Array[Dictionary] = []
@export var outputs: Array[Dictionary] = []
@export var required_skill: StringName
@export_range(0, 255, 1) var required_skill_level := 0
@export var experience_reward := 0
@export var allow_repeat := true

func validate() -> bool:
	if recipe_id.is_empty() or inputs.is_empty() or outputs.is_empty(): return false
	for entry in inputs + outputs:
		if StringName(entry.get("item_id", "")).is_empty() or int(entry.get("amount", 0)) <= 0: return false
	return true
