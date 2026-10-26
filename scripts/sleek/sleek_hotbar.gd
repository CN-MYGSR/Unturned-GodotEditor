extends "res://scripts/sleek/sleek_inventory.gd"
class_name SleekHotbar

# Reuses the reusable SleekInventory grid for the HUD hotbar.
# Port of the hotbar container in Unturned/UI/Player/PlayerLifeUI.cs built from
# SleekHotbarEntry instances (10 numeric hotkeys).

const HOTBAR_KEY_COUNT := 10

func _init() -> void:
	columns = HOTBAR_KEY_COUNT
	slot_size = Vector2(56, 56)
	display_mode = SleekSlot.DisplayMode.HOTBAR
	hotkeys_visible = true
	slot_count_override = HOTBAR_KEY_COUNT
