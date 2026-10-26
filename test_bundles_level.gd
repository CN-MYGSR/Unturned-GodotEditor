extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var database := GameAssetDatabase.new()
	root.add_child(database)
	var loaded := database.load_json_file_entries("res://data/assets/migration_examples.json")
	_expect(loaded.size() == 4, "load four assets from JSON array")
	_expect(database.errors.is_empty(), "asset loading has no errors")
	_expect(database.find_by_id(&"field_bandage") is ItemGameAsset, "lookup item by id")
	_expect(database.find_by_guid("D7A608F7-11EA-4C1C-9D79-010000000002") is ObjectGameAsset, "lookup object by normalized guid")
	_expect(database.find_all_of_type("object").size() == 1, "lookup assets by type")

	var spawn_table := database.find_by_id(&"medical_loot") as SpawnTableGameAsset
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var picked := spawn_table.pick(rng)
	_expect(picked == &"field_bandage" or picked == &"unknown_item", "weighted spawn table selection")

	var level := database.find_by_id(&"migration_test_level") as LevelGameAsset
	_expect(level != null and level.is_valid(), "level asset validation")
	_expect(level.placements.size() == 1, "level placement parsing")
	_expect(level.get_spawn_points("player").size() == 1, "player spawn parsing")
	_expect(level.get_spawn_points("zombie").size() == 1, "zombie spawn parsing")

	var runtime := LevelRuntime.new()
	root.add_child(runtime)
	_expect(runtime.build(level, database), "build level runtime")
	await process_frame
	_expect(runtime.get_child_count() == 3, "instantiate object and two spawn markers")
	_expect(runtime.get_region_nodes(Vector2i.ZERO).size() == 1, "query placed object by region")
	_expect(runtime.get_spawn_markers("player").size() == 1, "query player spawn marker")
	runtime.clear_level()
	await process_frame
	_expect(runtime.get_child_count() == 0, "clear built level")
	print("Bundles/Level tests passed")
	quit(0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		push_error("Bundles/Level test failed: " + label)
		quit(1)
