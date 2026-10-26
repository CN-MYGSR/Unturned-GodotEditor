extends Node
class_name CraftingManager

signal crafted(actor: Node, recipe_id: StringName, repeat_count: int)
signal craft_failed(recipe_id: StringName, reason: String)

@export var recipes: Array[CraftingRecipe] = []

func find_recipe(recipe_id: StringName) -> CraftingRecipe:
	for recipe in recipes:
		if recipe != null and recipe.recipe_id == recipe_id: return recipe
	return null

func can_craft(actor: Node, recipe_id: StringName, repeat_count := 1) -> bool:
	var recipe := find_recipe(recipe_id)
	var inventory := _find_inventory(actor)
	if recipe == null or inventory == null or not recipe.validate() or repeat_count <= 0: return false
	if repeat_count > 1 and not recipe.allow_repeat: return false
	if recipe.required_skill_level > 0:
		var skills := actor.get_node_or_null("Skills") as PlayerSkills
		if skills == null or skills.level(recipe.required_skill) < recipe.required_skill_level: return false
	for input in recipe.inputs:
		if inventory.count_item(StringName(input.item_id)) < int(input.amount) * repeat_count: return false
	var weight_delta := 0.0
	for output in recipe.outputs:
		var item_id := StringName(output.item_id)
		if not inventory.definitions.has(item_id): return false
		var definition: ItemDefinition = inventory.definitions[item_id]
		weight_delta += definition.weight * int(output.amount) * repeat_count
	return inventory.current_weight() + weight_delta <= inventory.max_weight and _has_output_slots(inventory, recipe.outputs, repeat_count)

func craft(actor: Node, recipe_id: StringName, repeat_count := 1) -> bool:
	if not can_craft(actor, recipe_id, repeat_count):
		craft_failed.emit(recipe_id, "requirements_not_met")
		return false
	var recipe := find_recipe(recipe_id)
	var inventory := _find_inventory(actor)
	var before := inventory.get_state()
	for input in recipe.inputs:
		if not inventory.remove_item(StringName(input.item_id), int(input.amount) * repeat_count):
			inventory.update_state(before)
			craft_failed.emit(recipe_id, "input_transaction_failed")
			return false
	for output in recipe.outputs:
		var remainder := inventory.add_item(StringName(output.item_id), int(output.amount) * repeat_count)
		if remainder > 0:
			inventory.update_state(before)
			craft_failed.emit(recipe_id, "output_transaction_failed")
			return false
	if recipe.experience_reward > 0:
		var skills := actor.get_node_or_null("Skills") as PlayerSkills
		if skills != null: skills.modify_experience(recipe.experience_reward * repeat_count)
	crafted.emit(actor, recipe_id, repeat_count)
	return true

func _find_inventory(actor: Node) -> PlayerInventory:
	if actor == null: return null
	var current := actor.get_node_or_null("Inventory") as PlayerInventory
	if current != null: return current
	for child in actor.get_children():
		if child is PlayerInventory: return child as PlayerInventory
	return null

func _has_output_slots(inventory: PlayerInventory, outputs: Array[Dictionary], repeat_count: int) -> bool:
	var required_slots := 0
	var projected: Dictionary = {}
	for stack in inventory.slots:
		var key := StringName(stack.item_id)
		projected[key] = int(projected.get(key, 0)) + int(stack.amount)
	for output in outputs:
		var item_id := StringName(output.item_id)
		var definition: ItemDefinition = inventory.definitions[item_id]
		var total := int(projected.get(item_id, 0)) + int(output.amount) * repeat_count
		var existing_slots := 0
		for stack in inventory.slots:
			if stack.item_id == item_id: existing_slots += 1
		var slots_for_item := ceili(float(total) / definition.max_stack)
		required_slots += maxi(0, slots_for_item - existing_slots)
		projected[item_id] = total
	return inventory.slots.size() + required_slots <= inventory.slot_capacity
