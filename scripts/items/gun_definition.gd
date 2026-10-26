extends ItemDefinition
class_name GunDefinition

# Godot-side port of U3 ItemGunAsset (Bundles/ItemGunAsset.cs) plus the shared
# weapon fields from ItemWeaponAsset/ItemCaliberAsset. Values parsed by
# from_data() keep U3 dat/JSON field names as aliases so gun packs can be
# migrated without rewriting their numbers.

enum FireMode { SAFETY, SEMI, AUTO, BURST }

@export var range := 100.0
@export var ammo_per_shot := 1
@export var magazine_capacity := 30
@export var default_magazine: StringName = &""
@export var firerate := 10
@export var fire_interval := -1.0
@export var reload_time := 2.0
@export var hammer_time := 0.35
@export var has_safety := false
@export var has_semi := true
@export var has_auto := false
@export var has_burst := false
@export var bursts := 3
@export var default_fire_mode := FireMode.SEMI
@export var spread_angle_degrees := 1.5
@export var spread_hip := -1.0
@export var spread_aim := 0.5
@export var spread_sprint := 1.25
@export var spread_crouch := 0.85
@export var spread_prone := 0.7
@export var spread_midair := 1.5
@export var recoil_min := Vector2(0.2, 0.1)
@export var recoil_max := Vector2(0.8, 0.4)
@export var recoil_crouch := 0.85
@export var recoil_prone := 0.7
@export var recoil_sprint := 1.25
@export var recoil_midair := 1.0
@export var recoil_recover := Vector2(4.0, 4.0)
@export var aiming_recoil_multiplier := 0.7
@export var muzzle_velocity := 100.0
@export var bullet_gravity_multiplier := 4.0
@export var pellets := 1
@export var damage_falloff_range := 1.0
@export var damage_falloff_max_range := 1.0
@export var damage_falloff_multiplier := 1.0
@export var infinite_ammo := false
@export var quality_damage_scaling := true
@export var durability := 0.0
@export var wear := 0.0
@export var alert_radius := 48.0
@export var caliber := 0
@export var has_sight := false
@export var has_grip := false
@export var has_tactical := false
@export var has_barrel := false
@export var default_sight: StringName = &""
@export var default_grip: StringName = &""
@export var default_tactical: StringName = &""
@export var default_barrel: StringName = &""

static func from_data(data: Dictionary, base: ItemDefinition) -> GunDefinition:
	var gun := GunDefinition.new()
	_copy_base(base, gun)
	gun.use_type = ItemDefinition.UseType.FIREARM
	if gun.equipment_slot.is_empty():
		gun.equipment_slot = &"primary"
	if gun.animation_action == &"use":
		gun.animation_action = &"shoot"
	gun.range = _number(data, ["Range", "range"], 100.0)
	gun.damage = _number(data, ["Player_Damage", "Damage", "damage", "PlayerDamage"], 30.0)
	gun.ammo_per_shot = maxi(1, _int(data, ["Ammo_Per_Shot", "ammo_per_shot"], 1))
	gun.magazine_capacity = maxi(0, _int(data, ["Magazine_Capacity", "magazine_capacity", "Ammo_Max", "AmmoMax"], 30))
	gun.default_magazine = StringName(_string(data, ["Magazine", "Default_Magazine", "default_magazine"]))
	gun.firerate = _int(data, ["Firerate", "Fire_Rate", "firerate"], 10)
	gun.fire_interval = _number(data, ["Fire_Interval", "fire_interval"], -1.0)
	gun.reload_time = maxf(0.0, _number(data, ["Reload_Time", "reload_time"], 2.0))
	gun.hammer_time = maxf(0.0, _number(data, ["Hammer_Time", "hammer_time"], 0.35))
	gun.has_safety = _flag(data, ["Safety", "safety"])
	gun.has_semi = _flag(data, ["Semi", "semi"], true)
	gun.has_auto = _flag(data, ["Auto", "auto"])
	gun.has_burst = _flag(data, ["Burst", "burst"]) or _int(data, ["Bursts", "bursts"], 0) > 0
	gun.bursts = maxi(3, _int(data, ["Bursts", "bursts"], 3))
	gun.spread_hip = _number(data, ["Spread_Hip", "spread_hip"], -1.0)
	gun.spread_angle_degrees = maxf(0.0, _number(data, ["Spread_Angle_Degrees", "spread_angle_degrees"], 1.5))
	gun.spread_aim = maxf(0.0, _number(data, ["Spread_Aim", "spreadAim", "spread_aim"], 0.5))
	gun.spread_sprint = _number(data, ["Spread_Sprint", "spread_sprint"], 1.25)
	gun.spread_crouch = _number(data, ["Spread_Crouch", "spread_crouch"], 0.85)
	gun.spread_prone = _number(data, ["Spread_Prone", "spread_prone"], 0.7)
	gun.spread_midair = _number(data, ["Spread_Midair", "spread_midair"], 1.5)
	gun.recoil_min = Vector2(_number(data, ["Recoil_Min_X", "recoil_min_x"], 0.2), _number(data, ["Recoil_Min_Y", "recoil_min_y"], 0.1))
	gun.recoil_max = Vector2(_number(data, ["Recoil_Max_X", "recoil_max_x"], 0.8), _number(data, ["Recoil_Max_Y", "recoil_max_y"], 0.4))
	gun.aiming_recoil_multiplier = _number(data, ["Aiming_Recoil_Multiplier", "aiming_recoil_multiplier"], 0.7)
	gun.recoil_crouch = _number(data, ["Recoil_Crouch", "recoil_crouch"], 0.85)
	gun.recoil_prone = _number(data, ["Recoil_Prone", "recoil_prone"], 0.7)
	gun.recoil_sprint = _number(data, ["Recoil_Sprint", "recoil_sprint"], 1.25)
	gun.recoil_midair = _number(data, ["Recoil_Midair", "recoil_midair"], 1.0)
	gun.recoil_recover = Vector2(_number(data, ["Recover_X", "recover_x"], 4.0), _number(data, ["Recover_Y", "recover_y"], 4.0))
	gun.muzzle_velocity = maxf(1.0, _number(data, ["Muzzle_Velocity", "muzzle_velocity"], 100.0))
	gun.bullet_gravity_multiplier = _number(data, ["Bullet_Gravity_Multiplier", "bullet_gravity_multiplier"], 4.0)
	gun.pellets = maxi(1, _int(data, ["Pellets", "pellets"], 1))
	gun.damage_falloff_range = _number(data, ["Damage_Falloff_Range", "damage_falloff_range"], 1.0)
	gun.damage_falloff_max_range = _number(data, ["Damage_Falloff_Max_Range", "damage_falloff_max_range"], 1.0)
	gun.damage_falloff_multiplier = _number(data, ["Damage_Falloff_Multiplier", "damage_falloff_multiplier"], 1.0)
	gun.infinite_ammo = _flag(data, ["Infinite_Ammo", "infinite_ammo"])
	gun.durability = _number(data, ["Durability", "durability"], 0.0)
	gun.wear = _number(data, ["Wear", "wear"], 0.0)
	gun.alert_radius = _number(data, ["Alert_Radius", "alert_radius"], 48.0)
	gun.caliber = _int(data, ["Caliber", "caliber"], 0)
	gun.has_sight = _flag(data, ["Hook_Sight", "has_sight"]) or not String(_string(data, ["Sight", "sight"])).is_empty()
	gun.has_grip = _flag(data, ["Hook_Grip", "has_grip"]) or not String(_string(data, ["Grip", "grip"])).is_empty()
	gun.has_tactical = _flag(data, ["Hook_Tactical", "has_tactical"]) or not String(_string(data, ["Tactical", "tactical"])).is_empty()
	gun.has_barrel = _flag(data, ["Hook_Barrel", "has_barrel"]) or not String(_string(data, ["Barrel", "barrel"])).is_empty()
	gun.default_sight = StringName(_string(data, ["Sight", "sight"]))
	gun.default_grip = StringName(_string(data, ["Grip", "grip"]))
	gun.default_tactical = StringName(_string(data, ["Tactical", "tactical"]))
	gun.default_barrel = StringName(_string(data, ["Barrel", "barrel"]))
	var action := _string(data, ["Action", "action"]).to_lower()
	if action == "auto":
		gun.has_auto = true
	elif action == "burst":
		gun.has_burst = true
	elif action == "safety":
		gun.has_safety = true
	gun.default_fire_mode = _default_mode(gun)
	return gun

static func _default_mode(gun: GunDefinition) -> FireMode:
	if gun.has_auto: return FireMode.AUTO
	if gun.has_semi: return FireMode.SEMI
	if gun.has_burst: return FireMode.BURST
	return FireMode.SAFETY

func fire_interval_seconds() -> float:
	if fire_interval > 0.0:
		return fire_interval
	return 50.0 / float(maxi(1, firerate + 1))

func allowed_fire_modes() -> Array:
	var modes: Array = []
	if has_safety: modes.append(FireMode.SAFETY)
	if has_semi: modes.append(FireMode.SEMI)
	if has_burst: modes.append(FireMode.BURST)
	if has_auto: modes.append(FireMode.AUTO)
	if modes.is_empty(): modes.append(FireMode.SEMI)
	return modes

func get_base_spread_radians() -> float:
	if spread_hip > 0.0:
		return atan(spread_hip)
	return deg_to_rad(maxf(0.0, spread_angle_degrees))

static func _copy_base(source: ItemDefinition, target: ItemDefinition) -> void:
	target.item_id = source.item_id
	target.display_name = source.display_name
	target.description = source.description
	target.max_stack = source.max_stack
	target.weight = source.weight
	target.use_type = source.use_type
	target.heal_amount = source.heal_amount
	target.food_amount = source.food_amount
	target.water_amount = source.water_amount
	target.virus_amount = source.virus_amount
	target.stamina_amount = source.stamina_amount
	target.damage = source.damage
	target.use_cooldown = source.use_cooldown
	target.projectile_scene = source.projectile_scene
	target.icon = source.icon
	target.equipment_slot = source.equipment_slot
	target.clothing_scene = source.clothing_scene
	target.animation_action = source.animation_action
	target.voice_event = source.voice_event

static func _number(data: Dictionary, keys: Array, fallback: float) -> float:
	for key in keys:
		if data.has(key) and data[key] is float or data.has(key) and data[key] is int:
			return float(data[key])
	return fallback

static func _int(data: Dictionary, keys: Array, fallback: int) -> int:
	for key in keys:
		if data.has(key) and (data[key] is int or data[key] is float):
			return int(data[key])
		if data.has(key) and data[key] is String and String(data[key]).is_valid_int():
			return int(data[key])
	return fallback

static func _string(data: Dictionary, keys: Array) -> String:
	for key in keys:
		if data.has(key) and data[key] != null:
			return str(data[key])
	return ""

static func _flag(data: Dictionary, keys: Array, fallback := false) -> bool:
	for key in keys:
		if data.has(key):
			var value: Variant = data[key]
			if value is bool: return bool(value)
			if value is int or value is float: return int(value) != 0
			if value is String: return not String(value).is_empty()
			return true
	return fallback
