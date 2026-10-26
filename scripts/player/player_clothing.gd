extends Node3D
class_name PlayerClothing

# Visual clothing layer. Mirrors U3 PlayerClothing: the equipment slots decide
# which clothing/visual is shown, and visuals are attached under marker nodes.
# Scene resolution order: explicit `register_clothing_scene()` entry, then the
# ItemDefinition.clothing_scene of the equipped item (asset compatibility).

signal clothing_changed(slot: StringName, item_id: StringName)

@export var equipment_path: NodePath = ^"../Equipment"
@export var attachment_paths: Dictionary = {}
var _visuals: Dictionary = {}
var _visual_items: Dictionary = {}
var _clothing_scenes: Dictionary = {}
var _definitions: Dictionary = {}
var _equipment: PlayerEquipment

func _ready() -> void:
	_resolve_equipment()

func _resolve_equipment() -> void:
	var found := get_node_or_null(equipment_path) as PlayerEquipment
	if found != null:
		bind_equipment(found)

func bind_equipment(equipment: PlayerEquipment) -> void:
	if _equipment != null and _equipment.equipment_changed.is_connected(_sync_equipment):
		_equipment.equipment_changed.disconnect(_sync_equipment)
	_equipment = equipment
	if _equipment != null:
		if not _equipment.equipment_changed.is_connected(_sync_equipment):
			_equipment.equipment_changed.connect(_sync_equipment)
		_sync_equipment()

func register_definitions(definitions: Dictionary) -> void:
	_definitions = definitions
	if _equipment != null:
		_sync_equipment()

func register_definition(definition: ItemDefinition) -> void:
	if definition == null or definition.item_id.is_empty(): return
	_definitions[definition.item_id] = definition

func set_attachment_path(slot: StringName, path: NodePath) -> void:
	attachment_paths[slot] = path

func register_clothing_scene(slot: StringName, item_id: StringName, scene: PackedScene) -> void:
	_clothing_scenes["%s:%s" % [slot, item_id]] = scene

func apply_item(slot: StringName, item_id: StringName, scene: PackedScene) -> Node3D:
	_clear_slot(slot)
	if scene == null or not attachment_paths.has(slot): return null
	var attachment := get_node_or_null(NodePath(str(attachment_paths[slot])))
	if attachment == null: return null
	var visual := scene.instantiate() as Node3D
	if visual == null: return null
	attachment.add_child(visual)
	_visuals[slot] = visual
	_visual_items[slot] = item_id
	clothing_changed.emit(slot, item_id)
	return visual

func clear_item(slot: StringName) -> void:
	_clear_slot(slot)
	clothing_changed.emit(slot, &"")

func get_visual(slot: StringName) -> Node3D:
	return _visuals.get(slot)

func get_equipment() -> PlayerEquipment:
	return _equipment

func _clear_slot(slot: StringName) -> void:
	var visual: Node3D = _visuals.get(slot)
	if is_instance_valid(visual): visual.queue_free()
	_visuals.erase(slot)
	_visual_items.erase(slot)

func _sync_equipment() -> void:
	if _equipment == null: return
	for slot_string in _equipment.supported_slots:
		var slot := StringName(slot_string)
		var item_id := _equipment.get_item(slot)
		if item_id.is_empty():
			if _visuals.has(slot):
				_clear_slot(slot)
				clothing_changed.emit(slot, &"")
			continue
		if StringName(_visual_items.get(slot, "")) == item_id: continue
		var scene := _resolve_scene(slot, item_id)
		if scene != null:
			apply_item(slot, item_id, scene)
		elif _visuals.has(slot):
			_clear_slot(slot)
			clothing_changed.emit(slot, &"")

func _resolve_scene(slot: StringName, item_id: StringName) -> PackedScene:
	var registered: PackedScene = _clothing_scenes.get("%s:%s" % [slot, item_id])
	if registered != null: return registered
	var definition := _definitions.get(item_id) as ItemDefinition
	if definition != null and definition.clothing_scene != null: return definition.clothing_scene
	return null
