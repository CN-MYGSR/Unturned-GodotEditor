extends Node
class_name PlayerGroup

signal membership_changed(member_id: StringName, joined: bool)
signal rank_changed(member_id: StringName, rank: int)
signal group_name_changed(value: String)

@export var maximum_members := 8
var group_name := ""
var members: Dictionary = {}

func add_member(member_id: StringName, rank := 0) -> bool:
	if member_id.is_empty() or members.has(member_id) or members.size() >= maximum_members: return false
	members[member_id] = clampi(rank, 0, 3)
	membership_changed.emit(member_id, true)
	return true

func remove_member(member_id: StringName) -> bool:
	if not members.erase(member_id): return false
	membership_changed.emit(member_id, false)
	return true

func set_rank(member_id: StringName, rank: int) -> bool:
	if not members.has(member_id): return false
	members[member_id] = clampi(rank, 0, 3)
	rank_changed.emit(member_id, members[member_id])
	return true

func set_group_name(value: String) -> void:
	var clean := value.strip_edges().substr(0, 32)
	if group_name == clean: return
	group_name = clean
	group_name_changed.emit(group_name)

func get_state() -> Dictionary:
	return {"group_name": group_name, "members": members.duplicate(true)}

func update_state(state: Dictionary) -> void:
	set_group_name(str(state.get("group_name", group_name)))
	members = state.get("members", {}).duplicate(true)
