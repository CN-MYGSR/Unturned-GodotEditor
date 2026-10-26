extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_parser()
	_test_spring()
	_test_skills_quests()
	_test_group_and_stance()
	_test_life()
	await _test_save_and_regions()
	await _test_undo()
	await process_frame
	if failures.is_empty():
		print("Player/Managers/Utils/Edit/Tools tests passed")
		quit(0)
		return
	for failure in failures: push_error("Foundation test failed: " + failure)
	quit(1)

func _test_parser() -> void:
	var split := SerialParser.split_start("alpha beta gamma")
	_expect(split.ok and split.start == "alpha" and split.end == "beta gamma", "parser splits prefix")
	_expect(SerialParser.split_end("alpha beta gamma").end == "gamma", "parser splits suffix")
	_expect(SerialParser.components("a,,b", ",").size() == 3, "parser preserves empty fields")
	_expect(SerialParser.is_valid_ip("127.0.0.1") and not SerialParser.is_valid_ip("999.1.1.1"), "parser validates IPv4")

func _test_spring() -> void:
	var spring := Rk4Spring.new()
	spring.target_position = 1.0
	spring.stiffness = 80.0
	spring.damping = 14.0
	for _index in 120: spring.update(1.0 / 60.0)
	_expect(absf(spring.current_position - 1.0) < 0.02, "RK4 spring converges to target")

func _test_skills_quests() -> void:
	var skills := PlayerSkills.new()
	skills.define_skill(&"aim", 3, 10, 5)
	skills.set_experience(30)
	_expect(skills.upgrade(&"aim"), "skill upgrades when experience permits")
	_expect(skills.level(&"aim") == 1 and skills.experience == 20, "skill spends experience")
	_expect(is_equal_approx(skills.mastery(&"aim"), 1.0 / 3.0), "skill mastery normalizes level")
	var quests := PlayerQuests.new()
	_expect(quests.start_quest(&"intro"), "quest starts")
	_expect(quests.track_quest(&"intro"), "active quest can be tracked")
	quests.set_flag(&"door_open", true)
	_expect(quests.complete_quest(&"intro"), "active quest completes")
	_expect(quests.get_flag(&"door_open") == true and quests.tracked_quest.is_empty(), "quest flags persist after completion")
	skills.free()
	quests.free()

func _test_group_and_stance() -> void:
	var group := PlayerGroup.new()
	group.maximum_members = 2
	_expect(group.add_member(&"one"), "group accepts member")
	_expect(group.set_rank(&"one", 2), "group updates rank")
	_expect(group.add_member(&"two") and not group.add_member(&"three"), "group enforces member limit")
	var stance := PlayerStance.new()
	_expect(stance.set_stance(&"crouching") and is_equal_approx(stance.get_height(), stance.crouching_height), "player stance changes height target")
	_expect(stance.set_stance(&"prone"), "player can enter prone stance")
	group.free()
	stance.free()

func _test_life() -> void:
	var life := PlayerLife.new()
	root.add_child(life)
	await process_frame
	_expect(life.consume_stamina(25.0), "life consumes available stamina")
	_expect(is_equal_approx(life.stamina, 75.0), "stamina level changes")
	life.set_virus(50.0)
	life.set_bleeding(true)
	life.set_broken(true)
	var state := life.get_state()
	life.set_bleeding(false)
	life.update_state(state)
	_expect(life.virus == 50.0 and life.is_bleeding and life.is_broken, "extended life state restores")
	life.queue_free()

func _test_save_and_regions() -> void:
	var save := GameSaveManager.new()
	root.add_child(save)
	var source := PlayerSkills.new()
	source.define_skill(&"craft", 2)
	source.set_experience(123)
	root.add_child(source)
	save.register_provider(&"skills", source)
	var path := "user://test_foundation_save.json"
	_expect(save.save_game(path), "save manager writes registered provider state")
	source.set_experience(10)
	_expect(save.load_game(path), "save manager reads saved state")
	_expect(source.experience == 123, "save manager restores provider state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var index := WorldRegionIndex.new()
	index.region_size = 10.0
	root.add_child(index)
	var node := Node3D.new()
	node.position = Vector3(2.0, 0.0, 2.0)
	root.add_child(node)
	index.register_node(node)
	_expect(index.query_radius(Vector3.ZERO, 5.0).has(node), "region index returns nearby registered node")
	index.unregister_node(node)
	_expect(index.query_radius(Vector3.ZERO, 5.0).is_empty(), "region index removes unregistered node")
	save.queue_free()
	source.queue_free()
	index.queue_free()
	node.queue_free()

func _test_undo() -> void:
	var undo := TransformUndoStack.new()
	root.add_child(undo)
	var node := Node3D.new()
	root.add_child(node)
	var before := node.global_transform
	node.position.x = 4.0
	_expect(undo.record_transform(node, before), "editor records transform change")
	_expect(undo.undo() and is_zero_approx(node.position.x), "editor undoes transform")
	_expect(undo.redo() and is_equal_approx(node.position.x, 4.0), "editor redoes transform")
	undo.queue_free()
	node.queue_free()

func _expect(condition: bool, label: String) -> void:
	if not condition: failures.append(label)









