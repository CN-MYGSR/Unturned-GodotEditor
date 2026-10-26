extends RefCounted
class_name SleekItemStack

# Game-agnostic item data shown by the reusable Sleek slot/grid widgets.
# Deliberately does NOT know about the gameplay item/inventory types: the UI layer
# adapts gameplay data into this DTO (see scripts/ui/player_inventory_model.gd).

var item_id: StringName = &""
var display_name := ""
var description := ""
var amount := 0
var icon: Texture2D = null
# -1 means "no quality". 0.0 .. 1.0 mirrors Item.quality / 100 from U3.
var quality := -1.0
var hotkey := ""

func _init(new_item_id := &"", new_display_name := "", new_amount := 0) -> void:
	item_id = new_item_id
	display_name = new_display_name
	amount = new_amount

func is_empty() -> bool:
	return item_id.is_empty() or amount <= 0

func has_quality() -> bool:
	return quality >= 0.0

func duplicate_stack() -> SleekItemStack:
	var copy := SleekItemStack.new(item_id, display_name, amount)
	copy.description = description
	copy.icon = icon
	copy.quality = quality
	copy.hotkey = hotkey
	return copy
