@tool
extends EditorPlugin

# Dock for editing WorldContentDocument: terrain raise/lower/smooth/flatten,
# road point authoring, spawn placement/removal, undo/redo. All edits go through
# the document API so they are serialized and undoable.

const MODE_TERRAIN_RAISE := 0
const MODE_TERRAIN_LOWER := 1
const MODE_TERRAIN_SMOOTH := 2
const MODE_TERRAIN_FLATTEN := 3
const MODE_ROAD_POINT := 4
const MODE_SPAWN_PLAYER := 5
const MODE_SPAWN_ZOMBIE := 6
const MODE_SPAWN_VEHICLE := 7
const MODE_REMOVE_SPAWN := 8

var _dock: VBoxContainer
var _mode: OptionButton
var _strength: SpinBox
var _radius: SpinBox
var _road_width: SpinBox
var _status: Label
var _road_index := -1
var _dragging := false

func _enter_tree() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "World Content"
	var title := Label.new()
	title.text = "Unturned World Tools"
	_dock.add_child(title)

	_mode = OptionButton.new()
	_mode.add_item("Terrain Raise", MODE_TERRAIN_RAISE)
	_mode.add_item("Terrain Lower", MODE_TERRAIN_LOWER)
	_mode.add_item("Terrain Smooth", MODE_TERRAIN_SMOOTH)
	_mode.add_item("Terrain Flatten", MODE_TERRAIN_FLATTEN)
	_mode.add_item("Road Point", MODE_ROAD_POINT)
	_mode.add_item("Player Spawn", MODE_SPAWN_PLAYER)
	_mode.add_item("Zombie Spawn", MODE_SPAWN_ZOMBIE)
	_mode.add_item("Vehicle Spawn", MODE_SPAWN_VEHICLE)
	_mode.add_item("Remove Spawn", MODE_REMOVE_SPAWN)
	_mode.item_selected.connect(func(_index: int): _refresh_status())
	_dock.add_child(_mode)

	_strength = _make_spin("Strength", 0.1, 10.0, 0.1, 1.0)
	_radius = _make_spin("Radius", 1.0, 64.0, 0.5, 6.0)
	_road_width = _make_spin("Road Width", 0.5, 32.0, 0.5, 4.0)
	_road_width.value_changed.connect(_on_road_width_changed)

	var buttons := HBoxContainer.new()
	var new_road := Button.new()
	new_road.text = "New Road"
	new_road.pressed.connect(func(): _road_index = -1)
	buttons.add_child(new_road)
	var undo := Button.new()
	undo.text = "Undo"
	undo.pressed.connect(_on_undo)
	buttons.add_child(undo)
	var redo := Button.new()
	redo.text = "Redo"
	redo.pressed.connect(_on_redo)
	buttons.add_child(redo)
	_dock.add_child(buttons)

	var remove_point := Button.new()
	remove_point.text = "Remove Last Road Point"
	remove_point.pressed.connect(_on_remove_road_point)
	_dock.add_child(remove_point)

	_status = Label.new()
	_status.text = "Select a WorldContentDocument."
	_dock.add_child(_status)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.free()

func _make_spin(label_text: String, minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	row.add_child(spin)
	_dock.add_child(row)
	return spin

func _handles(object: Object) -> bool:
	return object is WorldContentDocument or (object is Node and _find_document(object as Node) != null)

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var document := _find_document(get_editor_interface().get_edited_scene_root())
	if document == null:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion and _dragging:
		_apply_at(document, camera, (event as InputEventMouseMotion).position)
		return AFTER_GUI_INPUT_STOP
	if not (event is InputEventMouseButton):
		return AFTER_GUI_INPUT_PASS
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return AFTER_GUI_INPUT_PASS
	if mouse.pressed:
		var is_brush := _mode.get_selected_id() <= MODE_TERRAIN_FLATTEN
		if is_brush:
			_dragging = true
			document.begin_edit()
		_apply_at(document, camera, mouse.position)
		return AFTER_GUI_INPUT_STOP
	if _dragging:
		_dragging = false
		document.end_edit("terrain brush")
		_refresh_status()
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _apply_at(document: WorldContentDocument, camera: Camera3D, screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var intersection := Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if intersection == null:
		return
	var radius := float(_radius.value)
	var strength := float(_strength.value)
	match _mode.get_selected_id():
		MODE_TERRAIN_RAISE:
			document.paint_height(intersection, radius, strength * 3.0)
		MODE_TERRAIN_LOWER:
			document.paint_height(intersection, radius, -strength * 3.0)
		MODE_TERRAIN_SMOOTH:
			document.smooth_height(intersection, radius, clampf(strength, 0.0, 1.0))
		MODE_TERRAIN_FLATTEN:
			document.flatten_height(intersection, radius, document.get_height_at(intersection), clampf(strength, 0.0, 1.0))
		MODE_ROAD_POINT:
			_road_index = document.add_road_point(intersection, _road_index)
			_road_width.value = document.road_width
		MODE_SPAWN_PLAYER:
			document.add_spawn(intersection, "player")
		MODE_SPAWN_ZOMBIE:
			document.add_spawn(intersection, "zombie")
		MODE_SPAWN_VEHICLE:
			document.add_spawn(intersection, "vehicle")
		MODE_REMOVE_SPAWN:
			document.remove_spawn_near(intersection, maxf(radius, 1.0))
	_refresh_status()

func _on_road_width_changed(value: float) -> void:
	var document := _find_document(get_editor_interface().get_edited_scene_root())
	if document != null:
		document.set_road_width(value)

func _on_undo() -> void:
	var document := _find_document(get_editor_interface().get_edited_scene_root())
	if document != null:
		document.undo()
		_refresh_status()

func _on_redo() -> void:
	var document := _find_document(get_editor_interface().get_edited_scene_root())
	if document != null:
		document.redo()
		_refresh_status()

func _on_remove_road_point() -> void:
	var document := _find_document(get_editor_interface().get_edited_scene_root())
	if document == null or _road_index < 0 or _road_index >= document.road_paths.size():
		return
	var points := document.road_paths[_road_index]
	if points.is_empty():
		document.remove_road(_road_index)
		_road_index = -1
	else:
		document.remove_road_point(_road_index, points.size() - 1)
	_refresh_status()

func _refresh_status() -> void:
	var document := _find_document(get_editor_interface().get_edited_scene_root())
	if _status == null:
		return
	if document == null:
		_status.text = "Select a WorldContentDocument."
		return
	_status.text = "Road #%d · undo %d / redo %d" % [_road_index, document.history.undo_count() if document.history != null else 0, document.history.redo_count() if document.history != null else 0]

func _find_document(root: Node) -> WorldContentDocument:
	if root == null: return null
	if root is WorldContentDocument: return root as WorldContentDocument
	for node in root.find_children("*", "WorldContentDocument", true, false):
		return node as WorldContentDocument
	return null
