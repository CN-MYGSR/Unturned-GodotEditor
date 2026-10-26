extends RefCounted
class_name WorldEditHistory

# Snapshot-based undo/redo for WorldContentDocument edits (terrain brush, road
# points, spawns). The document serializes its editable state to a Dictionary;
# the history keeps before/after snapshots, which keeps every editor operation
# undoable without per-command classes.

var limit := 64

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

func push(before: Dictionary, after: Dictionary, label := "") -> void:
	if before.is_empty() or after.is_empty():
		return
	_undo.append({"before": before.duplicate(true), "after": after.duplicate(true), "label": label})
	_redo.clear()
	while _undo.size() > maxi(1, limit):
		_undo.pop_front()

func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	var entry: Dictionary = _undo.pop_back()
	_redo.append(entry)
	return (entry.get("before", {}) as Dictionary).duplicate(true)

func redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	var entry: Dictionary = _redo.pop_back()
	_undo.append(entry)
	return (entry.get("after", {}) as Dictionary).duplicate(true)

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func get_undo_label() -> String:
	return "" if _undo.is_empty() else str(_undo.back().get("label", ""))

func undo_count() -> int:
	return _undo.size()

func redo_count() -> int:
	return _redo.size()

func clear() -> void:
	_undo.clear()
	_redo.clear()
