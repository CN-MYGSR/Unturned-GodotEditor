extends ItemDefinition
class_name AttachmentDefinition

# Godot-side port of the U3 attachment assets:
#   ItemSightAsset / ItemGripAsset / ItemTacticalAsset /
#   ItemBarrelAsset / ItemMagazineAsset (all ItemCaliberAsset).
# One definition class with a kind enum keeps inventory/attachment code uniform
# while preserving the U3 fields that actually affect single-player gameplay.

enum Kind { SIGHT, GRIP, TACTICAL, BARREL, MAGAZINE }

@export var kind := Kind.SIGHT
@export var caliber := 0
# sight
@export var zoom := 1.0
@export var vision := ""
@export var is_holographic := false
# tactical
@export var is_laser := false
@export var is_light := false
@export var is_rangefinder := false
# barrel
@export var is_silenced := false
@export var is_braked := false
@export var gunshot_rolloff_multiplier := 1.0
# magazine
@export var capacity := 0
@export var pellets := 1
@export var range_override := 0.0
@export var explosive := false
# generic caliber-asset modifiers
@export var recoil_multiplier := 1.0
@export var spread_multiplier := 1.0
@export var aim_duration_multiplier := 1.0
@export var ballistic_damage_multiplier := 1.0
@export var firerate_offset := 0

static func from_data(data: Dictionary, base: ItemDefinition) -> AttachmentDefinition:
	var attachment := AttachmentDefinition.new()
	GunDefinition._copy_base(base, attachment)
	attachment.kind = detect_kind(data)
	attachment.caliber = GunDefinition._int(data, ["Caliber", "caliber"], 0)
	attachment.zoom = maxf(1.0, GunDefinition._number(data, ["Zoom", "zoom"], 1.0))
	attachment.vision = GunDefinition._string(data, ["Vision", "vision"])
	attachment.is_holographic = GunDefinition._flag(data, ["Holographic", "is_holographic"])
	attachment.is_laser = GunDefinition._flag(data, ["Laser", "is_laser"])
	attachment.is_light = GunDefinition._flag(data, ["Light", "is_light"])
	attachment.is_rangefinder = GunDefinition._flag(data, ["Rangefinder", "is_rangefinder"])
	attachment.is_silenced = GunDefinition._flag(data, ["Silenced", "is_silenced"])
	attachment.is_braked = GunDefinition._flag(data, ["Braked", "is_braked"])
	attachment.gunshot_rolloff_multiplier = GunDefinition._number(data, ["Gunshot_Rolloff_Distance_Multiplier", "gunshot_rolloff_multiplier"], 0.5 if attachment.is_silenced else 1.0)
	attachment.capacity = maxi(0, GunDefinition._int(data, ["Amount", "MaxAmount", "Ammo_Max", "capacity"], 0))
	attachment.pellets = maxi(1, GunDefinition._int(data, ["Pellets", "pellets"], 1))
	attachment.range_override = GunDefinition._number(data, ["Range", "range_override"], 0.0)
	attachment.explosive = GunDefinition._flag(data, ["Explosive", "explosive"])
	attachment.recoil_multiplier = GunDefinition._number(data, ["Recoil_Multiplier", "recoil_multiplier"], 1.0)
	attachment.spread_multiplier = GunDefinition._number(data, ["Spread_Multiplier", "spread_multiplier"], 1.0)
	attachment.aim_duration_multiplier = GunDefinition._number(data, ["Aim_Duration_Multiplier", "aim_duration_multiplier"], 1.0)
	attachment.ballistic_damage_multiplier = GunDefinition._number(data, ["Ballistic_Damage_Multiplier", "ballistic_damage_multiplier"], 1.0)
	attachment.firerate_offset = GunDefinition._int(data, ["Firerate_Offset", "firerate_offset"], 0)
	if attachment.is_empty_meaning():
		attachment.use_type = ItemDefinition.UseType.NONE
	return attachment

static func detect_kind(data: Dictionary) -> Kind:
	var explicit := GunDefinition._string(data, ["attachment", "attachment_kind", "Attachment_Kind", "Attachment"]).to_lower()
	match explicit:
		"sight", "optic": return Kind.SIGHT
		"grip": return Kind.GRIP
		"tactical", "laser", "light": return Kind.TACTICAL
		"barrel": return Kind.BARREL
		"magazine", "mag": return Kind.MAGAZINE
	if data.has("Zoom") or data.has("Vision") or data.has("Holographic"):
		return Kind.SIGHT
	if data.has("Grip"):
		return Kind.GRIP
	if data.has("Laser") or data.has("Light") or data.has("Rangefinder") or data.has("Tactical"):
		return Kind.TACTICAL
	if data.has("Silenced") or data.has("Braked") or data.has("Barrel"):
		return Kind.BARREL
	return Kind.MAGAZINE

func kind_name() -> StringName:
	match kind:
		Kind.SIGHT: return &"sight"
		Kind.GRIP: return &"grip"
		Kind.TACTICAL: return &"tactical"
		Kind.BARREL: return &"barrel"
		Kind.MAGAZINE: return &"magazine"
	return &""

func capacity_or(default_value: int) -> int:
	return capacity if capacity > 0 else default_value

func is_empty_meaning() -> bool:
	return kind == Kind.MAGAZINE and capacity <= 0 and not explosive
