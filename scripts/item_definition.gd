extends Resource
class_name ItemDefinition

enum UseType { NONE, CONSUMABLE, MELEE, FIREARM, THROWABLE, PLACEABLE, EQUIPMENT }

const CLOTHING_SLOTS := ["hat", "mask", "glasses", "shirt", "vest", "pants", "backpack"]

@export var item_id: StringName
@export var display_name := "Item"
@export_multiline var description := ""
@export_range(1, 999, 1) var max_stack := 1
@export var weight := 0.0
@export var use_type: UseType = UseType.NONE
@export var heal_amount := 0.0
@export var food_amount := 0.0
@export var water_amount := 0.0
@export var virus_amount := 0.0
@export var stamina_amount := 0.0
@export var damage := 0.0
@export var use_cooldown := 0.5
@export var projectile_scene: PackedScene
@export var icon: Texture2D
# Equipment/clothing compatibility (U3 ItemAsset -> Godot ItemDefinition).
@export var equipment_slot: StringName = &""
@export var clothing_scene: PackedScene
@export var animation_action: StringName = &"use"
@export var voice_event: StringName = &"use"

func is_consumable() -> bool:
	return use_type == UseType.CONSUMABLE or heal_amount > 0.0 or food_amount > 0.0 or water_amount > 0.0 or virus_amount != 0.0 or stamina_amount > 0.0

func is_equipment() -> bool:
	return not equipment_slot.is_empty()

func is_clothing() -> bool:
	return CLOTHING_SLOTS.has(String(equipment_slot))
