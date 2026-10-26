extends Interactable
class_name InteractableGenerator

signal power_changed(is_powered: bool)

@export var fuel := 0.0
@export var fuel_capacity := 100.0
@export var fuel_use_per_second := 0.0
@export var starts_enabled := false

var is_enabled := false
var is_powered := false

func _ready() -> void:
	is_enabled = starts_enabled
	_refresh_power()

func _process(delta: float) -> void:
	if is_enabled and fuel_use_per_second > 0.0:
		fuel = maxf(0.0, fuel - fuel_use_per_second * delta)
		_refresh_power()

func check_interactable() -> bool:
	return super.check_interactable() and (is_enabled or fuel < fuel_capacity)

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": Color("edbd64") if is_powered else Color("9da6ab")}

func check_hint(_actor: Node3D = null) -> Dictionary:
	var action := "Выключить" if is_enabled else ("Нет топлива" if fuel <= 0.0 else "Включить")
	return {"visible": true, "text": "%s · %.0f%%" % [action, fuel / maxf(fuel_capacity, 0.001) * 100.0]}

func use(_actor: Node3D) -> bool:
	if is_enabled:
		is_enabled = false
	else:
		if fuel <= 0.0:
			return false
		is_enabled = true
	_refresh_power()
	return true

func add_fuel(amount: float) -> float:
	if amount <= 0.0:
		return amount
	var added := minf(amount, fuel_capacity - fuel)
	fuel += added
	_refresh_power()
	return amount - added

func get_state() -> Dictionary:
	var state := super.get_state()
	state["fuel"] = fuel
	state["is_enabled"] = is_enabled
	return state

func update_state(state: Dictionary) -> void:
	super.update_state(state)
	if state.has("fuel"): fuel = clampf(float(state.fuel), 0.0, fuel_capacity)
	if state.has("is_enabled"): is_enabled = bool(state.is_enabled)
	_refresh_power()

func _refresh_power() -> void:
	var next_powered := is_enabled and fuel > 0.0
	if next_powered == is_powered:
		return
	is_powered = next_powered
	power_changed.emit(is_powered)
	interaction_state_changed.emit(get_state())
