extends Interactable
class_name InteractableLadder

signal climb_requested(actor: Node3D, direction: float)

@export var climb_speed := 3.0
@export var top_exit_offset := Vector3(0.0, 1.0, -0.5)

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": Color("83c5d8")}

func check_hint(_actor: Node3D = null) -> Dictionary:
	return {"visible": true, "text": interaction_name}

func use(actor: Node3D) -> bool:
	actor.set_meta("ladder_climb_speed", climb_speed)
	actor.set_meta("ladder_node", get_path())
	climb_requested.emit(actor, climb_speed)
	return true
