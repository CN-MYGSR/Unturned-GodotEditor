extends VehicleBody3D
class_name VehicleController

signal vehicle_entered(actor: Node3D, seat_index: int)
signal vehicle_exited(actor: Node3D, seat_index: int)
signal vehicle_state_changed(state: Dictionary)
signal health_changed(value: float, previous: float)
signal fuel_changed(value: float, previous: float)
signal battery_changed(value: float, previous: float)
signal lights_changed(enabled: bool)
signal lock_changed(locked: bool)
signal vehicle_destroyed
signal focused(actor: Node3D)
signal unfocused(actor: Node3D)

@export var vehicle_id: StringName
@export var interaction_enabled := true
@export var interaction_name := "进入载具"
@export var highlight_color := Color.WHITE
@export var max_health := 100.0
@export var max_fuel := 100.0
@export var max_battery := 100.0
@export var fuel_consumption_per_second := 0.02
@export var battery_consumption_per_second := 0.01
@export var engine_force_max := 1200.0
@export var brake_force := 30.0
@export var steering_limit := 0.45
@export var steering_speed := 2.5
@export var seat_paths: Array[NodePath] = []
@export var driver_seat_index := 0
@export var lock_owner_id: StringName
@export var locked := false
@export var headlights: Array[NodePath] = []
@export var trunk_capacity := 24
@export var auto_start_engine := true

var health := -1.0
var fuel := 100.0
var battery := 100.0
var engine_running := false
var headlights_enabled := false
var sirens_enabled := false
var passengers: Dictionary = {}
var trunk: Array[Dictionary] = []
var _seat_nodes: Array[Node3D] = []
var _previous_velocity := Vector3.ZERO
var _destroyed := false

func _ready() -> void:
	health = clampf(max_health if health < 0.0 else health, 0.0, max_health)
	fuel = clampf(fuel, 0.0, max_fuel)
	battery = clampf(battery, 0.0, max_battery)
	engine_force = engine_force_max
	steering_limit = absf(steering_limit)
	for path in seat_paths:
		_seat_nodes.append(get_node_or_null(path) as Node3D)
	if driver_seat_index < 0 or driver_seat_index >= _seat_nodes.size():
		driver_seat_index = 0
	_previous_velocity = linear_velocity

func _physics_process(delta: float) -> void:
	var driver := get_driver()
	if driver == null or _destroyed:
		engine_force = 0.0
		brake = brake_force
		steering = move_toward(steering, 0.0, steering_speed * delta)
	else:
		var throttle := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		var turn := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		if InputMap.has_action("vehicle_accelerate"):
			throttle = Input.get_axis("vehicle_reverse", "vehicle_accelerate")
		if InputMap.has_action("vehicle_steer_right"):
			turn = Input.get_axis("vehicle_steer_left", "vehicle_steer_right")
		engine_force = engine_force_max * throttle if engine_running and fuel > 0.0 else 0.0
		brake = brake_force if Input.is_key_pressed(KEY_SPACE) else 0.0
		steering = move_toward(steering, turn * steering_limit, steering_speed * delta)
		if engine_running:
			_set_fuel(fuel - fuel_consumption_per_second * absf(throttle) * delta)
			_set_battery(battery - battery_consumption_per_second * delta)
			if fuel <= 0.0 or battery <= 0.0:
				engine_running = false
	if not is_zero_approx(linear_velocity.length_squared() - _previous_velocity.length_squared()):
		vehicle_state_changed.emit(get_state())
	_previous_velocity = linear_velocity

func check_interactable() -> bool:
	return interaction_enabled and not _destroyed

func can_interact(actor: Node3D) -> bool:
	return actor != null and check_interactable() and check_useable(actor)

func check_useable(actor: Node3D = null) -> bool:
	if actor == null:
		return false
	if locked and not _is_owner(actor):
		return false
	return _find_free_seat() >= 0

func check_hint(actor: Node3D = null) -> Dictionary:
	if locked and (actor == null or not _is_owner(actor)):
		return {"visible": true, "text": "已锁定", "color": Color("d87870")}
	return {"visible": true, "text": "进入载具", "color": highlight_color}

func use(actor: Node3D) -> bool:
	return enter(actor)

func enter(actor: Node3D, requested_seat := -1) -> bool:
	if actor == null or not check_interactable():
		return false
	if locked and not _is_owner(actor):
		return false
	var index := requested_seat if requested_seat >= 0 else _find_free_seat()
	if index < 0 or index >= _seat_nodes.size() or passengers.has(index):
		return false
	var seat := _seat_nodes[index]
	if seat == null:
		return false
	passengers[index] = actor
	if actor is CharacterBody3D:
		(actor as CharacterBody3D).velocity = Vector3.ZERO
	actor.reparent(seat, true)
	actor.global_transform = seat.global_transform
	actor.set_meta("vehicle", self)
	actor.set_meta("vehicle_seat_index", index)
	if index == driver_seat_index:
		brake = 0.0
		if auto_start_engine and fuel > 0.0 and battery > 0.0:
			engine_running = true
	vehicle_entered.emit(actor, index)
	vehicle_state_changed.emit(get_state())
	return true

func exit(actor: Node3D) -> bool:
	for index in passengers:
		if passengers[index] != actor:
			continue
		var seat := _seat_nodes[index]
		var exit_transform := global_transform
		if seat != null:
			exit_transform = seat.global_transform
		actor.reparent(get_tree().root, true)
		actor.global_position = exit_transform.origin + global_basis.x * 1.5 + Vector3.UP * 0.2
		actor.remove_meta("vehicle")
		actor.remove_meta("vehicle_seat_index")
		passengers.erase(index)
		if index == driver_seat_index:
			engine_running = false
		vehicle_exited.emit(actor, index)
		vehicle_state_changed.emit(get_state())
		return true
	return false

func get_driver() -> Node3D:
	return passengers.get(driver_seat_index) as Node3D

func set_locked(value: bool, actor: Node3D = null) -> bool:
	if actor != null and lock_owner_id != &"" and not _is_owner(actor):
		return false
	if locked == value:
		return true
	locked = value
	lock_changed.emit(locked)
	vehicle_state_changed.emit(get_state())
	return true

func toggle_headlights() -> void:
	headlights_enabled = not headlights_enabled and battery > 0.0
	for path in headlights:
		var light := get_node_or_null(path) as Light3D
		if light != null:
			light.visible = headlights_enabled
	lights_changed.emit(headlights_enabled)

func apply_damage(amount: float, _source: Node = null) -> float:
	if amount <= 0.0 or _destroyed:
		return health
	var previous := health
	health = maxf(0.0, health - amount)
	health_changed.emit(health, previous)
	if health <= 0.0:
		_destroy_vehicle()
	return health

func repair(amount: float) -> float:
	if amount <= 0.0 or _destroyed:
		return 0.0
	var old := health
	health = minf(max_health, health + amount)
	health_changed.emit(health, old)
	return health - old

func add_fuel(amount: float) -> float:
	var before := fuel
	_set_fuel(fuel + maxf(0.0, amount))
	return amount - (fuel - before)

func add_battery_charge(amount: float) -> float:
	var before := battery
	_set_battery(battery + maxf(0.0, amount))
	return amount - (battery - before)

func add_trunk_stack(item_id: StringName, amount: int, max_stack := 1) -> int:
	if item_id.is_empty() or amount <= 0:
		return amount
	for stack in trunk:
		if stack.item_id == item_id and stack.amount < max_stack:
			var moved := mini(amount, max_stack - stack.amount)
			stack.amount += moved
			return amount - moved
	if trunk.size() >= trunk_capacity:
		return amount
	var moved := mini(amount, max_stack)
	trunk.append({"item_id": item_id, "amount": moved})
	return amount - moved

func remove_trunk_stack(index: int, amount := -1) -> Dictionary:
	if index < 0 or index >= trunk.size():
		return {}
	var stack: Dictionary = trunk[index]
	var removed := int(stack.amount) if amount <= 0 else mini(amount, int(stack.amount))
	var result := {"item_id": stack.item_id, "amount": removed}
	stack.amount -= removed
	if stack.amount <= 0:
		trunk.remove_at(index)
	return result

func get_state() -> Dictionary:
	var seat_state := {}
	for index in passengers:
		var passenger := passengers[index] as Node
		seat_state[index] = passenger.get_path() if is_instance_valid(passenger) else NodePath()
	return {"vehicle_id": vehicle_id, "transform": global_transform, "linear_velocity": linear_velocity, "angular_velocity": angular_velocity, "health": health, "fuel": fuel, "battery": battery, "engine_running": engine_running, "locked": locked, "lock_owner_id": lock_owner_id, "headlights_enabled": headlights_enabled, "sirens_enabled": sirens_enabled, "passengers": seat_state, "trunk": trunk.duplicate(true), "destroyed": _destroyed}

func update_state(state: Dictionary) -> void:
	if state.has("transform") and state.transform is Transform3D:
		global_transform = state.transform
	if state.has("linear_velocity"): linear_velocity = state.linear_velocity
	if state.has("angular_velocity"): angular_velocity = state.angular_velocity
	if state.has("health"): health = clampf(float(state.health), 0.0, max_health)
	if state.has("fuel"): _set_fuel(float(state.fuel))
	if state.has("battery"): _set_battery(float(state.battery))
	if state.has("engine_running"): engine_running = bool(state.engine_running)
	if state.has("locked"): locked = bool(state.locked)
	if state.has("lock_owner_id"): lock_owner_id = StringName(state.lock_owner_id)
	if state.has("headlights_enabled"): headlights_enabled = bool(state.headlights_enabled)
	if state.has("sirens_enabled"): sirens_enabled = bool(state.sirens_enabled)
	if state.get("trunk") is Array: trunk = state.trunk.duplicate(true)
	if state.has("destroyed"): _destroyed = bool(state.destroyed)

func _find_free_seat() -> int:
	if _seat_nodes.is_empty():
		return -1
	if driver_seat_index >= 0 and driver_seat_index < _seat_nodes.size() and not passengers.has(driver_seat_index):
		return driver_seat_index
	for index in _seat_nodes.size():
		if _seat_nodes[index] != null and not passengers.has(index):
			return index
	return -1

func _is_owner(actor: Node) -> bool:
	return lock_owner_id.is_empty() or StringName(str(actor.get_meta("owner_id", ""))) == lock_owner_id

func _set_fuel(value: float) -> void:
	var previous := fuel
	fuel = clampf(value, 0.0, max_fuel)
	if not is_equal_approx(previous, fuel):
		fuel_changed.emit(fuel, previous)

func _set_battery(value: float) -> void:
	var previous := battery
	battery = clampf(value, 0.0, max_battery)
	if not is_equal_approx(previous, battery):
		battery_changed.emit(battery, previous)

func _destroy_vehicle() -> void:
	if _destroyed:
		return
	_destroyed = true
	engine_running = false
	for actor in passengers.values().duplicate():
		if is_instance_valid(actor):
			exit(actor)
	vehicle_destroyed.emit()
	vehicle_state_changed.emit(get_state())








