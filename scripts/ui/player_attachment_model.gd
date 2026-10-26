extends SleekInventoryModel
class_name PlayerAttachmentModel

# U3 Inventory attachment view for the equipped firearm: sight/grip/tactical/
# barrel/magazine slots. The model reads the active UseableGun and reuses the
# reusable SleekInventory grid.

const KIND_ORDER := [&"sight", &"grip", &"tactical", &"barrel", &"magazine"]

var equipment: PlayerEquipment

func _init(source: PlayerEquipment = null) -> void:
	super._init(KIND_ORDER.size())
	bind(source)

func bind(source: PlayerEquipment) -> void:
	if equipment != null and is_instance_valid(equipment):
		if equipment.equipment_changed.is_connected(refresh):
			equipment.equipment_changed.disconnect(refresh)
		if equipment.weapon_changed.is_connected(_on_weapon_changed):
			equipment.weapon_changed.disconnect(_on_weapon_changed)
		if equipment.attachment_changed.is_connected(_on_attachment_changed):
			equipment.attachment_changed.disconnect(_on_attachment_changed)
		if equipment.weapon_state_changed.is_connected(_on_weapon_state_changed):
			equipment.weapon_state_changed.disconnect(_on_weapon_state_changed)
	equipment = source
	if equipment != null and is_instance_valid(equipment):
		equipment.equipment_changed.connect(refresh)
		equipment.weapon_changed.connect(_on_weapon_changed)
		equipment.attachment_changed.connect(_on_attachment_changed)
		equipment.weapon_state_changed.connect(_on_weapon_state_changed)
	refresh()

func refresh() -> void:
	set_slot_capacity(KIND_ORDER.size(), false)
	var gun := equipment.get_active_gun() if equipment != null else null
	for index in KIND_ORDER.size():
		_stacks[index] = _stack_for(StringName(KIND_ORDER[index]), gun)
	changed.emit()

func kind_for_index(index: int) -> StringName:
	if index < 0 or index >= KIND_ORDER.size(): return &""
	return StringName(KIND_ORDER[index])

func index_of_kind(kind: StringName) -> int:
	return KIND_ORDER.find(kind)

func get_display_name() -> String:
	return "附件"

func get_display_summary() -> String:
	if equipment == null or equipment.get_active_gun() == null:
		return "未装备枪械"
	var gun := equipment.get_active_gun()
	return "弹药 %d / %d  ·  %s" % [gun.get_ammo(), gun.get_capacity(), str(gun.get_firemode_name())]

func _stack_for(kind: StringName, gun: UseableGun) -> SleekItemStack:
	if gun == null: return null
	var attachment_id := gun.get_attachment(kind)
	if attachment_id.is_empty(): return null
	var inventory: PlayerInventory = gun.inventory
	var definition: AttachmentDefinition = null
	if inventory != null:
		definition = inventory.definitions.get(attachment_id) as AttachmentDefinition
	var stack := SleekItemStack.new(attachment_id, definition.display_name if definition != null else str(attachment_id), 1)
	if definition != null:
		stack.icon = definition.icon
		stack.description = definition.description
	return stack

func _on_weapon_changed(_item_id: StringName) -> void:
	refresh()

func _on_attachment_changed(_kind: StringName, _attachment_id: StringName) -> void:
	refresh()

func _on_weapon_state_changed(_item_id: StringName, _state: Dictionary) -> void:
	refresh()


