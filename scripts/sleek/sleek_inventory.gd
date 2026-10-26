extends GridContainer
class_name SleekInventory

# Reusable inventory grid: the extracted, HUD-independent version of the slot
# wall in Unturned/UI/Player/PlayerDashboardInventoryUI.cs.
# It knows nothing about the gameplay inventory/life classes - feed it any
# SleekInventoryModel. The same control is reused by the inventory screen and
# (through SleekHotbar) by the HUD hotbar.

signal slot_pressed(slot_index: int)
signal slot_activated(slot_index: int)
signal slot_secondary(slot_index: int, screen_position: Vector2)
signal selection_changed(slot_index: int)

# Uses GridContainer's native `columns` property (a script member with the same
# name would shadow the native one and fail to compile).
@export var slot_size := Vector2(76, 76)
# When > 0 the grid shows a fixed number of slots instead of the model capacity
# (used by SleekHotbar so a 24-slot inventory still renders 10 hotbar keys).
@export var slot_count_override := 0
@export var hotkeys_visible := false

var model: SleekInventoryModel = null
var slots: Array = []
var selected_index := -1
var display_mode := SleekSlot.DisplayMode.INVENTORY

func _init() -> void:
	columns = 6

func _ready() -> void:
	columns = maxi(columns, 1)
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	_sync_slots()
	_update_slots()

func bind_model(new_model: SleekInventoryModel) -> void:
	if model != null and model.changed.is_connected(refresh):
		model.changed.disconnect(refresh)
	model = new_model
	if model != null and not model.changed.is_connected(refresh):
		model.changed.connect(refresh)
	refresh()

func refresh() -> void:
	_sync_slots()
	_update_slots()

func get_slot_count() -> int:
	if slot_count_override > 0:
		return slot_count_override
	if model == null:
		return 0
	return model.get_slot_capacity()

func get_slot(index: int) -> SleekSlot:
	if index < 0 or index >= slots.size():
		return null
	return slots[index] as SleekSlot

func get_selected_index() -> int:
	return selected_index

func select(index: int) -> void:
	var next_index := index if (index >= 0 and index < slots.size()) else -1
	if next_index == selected_index:
		return
	selected_index = next_index
	for slot_index in range(slots.size()):
		var slot := slots[slot_index] as SleekSlot
		slot.set_selected(slot_index == selected_index)
	selection_changed.emit(selected_index)

func _sync_slots() -> void:
	var count := get_slot_count()
	while slots.size() < count:
		var slot := SleekSlot.new()
		slot.custom_minimum_size = slot_size
		slot.set_slot_index(slots.size())
		slot.set_display_mode(display_mode)
		slot.slot_pressed.connect(_on_slot_pressed)
		slot.slot_activated.connect(_on_slot_activated)
		slot.slot_secondary.connect(_on_slot_secondary)
		add_child(slot)
		slots.append(slot)
	while slots.size() > count:
		var removed := slots.pop_back() as SleekSlot
		remove_child(removed)
		removed.queue_free()
	if selected_index >= slots.size():
		selected_index = -1

func _update_slots() -> void:
	for index in range(slots.size()):
		var slot := slots[index] as SleekSlot
		slot.set_stack(model.get_stack(index) if model != null else null)
		slot.set_selected(index == selected_index)
		if display_mode == SleekSlot.DisplayMode.HOTBAR:
			slot.set_hotkey_text(_format_hotkey(index))
		else:
			slot.set_hotkey_text("")

func _format_hotkey(index: int) -> String:
	if not hotkeys_visible:
		return ""
	if index < 9:
		return str(index + 1)
	return "0"

func _on_slot_pressed(index: int) -> void:
	select(index)
	slot_pressed.emit(index)

func _on_slot_activated(index: int) -> void:
	slot_activated.emit(index)

func _on_slot_secondary(index: int, screen_position: Vector2) -> void:
	slot_secondary.emit(index, screen_position)


