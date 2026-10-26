extends Node3D
class_name InteractableSalvageable

signal salvage_started(actor: Node3D, duration: float)
signal salvaged(actor: Node3D)

@export var owner_id := 0
@export var group_id := 0
@export_range(0.0, 300.0, 0.1) var salvage_duration := 5.0
@export var allow_unowned_salvage := true
@export var interaction_enabled := true

var _salvaging: Dictionary = {}
var _salvage_serial := 0

func has_ownership(actor: Node) -> bool:
	if actor == null:
		return false
	var actor_owner := int(actor.get_meta("owner_id", 0))
	var actor_group := int(actor.get_meta("group_id", 0))
	return (owner_id != 0 and actor_owner == owner_id) or (group_id != 0 and actor_group == group_id)

func can_salvage(actor: Node) -> bool:
	if not interaction_enabled or actor == null:
		return false
	return has_ownership(actor) or (allow_unowned_salvage and owner_id == 0 and group_id == 0)

func begin_salvage(actor: Node3D) -> bool:
	if not can_salvage(actor) or _salvaging.has(actor.get_instance_id()):
		return false
	_salvage_serial += 1
	var actor_id := actor.get_instance_id()
	var request_id := _salvage_serial
	_salvaging[actor_id] = request_id
	var timer := get_tree().create_timer(salvage_duration)
	salvage_started.emit(actor, salvage_duration)
	timer.timeout.connect(_finish_salvage.bind(actor_id, request_id, actor), CONNECT_ONE_SHOT)
	return true

func cancel_salvage(actor: Node) -> bool:
	if actor == null:
		return false
	return _salvaging.erase(actor.get_instance_id())

func _finish_salvage(actor_id: int, request_id: int, actor: Node3D) -> void:
	if not _salvaging.has(actor_id) or int(_salvaging[actor_id]) != request_id:
		return
	if not is_instance_valid(actor) or not can_salvage(actor):
		_salvaging.erase(actor_id)
		return
	_salvaging.erase(actor_id)
	salvaged.emit(actor)
	queue_free()
