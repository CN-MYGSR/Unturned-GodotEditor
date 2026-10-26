extends RefCounted
class_name SleekInventoryModel

# Game-agnostic view model consumed by SleekInventory (the reusable slot grid).
# Subclasses adapt a concrete gameplay container (the player inventory) into a
# flat list of SleekItemStack. The grid never talks to gameplay classes directly,
# which is what keeps the inventory widget reusable outside the player HUD.

signal changed

var _stacks: Array = []
var _slot_capacity := 0

func _init(capacity := 0) -> void:
	set_slot_capacity(capacity, false)

func set_slot_capacity(value: int, notify := true) -> void:
	_slot_capacity = maxi(value, 0)
	while _stacks.size() < _slot_capacity:
		_stacks.append(null)
	while _stacks.size() > _slot_capacity:
		_stacks.pop_back()
	if notify:
		changed.emit()

func get_slot_capacity() -> int:
	return _slot_capacity

func get_stack(index: int) -> SleekItemStack:
	if index < 0 or index >= _stacks.size():
		return null
	return _stacks[index] as SleekItemStack

func set_stack(index: int, stack: SleekItemStack, notify := true) -> void:
	if index < 0:
		return
	while _stacks.size() <= index:
		_stacks.append(null)
	_slot_capacity = maxi(_slot_capacity, index + 1)
	_stacks[index] = stack
	if notify:
		changed.emit()

func clear() -> void:
	for index in range(_stacks.size()):
		_stacks[index] = null
	changed.emit()

func get_used_slot_count() -> int:
	var used := 0
	for stack in _stacks:
		if stack != null and not (stack as SleekItemStack).is_empty():
			used += 1
	return used

func get_display_name() -> String:
	return "背包"

func get_display_summary() -> String:
	return "格位 %d / %d" % [get_used_slot_count(), _slot_capacity]

func notify_changed() -> void:
	changed.emit()
