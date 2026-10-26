extends Node
class_name Damageable

signal damaged(context: DamageContext, remaining_health: float)
signal healed(amount: float, health: float)
signal died(context: DamageContext)

@export var max_health := 100.0
@export var armor := 0.0
@export var damage_multiplier := 1.0
var health := 100.0
var is_dead := false
var invulnerable := false

func _ready() -> void:
	health = max_health

func apply_damage(context: DamageContext) -> float:
	if context == null or invulnerable or is_dead or context.amount <= 0.0: return 0.0
	var applied := maxf(0.0, context.amount * maxf(0.0, damage_multiplier) - maxf(0.0, armor))
	if applied <= 0.0: return 0.0
	health = maxf(0.0, health - applied)
	damaged.emit(context, health)
	if health <= 0.0:
		is_dead = true
		died.emit(context)
	return applied

func heal(amount: float) -> float:
	if amount <= 0.0 or is_dead: return 0.0
	var previous := health
	health = minf(max_health, health + amount)
	healed.emit(health - previous, health)
	return health - previous

func get_state() -> Dictionary:
	return {"health": health, "is_dead": is_dead}

func update_state(state: Dictionary) -> void:
	health = clampf(float(state.get("health", health)), 0.0, max_health)
	is_dead = bool(state.get("is_dead", health <= 0.0))
