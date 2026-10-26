extends SleekInventoryModel
class_name PlayerInventoryModel

# Adapter between the gameplay container (PlayerInventory) and the reusable
# SleekInventory grid. This is the ONLY place that knows both sides, which keeps
# scripts/sleek/* free of gameplay types and keeps the inventory widget usable
# for containers, loot panels, vendors, etc.

var inventory: PlayerInventory

func _init(new_inventory: PlayerInventory = null) -> void:
	super._init()
	bind(new_inventory)

func bind(new_inventory: PlayerInventory) -> void:
	if inventory != null and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = new_inventory
	if inventory != null and not inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.connect(_on_inventory_changed)
	_rebuild()

func _on_inventory_changed() -> void:
	_rebuild()

func _rebuild() -> void:
	if inventory == null:
		set_slot_capacity(0, false)
		for index in range(_stacks.size()):
			_stacks[index] = null
		changed.emit()
		return
	set_slot_capacity(inventory.slot_capacity, false)
	for index in range(_stacks.size()):
		if index < inventory.slots.size():
			_stacks[index] = _make_stack(inventory.slots[index])
		else:
			_stacks[index] = null
	changed.emit()

func _make_stack(slot_data: Dictionary) -> SleekItemStack:
	var stack := SleekItemStack.new()
	var item_id: StringName = slot_data.get("item_id", &"")
	var definition: ItemDefinition = inventory.definitions.get(item_id)
	stack.item_id = item_id
	stack.amount = int(slot_data.get("amount", 0))
	if definition != null:
		stack.display_name = definition.display_name
		stack.description = definition.description
		stack.icon = definition.icon
	else:
		stack.display_name = str(item_id)
	return stack

func get_display_name() -> String:
	return "幸存者背包"

func get_display_summary() -> String:
	if inventory == null:
		return super.get_display_summary()
	return "物品 %d / %d     重量 %.1f / %.1f kg" % [inventory.slots.size(), inventory.slot_capacity, inventory.current_weight(), inventory.max_weight]
