extends RigidBody3D
class_name Projectile

signal impacted(projectile: Projectile, context: DamageContext)

@export var damage := 25.0
@export var lifetime := 8.0
@export var impact_radius := 0.0
@export var damage_mask := 0xFFFFFFFF
@export var explode_on_impact := false

var source: Node
var _expired := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(_expire)

func launch(impulse: Vector3, instigator: Node = null) -> void:
	source = instigator
	apply_central_impulse(impulse)

func _on_body_entered(body: Node) -> void:
	if _expired or body == source: return
	var context := DamageContext.new()
	context.amount = damage
	context.source = source
	context.target = body
	context.hit_position = global_position
	context.cause = &"projectile"
	if body.has_method("apply_damage"):
		body.call("apply_damage", damage, source)
	var damageable := body.get_node_or_null("Damageable") as Damageable
	if damageable != null: damageable.apply_damage(context)
	impacted.emit(self, context)
	if explode_on_impact: _apply_radius_damage()
	_expire()

func _apply_radius_damage() -> void:
	if impact_radius <= 0.0: return
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = impact_radius
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = damage_mask
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var node := hit.collider as Node
		if node == source: continue
		var context := DamageContext.new()
		context.amount = damage * (1.0 - global_position.distance_to((node as Node3D).global_position) / impact_radius)
		context.source = source
		context.target = node
		context.hit_position = (node as Node3D).global_position
		context.cause = &"explosion"
		context.is_explosion = true
		var damageable := node.get_node_or_null("Damageable") as Damageable
		if damageable != null: damageable.apply_damage(context)

func _expire() -> void:
	if _expired: return
	_expired = true
	queue_free()
