extends SleekInventoryModel
class_name PlayerEquipmentModel

# U3 Inventory equipment-slot view: the dashboard inventory shows the equipped
# weapon/melee and clothing slots. Reuses the same SleekInventory grid widget as
# the backpack, so equipment slots are just another model adapter.

const SLOT_ORDER := [&"primary", &"secondary", &"melee", &"hat", &"mask", &"glasses", &"shirt", &"vest", &"pants", &"backpack"]

var equipment: PlayerEquipment

func _init(source: PlayerEquipment = null) -> void:
	super._init(SLOT_ORDER.size())
	bind(source)

func bind(source: PlayerEquipment) -> void:
	if equipment != null and is_instance_valid(equipment) and equipment.equipment_changed.is_connected(refresh):
		equipment.equipment_changed.disconnect(refresh)
	equipment = source
	if equipment != null and is_instance_valid(equipment) and not equipment.equipment_changed.is_connected(refresh):
		equipment.equipment_changed.connect(refresh)
	refresh()

func refresh() -> void:
	set_slot_capacity(SLOT_ORDER.size(), false)
	for index in SLOT_ORDER.size():
		_stacks[index] = _stack_for(StringName(SLOT_ORDER[index]))
	changed.emit()

func slot_for_index(index: int) -> StringName:
	if index < 0 or index >= SLOT_ORDER.size(): return &""
	return StringName(SLOT_ORDER[index])

func index_of_slot(slot: StringName) -> int:
	return SLOT_ORDER.find(slot)

func get_display_name() -> String:
	return "装备"

func get_display_summary() -> String:
	var equipped := 0
	for stack in _stacks:
		if stack != null: equipped += 1
	return "已装备 %d / %d" % [equipped, SLOT_ORDER.size()]

func _stack_for(slot: StringName) -> SleekItemStack:
	if equipment == null: return null
	var item_id := equipment.get_item(slot)
	if item_id.is_empty(): return null
	var inventory: PlayerInventory = equipment.inventory
	var definition: ItemDefinition = inventory.definitions.get(item_id) as ItemDefinition if inventory != null else null
	var stack := SleekItemStack.new(item_id, definition.display_name if definition != null else str(item_id), 1)
	if definition != null:
		stack.icon = definition.icon
		stack.description = definition.description
	return stack


