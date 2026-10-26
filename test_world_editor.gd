extends SceneTree

# Terrain / road / spawn editor test for WorldContentDocument + WorldEditHistory.

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var document := WorldContentDocument.new()
	root.add_child(document)
	await process_frame

	_check(document.generate_collision and document.get_node_or_null("TerrainCollision") != null, "terrain collision generated")
	_check(document.history != null and not document.can_undo(), "fresh document has empty history")

	var base_height := document.get_height_at(Vector3.ZERO)
	_check(document.paint_height(Vector3.ZERO, 8.0, 4.0), "terrain raise brush edits vertices")
	var raised_height := document.get_height_at(Vector3.ZERO)
	_check(raised_height > base_height + 1.0, "raise brush modifies sampled height")
	_check(document.can_undo(), "brush edit recorded in history")
	_check(document.undo(), "undo brush edit")
	_check(is_equal_approx(document.get_height_at(Vector3.ZERO), base_height), "undo restores terrain height")
	_check(document.redo(), "redo brush edit")
	_check(document.get_height_at(Vector3.ZERO) > base_height + 1.0, "redo reapplies terrain height")

	_check(document.smooth_height(Vector3.ZERO, 10.0, 1.0), "smooth brush averages heights")
	_check(document.flatten_height(Vector3.ZERO, 10.0, 2.0, 1.0), "flatten brush sets target height")
	_check(absf(document.get_height_at(Vector3.ZERO) - 2.0) < 0.01, "flatten brush reaches target height")

	var road := document.add_road_point(Vector3.ZERO)
	_check(road == 0, "first road point creates road 0")
	document.add_road_point(Vector3(6.0, 0.0, 0.0), road)
	_check(document.add_road_point(Vector3(12.0, 0.0, 0.0), road) == road, "road points append to same road")
	_check(document.road_paths[road].size() == 3, "road stores three points")
	_check(document.move_road_point(road, 1, Vector3(0.0, 0.0, 6.0)), "move road control point")
	_check(document.remove_road_point(road, 2), "remove road control point")
	_check(document.road_paths[road].size() == 2, "road point removal shrinks path")
	_check(document.set_road_width(7.5), "set road width")
	_check(is_equal_approx(document.road_width, 7.5), "road width applied")
	_check(document.get_road_count() == 1, "road count reflects document")

	var zombie_spawn := document.add_spawn(Vector3(1.0, 0.0, 2.0), "zombie", "zombie_asset")
	_check(document.set_spawn_rotation(zombie_spawn, 90.0), "rotate spawn marker")
	_check(document.move_spawn(zombie_spawn, Vector3(3.0, 0.0, 3.0)), "move spawn marker")
	_check(document.get_spawns_of_type("zombie").size() == 1, "spawn type query")
	_check(document.add_spawn(Vector3(5.0, 0.0, 5.0), "player") == 1, "player spawn added")
	_check(document.remove_spawn(0), "remove spawn")
	_check(document.get_spawn_count() == 1, "spawn removal shrinks document")

	_check(document.set_road_width(9.0), "second road width change")
	_check(document.undo() and is_equal_approx(document.road_width, 7.5), "undo road width")
	_check(document.redo() and is_equal_approx(document.road_width, 9.0), "redo road width")

	_check(document.set_spawn_rotation(0, 45.0), "rotate remaining spawn")
	_check(document.move_spawn(0, Vector3(3.0, 0.0, 3.0)), "move remaining spawn")

	var path := "user://world_editor_test.json"
	_check(document.save_document(path) == OK, "save world document")
	var loaded := WorldContentDocument.new()
	root.add_child(loaded)
	await process_frame
	_check(loaded.load_document(path) == OK, "load world document")
	_check(loaded.get_spawn_count() == 1, "spawn roundtrip")
	_check(loaded.get_road_count() == 1 and loaded.road_paths[0].size() == 2, "road roundtrip")
	_check(is_equal_approx(loaded.road_width, 9.0), "road width roundtrip")
	_check(is_equal_approx(float(loaded.spawn_points[0].get("rotation_y", 0.0)), 45.0), "spawn rotation roundtrip")
	_check(absf(loaded.get_height_at(Vector3.ZERO) - document.get_height_at(Vector3.ZERO)) < 0.01, "terrain height roundtrip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	document.queue_free()
	loaded.queue_free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("World editor tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("World editor test failed: " + failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
