extends Interactable
class_name InteractableStorage

signal storage_opened(actor: Node3D, storage: InteractableStorage)
signal contents_changed

@export_range(1, 128, 1) var capacity := 24
@export var locked := false
@export var display_name := "储物箱"

var stacks: Array[Dictionary] = []

func check_interactable() -> bool:
	return super.check_interactable() and not locked

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": Color("d4b26f") if locked else Color("93c9a0")}

func check_hint(_actor: Node3D = null) -> Dictionary:
	return {"visible": true, "text": "上锁" if locked else "打开 %s" % display_name, "color": Color("d87870") if locked else Color.WHITE}

func use(actor: Node3D) -> bool:
	storage_opened.emit(actor, self)
	return true

func add_stack(item_id: StringName, amount: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return amount
	for stack in stacks:
		if stack.item_id == item_id:
			stack.amount += amount
			contents_changed.emit()
			return 0
	if stacks.size() >= capacity:
		return amount
	stacks.append({"item_id": item_id, "amount": amount})
	contents_changed.emit()
	return 0

func remove_stack(index: int, amount: int = -1) -> Dictionary:
	if index < 0 or index >= stacks.size():
		return {}
	var stack: Dictionary = stacks[index]
	var removed := int(stack.amount) if amount <= 0 else mini(amount, int(stack.amount))
	var result := {"item_id": stack.item_id, "amount": removed}
	stack.amount -= removed
	if stack.amount <= 0:
		stacks.remove_at(index)
	contents_changed.emit()
	return result

func get_state() -> Dictionary:
	var state := super.get_state()
	state["locked"] = locked
	state["stacks"] = stacks.duplicate(true)
	return state

func update_state(state: Dictionary) -> void:
	super.update_state(state)
	if state.has("locked"): locked = bool(state.locked)
	if state.get("stacks") is Array:
		stacks.clear()
		for entry in state.stacks:
			if entry is Dictionary and not str(entry.get("item_id", "")).is_empty() and int(entry.get("amount", 0)) > 0:
				stacks.append({"item_id": StringName(str(entry.item_id)), "amount": int(entry.amount)})
		contents_changed.emit()
