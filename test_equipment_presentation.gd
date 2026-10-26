extends SceneTree

# Equipment / animation / clothing / voice runtime wiring + skill & quest asset
# compatibility. Run headless:
#   Godot --headless --path UnturnedGodot --script res://test_equipment_presentation.gd

var _failures: Array[String] = []
var _voice_events: Array[StringName] = []
var _actions: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_item_asset_compatibility()
	await _test_equipment_clothing_presentation()
	await _test_skill_asset_compatibility()
	await _test_quest_asset_compatibility()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Equipment/presentation/asset compatibility tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("Equipment/presentation test failed: " + failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _on_action(action: StringName) -> void:
	_actions.append(action)

func _on_voice(event_id: StringName, _stream: AudioStream) -> void:
	_voice_events.append(event_id)

func _make_visual_scene() -> PackedScene:
	var node := Node3D.new()
	node.name = "Visual"
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed

func _test_item_asset_compatibility() -> void:
	var weapon := ItemGameAsset.new()
	weapon.populate({"id": "spear", "name": "Spear", "MaxStack": 1, "Weight": 1.5, "Useable": "Melee", "Damage": 30, "EquipSlot": "primary", "Animation": "melee", "Voice": "punch", "category": "weapon"})
	_check(weapon.equipment_slot == &"primary", "item asset parses EquipmentSlot alias")
	_check(weapon.get_use_type_value() == ItemDefinition.UseType.MELEE, "item asset parses U3 Useable name")
	var definition := weapon.to_definition()
	_check(definition.item_id == &"spear" and definition.damage == 30.0, "item asset converts to runtime definition")
	_check(definition.is_equipment() and not definition.is_clothing(), "primary equipment is not clothing")
	_check(definition.animation_action == &"melee" and definition.voice_event == &"punch", "item asset keeps presentation hooks")

	var hat := ItemGameAsset.new()
	hat.populate({"id": "hat_01", "slot": "hat", "use_type": "clothing"})
	_check(hat.to_definition().is_clothing(), "clothing slot item asset is clothing")
	_check(not ItemDefinition.new().is_equipment(), "plain item definitions are not equipment")
	_check(ItemGameAsset.new().get_use_type_value() == ItemDefinition.UseType.NONE, "unknown use type falls back to none")

func _test_equipment_clothing_presentation() -> void:
	var player := Node3D.new()
	player.name = "Player"
	root.add_child(player)
	var life := PlayerLife.new()
	life.name = "Life"
	player.add_child(life)
	var inventory := PlayerInventory.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	var equipment := PlayerEquipment.new()
	equipment.name = "Equipment"
	player.add_child(equipment)
	var stance := PlayerStance.new()
	stance.name = "Stance"
	player.add_child(stance)
	var clothing := PlayerClothing.new()
	clothing.name = "Clothing"
	var shirt_marker := Node3D.new()
	shirt_marker.name = "ShirtMarker"
	clothing.add_child(shirt_marker)
	clothing.attachment_paths = {&"shirt": ^"ShirtMarker"}
	player.add_child(clothing)
	var animation := PlayerAnimationDriver.new()
	animation.name = "AnimationDriver"
	player.add_child(animation)
	animation.action_requested.connect(_on_action)
	var voice := PlayerVoice.new()
	voice.name = "Voice"
	player.add_child(voice)
	voice.voice_event.connect(_on_voice)
	var presentation := PlayerPresentation.new()
	presentation.name = "Presentation"
	player.add_child(presentation)
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame

	var shirt := ItemDefinition.new()
	shirt.item_id = &"shirt"
	shirt.display_name = "Shirt"
	shirt.max_stack = 1
	shirt.equipment_slot = &"shirt"
	shirt.clothing_scene = _make_visual_scene()
	var spear := ItemDefinition.new()
	spear.item_id = &"spear"
	spear.max_stack = 1
	spear.use_type = ItemDefinition.UseType.MELEE
	spear.damage = 25.0
	spear.equipment_slot = &"primary"
	spear.animation_action = &"wield"
	spear.voice_event = &"punch"
	inventory.register_definition(shirt)
	inventory.register_definition(spear)
	inventory.add_item(&"shirt", 1)
	inventory.add_item(&"spear", 1)
	await process_frame

	_check(presentation.equipment == equipment and presentation.clothing == clothing, "presentation resolves player modules")
	_check(presentation.voice == voice and presentation.animation == animation, "presentation resolves audio/animation ports")
	_check(hud.equipment == equipment and hud.inventory == inventory, "HUD binds equipment through the player path")
	hud._select_hotbar(0)
	await process_frame
	_check(equipment.get_item(&"shirt") == &"shirt", "HUD hotbar equips the matching inventory item")
	_check(hud.hud.hotbar.get_slot(0).equipped, "HUD hotbar shows the equipped highlight")
	_check(clothing.get_visual(&"shirt") != null, "clothing visual comes from item definition")
	_check(equipment.equip_from_inventory(1), "equipment equips primary item")
	await process_frame
	_check(equipment.get_item(&"primary") == &"spear", "primary slot holds spear")
	_check(_actions.has(&"wield"), "equipment change drives animation action")

	stance.set_stance(&"crouching")
	_check(is_equal_approx(presentation.get_stance_blend(), 0.5), "presentation maps crouching to stance blend")
	stance.set_stance(&"prone")
	_check(is_equal_approx(presentation.get_stance_blend(), 1.0), "presentation maps prone to stance blend")

	var hurt_stream := AudioStreamWAV.new()
	voice.register_event(&"hurt", hurt_stream)
	voice.register_event(&"death", AudioStreamWAV.new())
	_voice_events.clear()
	life.take_damage(10.0)
	_check(_voice_events.has(&"hurt"), "voice reacts to damage")
	life.take_damage(999.0)
	_check(_voice_events.has(&"death"), "voice reacts to death")
	_check(animation.get_current_action() == &"death", "presentation plays death animation")

	inventory.remove_item(&"shirt", 1)
	await process_frame
	_check(equipment.get_item(&"shirt").is_empty(), "equipment drops items removed from inventory")
	_check(clothing.get_visual(&"shirt") == null, "clothing clears removed visual")
	_check(not hud.hud.hotbar.get_slot(0).equipped, "HUD hotbar clears the equipped highlight")


func _test_skill_asset_compatibility() -> void:
	var strength := SkillGameAsset.new()
	strength.populate({"type": "skill", "id": "strength", "MaxLevel": 3, "Cost": 10, "CostIncrease": 5, "Difficulty": "hard", "effects": {"melee_damage": 2.5}})
	var melee := SkillGameAsset.new()
	melee.populate({"type": "skill", "id": "melee", "max_level": 2, "base_cost": 5, "cost_per_level": 5, "prerequisites": ["strength"], "required_level": 2})
	_check(strength.difficulty == 2, "skill difficulty alias parsed")
	_check(strength.base_cost == 10 and strength.cost_per_level == 5, "skill cost aliases parsed")
	_check(melee.prerequisites.size() == 1 and melee.prerequisites[0] == &"strength", "skill prerequisites parsed")

	var skills := PlayerSkills.new()
	root.add_child(skills)
	_check(skills.load_skill_assets([strength, melee]) == 2, "skill assets register")
	skills.set_experience(1000)
	_check(not skills.upgrade(&"melee"), "skill prerequisite blocks early upgrade")
	_check(skills.upgrade(&"strength") and skills.upgrade(&"strength"), "prerequisite skill upgrades")
	_check(is_equal_approx(skills.get_effect_total(&"melee_damage"), 5.0), "skill effects accumulate with level")
	_check(skills.upgrade(&"melee"), "skill unlocks after prerequisite level")
	skills.queue_free()

func _test_quest_asset_compatibility() -> void:
	var quest := QuestGameAsset.new()
	quest.populate({
		"type": "quest", "id": "clear", "level": 2, "npc": "trader",
		"objectives": [{"type": "kill_zombie", "amount": 2}, {"type": "collect_item", "target": "medkit", "amount": 1}],
		"rewards": [{"type": "experience", "amount": 50}, {"type": "item", "id": "medkit", "amount": 2}, {"type": "flag", "id": "cleared", "value": true}],
		"flags": {"quest_done": true},
	})
	_check(quest.level == 2 and quest.npc_id == &"trader", "quest level/npc aliases parsed")
	_check(quest.objectives.size() == 2 and quest.rewards.size() == 3, "quest objectives/rewards parsed")
	_check(quest.flags_set.get("quest_done", false), "quest flags parsed")

	var actor := Node3D.new()
	actor.name = "Player"
	root.add_child(actor)
	var skills := PlayerSkills.new()
	skills.name = "Skills"
	actor.add_child(skills)
	var inventory := PlayerInventory.new()
	inventory.name = "Inventory"
	actor.add_child(inventory)
	var medkit := ItemDefinition.new()
	medkit.item_id = &"medkit"
	medkit.max_stack = 5
	inventory.register_definition(medkit)

	var quests := PlayerQuests.new()
	quests.name = "Quests"
	actor.add_child(quests)
	quests.bind_rewards(skills, inventory)
	_check(quests.start_from_asset(quest), "quest asset starts")
	_check(quests.notify_event(&"kill_zombie") == 1, "kill event progresses quest objective")
	_check(not quests.is_quest_objectives_complete(&"clear"), "quest is not complete early")
	quests.notify_event(&"kill_zombie")
	_check(not quests.completed_quests.has(&"clear"), "quest waits for remaining objective")
	_check(quests.notify_event(&"collect_item", &"medkit") == 1, "collect event progresses remaining objective")
	_check(quests.completed_quests.has(&"clear"), "quest auto-completes when objectives finish")
	_check(skills.experience == 50, "quest experience reward granted")
	_check(inventory.count_item(&"medkit") == 2, "quest item reward granted")
	_check(quests.get_flag(&"cleared") == true and quests.get_flag(&"quest_done") == true, "quest reward and asset flags granted")

	# Gameplay -> asset compatibility: a pickup progresses collect objectives.
	var gather := QuestGameAsset.new()
	gather.populate({"type": "quest", "id": "gather", "objectives": [{"type": "collect_item", "target": "medkit", "amount": 1}]})
	_check(quests.start_from_asset(gather), "collect quest starts")
	var pickup := PickupInteractable.new()
	pickup.item_id = &"medkit"
	pickup.amount = 1
	actor.add_child(pickup)
	_check(pickup.use(actor), "pickup adds the item to the player inventory")
	_check(quests.completed_quests.has(&"gather"), "pickup auto-progresses the collect quest")

	actor.queue_free()




