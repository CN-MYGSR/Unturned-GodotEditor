extends Node
class_name PlayerPresentation

# Single-player binding layer between gameplay state and character presentation.
# U3 spreads this across PlayerAnimator/PlayerClothing/PlayerVoice/PlayerEquipment;
# here one node composes the ports so scenes stay declarative and headless tests
# can verify the wiring without an AnimationTree or audio device.
#
# Expected node layout (defaults):
#   Player (PlayerController)
#   ├── Life · Inventory · Stance · Equipment · Clothing
#   ├── AnimationDriver · Voice · VoiceAudio
#   └── Presentation
#
# Movement, stance, equipment use, damage and death fan out to animation events,
# voice events and the clothing visual layer.

@export var controller_path: NodePath = ^".."
@export var life_path: NodePath = ^"../Life"
@export var stance_path: NodePath = ^"../Stance"
@export var equipment_path: NodePath = ^"../Equipment"
@export var clothing_path: NodePath = ^"../Clothing"
@export var animation_path: NodePath = ^"../AnimationDriver"
@export var voice_path: NodePath = ^"../Voice"
@export var inventory_path: NodePath = ^"../Inventory"
@export var skills_path: NodePath = ^"../Skills"
@export var quests_path: NodePath = ^"../Quests"

var controller: PlayerController
var life: PlayerLife
var stance: PlayerStance
var equipment: PlayerEquipment
var clothing: PlayerClothing
var animation: PlayerAnimationDriver
var voice: PlayerVoice
var inventory: PlayerInventory
var skills: PlayerSkills
var quests: PlayerQuests

var _last_health := -1.0

func _ready() -> void:
	resolve_and_bind()

func resolve_and_bind() -> void:
	controller = get_node_or_null(controller_path) as PlayerController
	life = get_node_or_null(life_path) as PlayerLife
	stance = get_node_or_null(stance_path) as PlayerStance
	equipment = get_node_or_null(equipment_path) as PlayerEquipment
	clothing = get_node_or_null(clothing_path) as PlayerClothing
	animation = get_node_or_null(animation_path) as PlayerAnimationDriver
	voice = get_node_or_null(voice_path) as PlayerVoice
	inventory = get_node_or_null(inventory_path) as PlayerInventory
	skills = get_node_or_null(skills_path) as PlayerSkills
	quests = get_node_or_null(quests_path) as PlayerQuests
	_bind()

func _bind() -> void:
	if equipment != null:
		if not equipment.equipment_changed.is_connected(_on_equipment_changed):
			equipment.equipment_changed.connect(_on_equipment_changed)
		if inventory != null:
			equipment.bind_inventory(inventory)
	if clothing != null:
		if inventory != null:
			clothing.register_definitions(inventory.definitions)
		clothing.bind_equipment(equipment)
	if voice != null:
		if life != null:
			voice.bind_life(life)
		if equipment != null:
			voice.bind_equipment(equipment)
	if life != null:
		_last_health = life.health
		if not life.health_changed.is_connected(_on_health_changed):
			life.health_changed.connect(_on_health_changed)
		if not life.died.is_connected(_on_died):
			life.died.connect(_on_died)
	if quests != null:
		quests.bind_rewards(skills, inventory)
	_on_equipment_changed()

func _physics_process(_delta: float) -> void:
	if animation == null or controller == null:
		return
	var local_velocity := controller.global_transform.basis.inverse() * controller.velocity
	animation.set_movement_velocity(Vector2(local_velocity.x, local_velocity.z))
	animation.set_stance(_stance_blend())

func play_action(action: StringName, voice_event: StringName = &"") -> void:
	if animation != null:
		animation.play_action(action)
	if voice != null and not voice_event.is_empty():
		voice.play_event(voice_event)

func play_voice_event(event_id: StringName) -> bool:
	return voice.play_event(event_id) if voice != null else false

func get_stance_blend() -> float:
	return _stance_blend()

func _stance_blend() -> float:
	if stance == null:
		return 0.0
	match stance.stance:
		&"crouching": return 0.5
		&"prone": return 1.0
	return 0.0

func _on_equipment_changed() -> void:
	if equipment == null:
		return
	var arm_item := &""
	for slot in PlayerEquipment.ARM_SLOTS:
		arm_item = equipment.get_item(slot)
		if not arm_item.is_empty():
			break
	if arm_item.is_empty():
		if animation != null:
			animation.play_action(&"unarmed")
		return
	var definition := equipment.get_definition(_first_arm_slot())
	var action: StringName = definition.animation_action if definition != null and not definition.animation_action.is_empty() else &"equip"
	var voice_event: StringName = definition.voice_event if definition != null and not definition.voice_event.is_empty() else &"equip"
	play_action(action, voice_event)

func _first_arm_slot() -> StringName:
	for slot in PlayerEquipment.ARM_SLOTS:
		if not equipment.get_item(slot).is_empty():
			return slot
	return &""

func _on_health_changed(value: float) -> void:
	if _last_health >= 0.0 and value < _last_health and voice != null:
		voice.play_event(&"hurt")
	_last_health = value

func _on_died() -> void:
	if animation != null:
		animation.play_action(&"death")
	if voice != null:
		voice.play_event(&"death")
