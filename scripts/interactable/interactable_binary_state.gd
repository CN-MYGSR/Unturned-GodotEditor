extends Interactable
class_name InteractableBinaryState

signal state_changed(is_active: bool)

@export var starts_active := false
@export var active_text := "关闭"
@export var inactive_text := "开启"
@export var active_color := Color("e6c86e")

var is_active := false

func _ready() -> void:
	is_active = starts_active

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": active_color if is_active else highlight_color}

func check_hint(_actor: Node3D = null) -> Dictionary:
	return {"visible": true, "text": active_text if is_active else inactive_text}

func use(_actor: Node3D) -> bool:
	is_active = not is_active
	state_changed.emit(is_active)
	interaction_state_changed.emit(get_state())
	return true

func get_state() -> Dictionary:
	var state := super.get_state()
	state["is_active"] = is_active
	return state

func update_state(state: Dictionary) -> void:
	super.update_state(state)
	if state.has("is_active"):
		is_active = bool(state.is_active)
