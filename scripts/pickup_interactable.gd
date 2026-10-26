extends Interactable
class_name PickupInteractable

signal pickup_amount_changed(remaining: int)

@export var item_id: StringName
@export_range(1, 999, 1) var amount := 1

func check_useable(actor: Node3D = null) -> bool:
	if not super.check_useable(actor) or actor == null:
		return false
	return _find_inventory(actor) != null and not item_id.is_empty() and amount > 0

func use(actor: Node3D) -> bool:
	var inventory := _find_inventory(actor)
	if inventory == null:
		return false
	var previous_amount := amount
	amount = inventory.add_item(item_id, amount)
	if amount == previous_amount:
		return false
	var picked_up := previous_amount - amount
	pickup_amount_changed.emit(amount)
	_notify_quests(actor, picked_up)
	if amount <= 0:
		queue_free()
	return true

# Quest asset compatibility: pickup events progress collect_item objectives.
func _notify_quests(actor: Node, picked_up: int) -> void:
	if actor == null or picked_up <= 0: return
	var quests := actor.get_node_or_null("Quests") as PlayerQuests
	if quests != null:
		quests.notify_event(&"collect_item", item_id, picked_up)

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": Color("9bd17c")}

func check_hint(actor: Node3D = null) -> Dictionary:
	var can_pick_up := actor != null and check_useable(actor)
	return {
		"visible": true,
		"text": "%s ×%d" % [interaction_name, amount] if can_pick_up else "背包已满",
		"color": Color("9bd17c") if can_pick_up else Color("d87870")
	}

func get_state() -> Dictionary:
	var state := super.get_state()
	state["amount"] = amount
	return state

func update_state(state: Dictionary) -> void:
	super.update_state(state)
	if state.has("amount"):
		amount = maxi(0, int(state.amount))

func _find_inventory(actor: Node) -> PlayerInventory:
	var inventory := actor.get_node_or_null("Inventory") as PlayerInventory
	if inventory != null:
		return inventory
	for child in actor.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null
