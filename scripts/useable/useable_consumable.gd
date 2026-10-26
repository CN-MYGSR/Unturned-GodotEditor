extends UseableItem
class_name UseableConsumable


func _init() -> void:
	consumes_item = true

func can_use(actor: Node, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	if not super.can_use(actor, definition, state): return false
	var life := _find_life(actor)
	return life != null and life.can_apply_item_effects(definition.heal_amount, definition.food_amount, definition.water_amount, definition.virus_amount, definition.stamina_amount)

func use_item(actor: Node, definition: ItemDefinition, state: Dictionary = {}) -> bool:
	if not can_use(actor, definition, state): return false
	var life := _find_life(actor)
	life.apply_item_effects(definition.heal_amount, definition.food_amount, definition.water_amount, definition.virus_amount, definition.stamina_amount)
	_next_use_msec = Time.get_ticks_msec() + int(maxf(cooldown, definition.use_cooldown) * 1000.0)
	play_presentation(actor, definition.animation_action, definition.voice_event)
	use_started.emit(actor, definition.item_id)
	use_finished.emit(actor, definition.item_id, true)
	return true

func _find_life(actor: Node) -> PlayerLife:
	var current: Node = actor
	while current != null:
		var life := current.get_node_or_null("Life") as PlayerLife
		if life != null: return life
		if current is PlayerLife: return current as PlayerLife
		current = current.get_parent()
	return null


