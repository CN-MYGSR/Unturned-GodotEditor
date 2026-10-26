extends Node
class_name SceneObjectPool

@export var scene: PackedScene
@export_range(0, 256, 1) var prewarm_count := 0
var _available: Array[Node] = []
var _leased: Dictionary = {}

func _ready() -> void:
	for _index in prewarm_count: _available.append(_create_instance())

func acquire(parent: Node, world_transform := Transform3D.IDENTITY) -> Node:
	if parent == null or scene == null: return null
	var instance: Node = _available.pop_back() if not _available.is_empty() else _create_instance()
	if instance == null: return null
	if instance.get_parent() != null: instance.reparent(parent)
	else: parent.add_child(instance)
	if instance is Node3D: (instance as Node3D).global_transform = world_transform
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.show()
	_leased[instance.get_instance_id()] = weakref(instance)
	if instance.has_method("on_pool_acquired"): instance.call("on_pool_acquired")
	return instance

func release(instance: Node) -> bool:
	if instance == null or not _leased.has(instance.get_instance_id()): return false
	_leased.erase(instance.get_instance_id())
	if instance.has_method("on_pool_released"): instance.call("on_pool_released")
	instance.hide()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.reparent(self)
	_available.append(instance)
	return true

func clear_pool() -> void:
	for instance in _available:
		if is_instance_valid(instance): instance.queue_free()
	_available.clear()
	for reference in _leased.values():
		var instance := reference.get_ref() as Node
		if instance != null: instance.queue_free()
	_leased.clear()

func _create_instance() -> Node:
	if scene == null: return null
	var instance := scene.instantiate()
	add_child(instance)
	instance.hide()
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	return instance
