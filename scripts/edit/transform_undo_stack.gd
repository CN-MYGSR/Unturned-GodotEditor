extends Node
class_name TransformUndoStack

signal history_changed(can_undo: bool, can_redo: bool)

@export_range(1, 1000, 1) var maximum_entries := 128
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

func record_transform(node: Node3D, before: Transform3D, after: Transform3D = Transform3D()) -> bool:
	if node == null: return false
	var final_transform := node.global_transform if after == Transform3D() else after
	if before.is_equal_approx(final_transform): return false
	_undo.append({"path": node.get_path(), "before": before, "after": final_transform})
	while _undo.size() > maximum_entries: _undo.pop_front()
	_redo.clear()
	_emit_history()
	return true

func undo() -> bool:
	if _undo.is_empty(): return false
	var command: Dictionary = _undo.pop_back()
	if not _apply(command, "before"): return false
	_redo.append(command)
	_emit_history()
	return true

func redo() -> bool:
	if _redo.is_empty(): return false
	var command: Dictionary = _redo.pop_back()
	if not _apply(command, "after"): return false
	_undo.append(command)
	_emit_history()
	return true

func clear() -> void:
	_undo.clear()
	_redo.clear()
	_emit_history()

func _apply(command: Dictionary, key: String) -> bool:
	var node := get_tree().root.get_node_or_null(command.path) as Node3D
	if node == null: return false
	node.global_transform = command[key]
	return true

func _emit_history() -> void:
	history_changed.emit(not _undo.is_empty(), not _redo.is_empty())
