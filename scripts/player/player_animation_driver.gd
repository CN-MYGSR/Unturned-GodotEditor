extends Node
class_name PlayerAnimationDriver

# Drives a character AnimationTree from movement/stance/equipment. In U3 the
# equivalent logic is spread across PlayerAnimator/PlayerMovement/PlayerLook;
# this port exposes the same parameter contract and always emits action events
# so gameplay (voice, effects, tests) works even when no AnimationTree is wired.

signal action_requested(action: StringName)

@export var animation_tree_path: NodePath = ^"../AnimationTree"
@export var movement_blend_path := "parameters/Move/blend_position"
@export var stance_path := "parameters/Stance/blend_amount"
@export var aim_path := "parameters/Aim/blend_amount"
@export var action_playback_path := "parameters/Action/playback"
var _tree: AnimationTree
var _current_action: StringName = &""

func _ready() -> void:
	_resolve_tree()

func _resolve_tree() -> void:
	_tree = get_node_or_null(animation_tree_path) as AnimationTree

func bind_tree(tree: AnimationTree) -> void:
	_tree = tree

func has_tree() -> bool:
	return _tree != null

func get_current_action() -> StringName:
	return _current_action

func set_movement_velocity(local_velocity: Vector2) -> void:
	_set_parameter(movement_blend_path, local_velocity)

func set_stance(blend: float) -> void:
	_set_parameter(stance_path, clampf(blend, 0.0, 1.0))

func set_aiming(enabled: bool) -> void:
	_set_parameter(aim_path, 1.0 if enabled else 0.0)

func play_action(action: StringName) -> bool:
	if action.is_empty(): return false
	_current_action = action
	var tree_dispatched := false
	if _tree != null and _tree.has_parameter(action_playback_path):
		var playback: AnimationNodeStateMachinePlayback = _tree.get(action_playback_path)
		if playback != null:
			playback.travel(String(action))
			tree_dispatched = true
	action_requested.emit(action)
	return tree_dispatched

func _set_parameter(path: String, value: Variant) -> void:
	if _tree != null and _tree.has_parameter(path): _tree.set(path, value)
