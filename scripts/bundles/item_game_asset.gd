extends BaseGameAsset
class_name ItemGameAsset

@export var max_stack := 1
@export var weight := 0.0
@export var rarity := "common"
@export var item_category := "misc"
@export var model_scene: PackedScene
@export var icon: Texture2D
@export var heal_amount := 0.0
@export var food_amount := 0.0
@export var water_amount := 0.0
@export var virus_amount := 0.0
@export var stamina_amount := 0.0
@export var use_type := "none"
@export var damage := 0.0
@export var use_cooldown := 0.5
@export var projectile_scene: PackedScene
# U3 ItemAsset equipment fields: slot name (hat/shirt/primary/...), clothing
# visual scene, and presentation hooks consumed by PlayerEquipment/Clothing.
@export var equipment_slot: StringName = &""
@export var attachment_kind := ""
@export var clothing_scene: PackedScene
@export var animation_action: StringName = &"use"
@export var voice_event: StringName = &"use"

func populate(data: Dictionary, source_path := "") -> void:
	super.populate(data, source_path)
	max_stack = maxi(1, int(data.get("max_stack", data.get("MaxStack", 1))))
	weight = maxf(0.0, float(data.get("weight", data.get("Weight", 0.0))))
	rarity = str(data.get("rarity", data.get("Rarity", "common"))).to_lower()
	item_category = str(data.get("category", data.get("type", "misc")))
	heal_amount = maxf(0.0, float(data.get("heal", data.get("Health", 0.0))))
	food_amount = maxf(0.0, float(data.get("food", data.get("Food", 0.0))))
	water_amount = maxf(0.0, float(data.get("water", data.get("Water", 0.0))))
	virus_amount = float(data.get("virus", data.get("Virus", 0.0)))
	stamina_amount = float(data.get("stamina", data.get("Stamina", 0.0)))
	use_type = _normalize_use_type(str(data.get("use_type", data.get("Useable", "none"))))
	damage = maxf(0.0, float(data.get("damage", data.get("Damage", data.get("Player_Damage", 0.0)))))
	use_cooldown = maxf(0.0, float(data.get("use_cooldown", data.get("UseCooldown", 0.5))))
	equipment_slot = StringName(str(data.get("equipment_slot", data.get("equip_slot", data.get("slot", data.get("EquipSlot", ""))))).to_lower())
	attachment_kind = str(data.get("attachment", data.get("attachment_kind", data.get("Attachment_Kind", "")))).to_lower()
	animation_action = StringName(str(data.get("animation", data.get("Animation", data.get("animation_action", "use")))))
	voice_event = StringName(str(data.get("voice", data.get("Voice", data.get("voice_event", "use")))))
	model_scene = _load_scene(str(data.get("scene", data.get("model", ""))), model_scene)
	clothing_scene = _load_scene(str(data.get("clothing_scene", data.get("clothing", data.get("Clothing", "")))), clothing_scene)
	projectile_scene = _load_scene(str(data.get("projectile", "")), projectile_scene)
	icon = _load_texture(str(data.get("icon", "")), icon)
	validate()

func validate() -> void:
	super.validate()
	if max_stack < 1:
		validation_errors.append("max_stack must be at least 1")
	if not use_type.is_empty() and not ["none", "consumable", "melee", "firearm", "throwable", "placeable", "equipment"].has(use_type):
		validation_errors.append("unknown use_type: " + use_type)

func get_use_type_value() -> int:
	match use_type:
		"consumable": return ItemDefinition.UseType.CONSUMABLE
		"melee": return ItemDefinition.UseType.MELEE
		"firearm": return ItemDefinition.UseType.FIREARM
		"throwable": return ItemDefinition.UseType.THROWABLE
		"placeable": return ItemDefinition.UseType.PLACEABLE
		"equipment": return ItemDefinition.UseType.EQUIPMENT
	return ItemDefinition.UseType.NONE

# Asset compatibility bridge: ItemGameAsset (parsed U3-like JSON) -> runtime
# ItemDefinition consumed by PlayerInventory/PlayerEquipment/PlayerClothing.
# Firearms and attachments become GunDefinition/AttachmentDefinition subclasses.
func to_definition() -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = asset_id if not asset_id.is_empty() else StringName(guid)
	definition.display_name = asset_name if not asset_name.is_empty() else String(definition.item_id)
	definition.description = str(source_data.get("description", source_data.get("Description", "")))
	definition.max_stack = max_stack
	definition.weight = weight
	definition.use_type = get_use_type_value()
	definition.heal_amount = heal_amount
	definition.food_amount = food_amount
	definition.water_amount = water_amount
	definition.virus_amount = virus_amount
	definition.stamina_amount = stamina_amount
	definition.damage = damage
	definition.use_cooldown = use_cooldown
	definition.projectile_scene = projectile_scene
	definition.icon = icon
	definition.equipment_slot = equipment_slot
	definition.clothing_scene = clothing_scene
	definition.animation_action = animation_action
	definition.voice_event = voice_event
	if _is_attachment_asset():
		return AttachmentDefinition.from_data(source_data, definition)
	if definition.use_type == ItemDefinition.UseType.FIREARM:
		return GunDefinition.from_data(source_data, definition)
	return definition

func _is_attachment_asset() -> bool:
	if not attachment_kind.is_empty():
		return true
	if item_category.to_lower() in ["attachment", "sight", "grip", "tactical", "barrel", "magazine"]:
		return true
	if source_data.has("attachment") or source_data.has("attachment_kind") or source_data.has("Attachment_Kind"):
		return true
	# U3 attachment assets have no Useable field; infer from their distinctive keys.
	if not source_data.has("Useable") and (source_data.has("Zoom") or source_data.has("Silenced") or source_data.has("Rangefinder") or source_data.has("Pellets") or source_data.has("Explosive")):
		return true
	return false

func _normalize_use_type(raw: String) -> String:
	match raw.to_lower():
		"consume", "consumable", "food", "water", "medical", "medicine": return "consumable"
		"gun", "firearm", "weapon": return "firearm"
		"melee", "sword", "axe", "blade": return "melee"
		"throwable": return "throwable"
		"barricade", "structure", "placeable": return "placeable"
		"clothing", "equipment", "wearable": return "equipment"
	return raw.to_lower()

func _load_scene(path: String, fallback: PackedScene) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		return fallback
	return load(path) as PackedScene

func _load_texture(path: String, fallback: Texture2D) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return fallback
	return load(path) as Texture2D
