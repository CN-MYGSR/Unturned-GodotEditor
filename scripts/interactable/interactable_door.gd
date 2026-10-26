extends Interactable
class_name InteractableDoor

signal door_state_changed(is_open: bool)

@export var starts_open := false
@export var locked := false
@export var open_angle_degrees := 90.0
@export var animation_pivot_path: NodePath

var is_open := false
var _closed_rotation := Vector3.ZERO
var _pivot: Node3D

func _ready() -> void:
	is_open = starts_open
	_pivot = get_node_or_null(animation_pivot_path) as Node3D if not animation_pivot_path.is_empty() else self
	_closed_rotation = _pivot.rotation_degrees if _pivot != null else rotation_degrees
	_apply_door_pose()

func check_interactable() -> bool:
	return super.check_interactable() and not locked

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": Color("e3c56e") if locked else Color("a5d88a")}

func check_hint(actor: Node3D = null) -> Dictionary:
	return {"visible": true, "text": "上锁" if locked else ("关闭" if is_open else "打开"), "color": Color("d87870") if locked else Color.WHITE}

func use(_actor: Node3D) -> bool:
	is_open = not is_open
	_apply_door_pose()
	door_state_changed.emit(is_open)
	interaction_state_changed.emit(get_state())
	return true

func get_state() -> Dictionary:
	var state := super.get_state()
	state["is_open"] = is_open
	state["locked"] = locked
	return state

func update_state(state: Dictionary) -> void:
	super.update_state(state)
	if state.has("is_open"): is_open = bool(state.is_open)
	if state.has("locked"): locked = bool(state.locked)
	_apply_door_pose()

func _apply_door_pose() -> void:
	if _pivot == null:
		return
	_pivot.rotation_degrees = _closed_rotation + Vector3(0.0, open_angle_degrees if is_open else 0.0, 0.0)
