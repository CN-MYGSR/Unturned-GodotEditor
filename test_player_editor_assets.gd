extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var equipment := PlayerEquipment.new()
	equipment.name = "Equipment"
	actor.add_child(equipment)
	_expect(equipment.equip(&"shirt", &"shirt_01"), "equip clothing item")
	_expect(equipment.get_item(&"shirt") == &"shirt_01", "equipment lookup")
	var saved_equipment := equipment.get_state()
	equipment.unequip(&"shirt")
	equipment.update_state(saved_equipment)
	_expect(equipment.get_item(&"shirt") == &"shirt_01", "equipment persistence")

	var skill := SkillGameAsset.new()
	skill.populate({"type": "skill", "id": "sprint", "max_level": 5, "base_cost": 12, "cost_per_level": 4})
	var skills := PlayerSkills.new()
	actor.add_child(skills)
	_expect(skills.load_skill_assets([skill]) == 1 and skills.level(&"sprint") == 0, "skill asset registration")
	skills.set_experience(12)
	_expect(skills.upgrade(&"sprint") and skills.level(&"sprint") == 1, "asset skill upgrade")

	var quests := PlayerQuests.new()
	actor.add_child(quests)
	var quest := QuestGameAsset.new()
	quest.populate({"type": "quest", "id": "clear", "objectives": [{"type": "kill_zombie", "amount": 2}]})
	_expect(quests.start_from_asset(quest), "quest asset start")
	_expect(quests.add_objective_progress(&"clear", 0, 2), "quest objective progress")
	_expect(quests.is_quest_objectives_complete(&"clear"), "quest objective completion")

	var document := WorldContentDocument.new()
	root.add_child(document)
	await process_frame
	_expect(document.paint_height(Vector3.ZERO, 4.0, 1.0), "terrain brush edit")
	_expect(document.add_road_point(Vector3.ZERO) == 0, "create road path")
	document.add_road_point(Vector3(5.0, 0.0, 0.0), 0)
	_expect(document.road_paths[0].size() == 2, "road point creation")
	document.add_spawn(Vector3(1.0, 0.0, 2.0), "zombie", "zombie_asset")
	var path := "user://world_content_test.json"
	_expect(document.save_document(path) == OK, "world data save")
	var loaded := WorldContentDocument.new()
	root.add_child(loaded)
	_expect(loaded.load_document(path) == OK, "world data load")
	_expect(loaded.spawn_points.size() == 1 and loaded.road_paths[0].size() == 2, "world data roundtrip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Equipment/assets/world editor tests passed")
	quit(0)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		push_error("Migration test failed: " + label)
		quit(1)
