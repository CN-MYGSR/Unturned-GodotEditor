extends Node
class_name PlayerInventory

signal changed
signal item_added(item_id: StringName, amount: int)
signal item_removed(item_id: StringName, amount: int)
signal slot_changed(index: int)
signal item_used(item_id: StringName)
signal active_slot_changed(index: int)

@export_range(1, 128, 1) var slot_capacity := 24
@export var max_weight := 40.0
@export var item_definitions: Array[ItemDefinition] = []
@export_range(0, 9, 1) var hotbar_capacity := 6

var slots: Array[Dictionary] = []
var definitions: Dictionary = {}
var hotbar: Array[int] = []
var active_slot := -1

func _ready() -> void:
	for definition in item_definitions: register_definition(definition)
	if hotbar.is_empty():
		for index in mini(hotbar_capacity, slot_capacity): hotbar.append(index)

func register_definition(definition: ItemDefinition) -> void:
	if definition == null or definition.item_id.is_empty(): return
	definitions[definition.item_id] = definition

func add_item(item_id: StringName, amount: int = 1, state: Dictionary = {}) -> int:
	if amount <= 0 or not definitions.has(item_id): return amount
	var definition: ItemDefinition = definitions[item_id]
	var allowed := amount
	if definition.weight > 0.0:
		allowed = mini(amount, maxi(0, int(floor((max_weight - current_weight()) / definition.weight))))
	var remaining := allowed
	for index in slots.size():
		var slot: Dictionary = slots[index]
		if slot.item_id != item_id or slot.amount >= definition.max_stack or slot.get("state", {}) != state: continue
		var moved := mini(remaining, definition.max_stack - int(slot.amount))
		slot.amount += moved
		slots[index] = slot
		remaining -= moved
		slot_changed.emit(index)
		if remaining == 0: break
	while remaining > 0 and slots.size() < slot_capacity:
		var moved := mini(remaining, definition.max_stack)
		slots.append({"item_id": item_id, "amount": moved, "state": state.duplicate(true)})
		remaining -= moved
	var added := allowed - remaining
	if added > 0:
		item_added.emit(item_id, added)
		changed.emit()
	return amount - added

func remove_item(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count_item(item_id) < amount: return false
	var remaining := amount
	for index in range(slots.size() - 1, -1, -1):
		if slots[index].item_id != item_id: continue
		var removed := mini(remaining, int(slots[index].amount))
		slots[index].amount -= removed
		remaining -= removed
		if slots[index].amount <= 0:
			slots.remove_at(index)
			_reindex_after_removal(index)
		else:
			slot_changed.emit(index)
		if remaining == 0: break
	item_removed.emit(item_id, amount)
	changed.emit()
	return true

func remove_slot_amount(index: int, amount: int) -> Dictionary:
	if index < 0 or index >= slots.size() or amount <= 0: return {}
	var slot: Dictionary = slots[index]
	var removed := mini(amount, int(slot.amount))
	var result := {"item_id": slot.item_id, "amount": removed, "state": slot.get("state", {}).duplicate(true)}
	slot.amount -= removed
	if slot.amount <= 0:
		slots.remove_at(index)
		_reindex_after_removal(index)
	else:
		slots[index] = slot
		slot_changed.emit(index)
	item_removed.emit(result.item_id, removed)
	changed.emit()
	return result

func count_item(item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if slot.item_id == item_id: total += int(slot.amount)
	return total

func current_weight() -> float:
	var total := 0.0
	for slot in slots:
		var definition: ItemDefinition = definitions.get(slot.item_id)
		if definition != null: total += definition.weight * int(slot.amount)
	return total

func can_add_item(item_id: StringName, amount: int = 1) -> bool:
	return amount > 0 and add_item_preview(item_id, amount) == 0

func add_item_preview(item_id: StringName, amount: int = 1) -> int:
	if amount <= 0 or not definitions.has(item_id): return amount
	var definition: ItemDefinition = definitions[item_id]
	var weight_capacity := amount
	if definition.weight > 0.0:
		weight_capacity = maxi(0, int(floor((max_weight - current_weight()) / definition.weight)))
	var stack_capacity := maxi(0, slot_capacity - slots.size()) * definition.max_stack
	stack_capacity += _existing_stack_space(item_id)
	return amount - mini(amount, mini(weight_capacity, stack_capacity))

func swap_slots(first: int, second: int) -> bool:
	if first < 0 or second < 0 or first >= slots.size() or second >= slots.size() or first == second: return false
	var value := slots[first]
	slots[first] = slots[second]
	slots[second] = value
	slot_changed.emit(first)
	slot_changed.emit(second)
	changed.emit()
	return true

func split_stack(index: int, amount: int) -> bool:
	if index < 0 or index >= slots.size() or slots.size() >= slot_capacity: return false
	var source: Dictionary = slots[index]
	if amount <= 0 or amount >= int(source.amount): return false
	source.amount -= amount
	slots[index] = source
	var split := source.duplicate(true)
	split.amount = amount
	slots.insert(index + 1, split)
	_reindex_hotbar_insert(index + 1)
	slot_changed.emit(index)
	slot_changed.emit(index + 1)
	changed.emit()
	return true

func set_active_slot(index: int) -> bool:
	if index < -1 or index >= slots.size(): return false
	if active_slot == index: return true
	active_slot = index
	active_slot_changed.emit(index)
	return true

func use_active_item(life: PlayerLife) -> bool:
	if active_slot < 0 or active_slot >= slots.size(): return false
	var id: StringName = slots[active_slot].item_id
	if not use_item(id, life): return false
	item_used.emit(id)
	return true

func use_item(item_id: StringName, actor: Node) -> bool:
	if actor == null or count_item(item_id) < 1: return false
	var definition: ItemDefinition = definitions.get(item_id)
	if definition == null: return false
	var handler := _get_useable(definition)
	if handler == null or not handler.can_use(actor, definition): return false
	if not handler.use_item(actor, definition): return false
	if handler.consumes_item and not remove_item(item_id, 1): return false
	item_used.emit(item_id)
	return true

# U3 Inventory equipment/attachment accessors. Gun state (ammo/attachments/
# firemode) lives in the inventory slot's `state` dictionary, mirroring U3's
# per-item byte[] state.
func get_useable(item_id: StringName) -> UseableItem:
	var definition: ItemDefinition = definitions.get(item_id)
	if definition == null: return null
	return _get_useable(definition)

func get_slot_state(index: int) -> Dictionary:
	if index < 0 or index >= slots.size(): return {}
	return (slots[index].get("state", {}) as Dictionary).duplicate(true)

func set_slot_state(index: int, state: Dictionary) -> bool:
	if index < 0 or index >= slots.size(): return false
	var slot: Dictionary = slots[index]
	if slot.get("state", {}) == state: return true
	slot["state"] = state.duplicate(true)
	slots[index] = slot
	slot_changed.emit(index)
	changed.emit()
	return true

func find_slot_index(item_id: StringName) -> int:
	for index in slots.size():
		if slots[index].item_id == item_id: return index
	return -1

func find_slot_with_state(item_id: StringName, state: Dictionary) -> int:
	for index in slots.size():
		if slots[index].item_id == item_id and slots[index].get("state", {}) == state: return index
	return -1

func take_item_at(index: int, amount := 1) -> Dictionary:
	if index < 0 or index >= slots.size() or amount <= 0: return {}
	var slot: Dictionary = slots[index]
	var taken := mini(amount, int(slot.amount))
	if taken <= 0: return {}
	var result := {"item_id": StringName(slot.item_id), "amount": taken, "state": (slot.get("state", {}) as Dictionary).duplicate(true)}
	slot.amount = int(slot.amount) - taken
	if int(slot.amount) <= 0:
		slots.remove_at(index)
		_reindex_after_removal(index)
	else:
		slots[index] = slot
		slot_changed.emit(index)
	item_removed.emit(result.item_id, taken)
	changed.emit()
	return result

func count_items_with_state(item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if slot.item_id == item_id: total += int(slot.amount)
	return total

func _get_useable(definition: ItemDefinition) -> UseableItem:
	var useable_type := definition.use_type
	if useable_type == ItemDefinition.UseType.NONE and definition.is_consumable():
		useable_type = ItemDefinition.UseType.CONSUMABLE
	var node_name := "Useable_%s" % str(definition.item_id).validate_node_name()
	var handler := get_node_or_null(node_name) as UseableItem
	if handler != null: return handler
	match useable_type:
		ItemDefinition.UseType.CONSUMABLE: handler = UseableConsumable.new()
		ItemDefinition.UseType.MELEE: handler = UseableMelee.new()
		ItemDefinition.UseType.FIREARM: handler = UseableGun.new()
		ItemDefinition.UseType.THROWABLE: handler = UseableThrowable.new()
		_: return null
	handler.name = node_name
	add_child(handler)
	return handler

func get_state() -> Dictionary:
	return {"slots": slots.duplicate(true), "hotbar": hotbar.duplicate(), "active_slot": active_slot}

func update_state(state: Dictionary) -> void:
	if state.get("slots") is Array:
		slots.clear()
		for entry in state.slots:
			if entry is Dictionary and definitions.has(StringName(entry.get("item_id", ""))) and int(entry.get("amount", 0)) > 0:
				var definition: ItemDefinition = definitions[StringName(entry.item_id)]
				slots.append({"item_id": StringName(entry.item_id), "amount": mini(int(entry.amount), definition.max_stack), "state": entry.get("state", {}).duplicate(true)})
				if slots.size() >= slot_capacity: break
	if state.get("hotbar") is Array:
		hotbar.clear()
		for index in state.hotbar:
			if int(index) >= 0 and int(index) < slot_capacity: hotbar.append(int(index))
	active_slot = clampi(int(state.get("active_slot", -1)), -1, slots.size() - 1)
	changed.emit()
	for index in slots.size(): slot_changed.emit(index)
	active_slot_changed.emit(active_slot)

func _existing_stack_space(item_id: StringName) -> int:
	var space := 0
	for slot in slots:
		if slot.item_id == item_id and slot.get("state", {}).is_empty():
			space += maxi(0, int(definitions[item_id].max_stack) - int(slot.amount))
	return space

func _reindex_after_removal(removed_index: int) -> void:
	for index in hotbar.size():
		if hotbar[index] == removed_index: hotbar[index] = -1
		elif hotbar[index] > removed_index: hotbar[index] -= 1
	if active_slot == removed_index: set_active_slot(-1)
	elif active_slot > removed_index: active_slot -= 1

func _reindex_hotbar_insert(inserted_index: int) -> void:
	for index in hotbar.size():
		if hotbar[index] >= inserted_index: hotbar[index] += 1

