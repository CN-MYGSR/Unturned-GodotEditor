extends RefCounted
class_name InventoryTransaction

var _inventory: PlayerInventory
var _snapshot: Dictionary
var _committed := false

func _init(inventory: PlayerInventory) -> void:
	_inventory = inventory
	_snapshot = inventory.get_state() if inventory != null else {}

func commit() -> void:
	_committed = true

func rollback() -> void:
	if _inventory != null and not _committed:
		_inventory.update_state(_snapshot)
		_committed = true

func is_committed() -> bool:
	return _committed
