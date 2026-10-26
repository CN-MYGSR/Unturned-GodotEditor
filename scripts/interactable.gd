extends Node3D
class_name Interactable

signal focused(actor: Node3D)
signal unfocused(actor: Node3D)
signal interacted(actor: Node3D)
signal interaction_state_changed(state: Dictionary)

@export var interaction_name := "Interact"
@export var interaction_enabled := true
@export var one_shot := false
@export var interaction_distance := 3.0
@export var highlight_color := Color.WHITE

var _has_interacted := false

func check_interactable() -> bool:
	return interaction_enabled and not (one_shot and _has_interacted)

func check_useable(_actor: Node3D = null) -> bool:
	return check_interactable()

func can_interact(actor: Node3D) -> bool:
	return actor != null and check_interactable() and check_useable(actor)

func check_highlight() -> Dictionary:
	return {"enabled": false, "color": highlight_color}

func check_hint(_actor: Node3D = null) -> Dictionary:
	return {"visible": check_interactable(), "text": interaction_name, "color": highlight_color}

func interact(actor: Node3D) -> bool:
	if not can_interact(actor):
		return false
	if not use(actor):
		return false
	_has_interacted = true
	interacted.emit(actor)
	if one_shot:
		interaction_enabled = false
	return true

func use(_actor: Node3D) -> bool:
	return true

func update_state(state: Dictionary) -> void:
	if state.has("interaction_enabled"):
		interaction_enabled = bool(state.interaction_enabled)
	if state.has("has_interacted"):
		_has_interacted = bool(state.has_interacted)

func get_state() -> Dictionary:
	return {"interaction_enabled": interaction_enabled, "has_interacted": _has_interacted}

func set_interaction_enabled(enabled: bool) -> void:
	if interaction_enabled == enabled:
		return
	interaction_enabled = enabled
	interaction_state_changed.emit(get_state())

func get_interaction_owner() -> Node:
	var current: Node = self
	while current != null and not current is VehicleBody3D and not current.is_in_group("vehicle"):
		current = current.get_parent()
	return current

func focus(actor: Node3D) -> void:
	focused.emit(actor)

func unfocus(actor: Node3D) -> void:
	unfocused.emit(actor)
