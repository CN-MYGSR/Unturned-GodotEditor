extends Node
class_name PlayerLife

signal health_changed(value: float)
signal food_changed(value: float)
signal water_changed(value: float)
signal stamina_changed(value: float)
signal virus_changed(value: float)
signal bleeding_changed(value: bool)
signal broken_changed(value: bool)
signal temperature_changed(value: float)
signal died

@export var max_health := 100.0
@export var max_food := 100.0
@export var max_water := 100.0
@export var max_stamina := 100.0
@export var max_virus := 100.0
@export var starvation_damage_per_second := 2.0
@export var dehydration_damage_per_second := 4.0
@export var virus_damage_per_second := 0.5
@export var bleeding_damage_per_second := 1.0
@export var survival_drain_per_second := 0.15
@export var stamina_regen_per_second := 18.0
@export var temperature_min := -100.0
@export var temperature_max := 100.0

var health := 100.0
var food := 100.0
var water := 100.0
var stamina := 100.0
var virus := 0.0
var temperature := 0.0
var is_bleeding := false
var is_broken := false
var is_dead := false

func _ready() -> void:
	health = max_health
	food = max_food
	water = max_water
	stamina = max_stamina

func _process(delta: float) -> void:
	if is_dead: return
	set_food(food - survival_drain_per_second * delta)
	set_water(water - survival_drain_per_second * delta)
	if food <= 0.0: take_damage(starvation_damage_per_second * delta)
	if water <= 0.0: take_damage(dehydration_damage_per_second * delta)
	if virus > 0.0: take_damage(virus_damage_per_second * virus / maxf(max_virus, 1.0) * delta)
	if is_bleeding: take_damage(bleeding_damage_per_second * delta)
	if not is_broken: set_stamina(stamina + stamina_regen_per_second * delta)

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0: return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health)
	if health <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if not is_dead and amount > 0.0:
		health = minf(health + amount, max_health)
		health_changed.emit(health)

func can_apply_item_effects(healing: float, food_delta: float, water_delta: float, virus_delta: float, stamina_delta: float = 0.0) -> bool:
	if is_dead: return false
	return (healing < 0.0 and health > 0.0) or (healing > 0.0 and health < max_health) or (food_delta > 0.0 and food < max_food) or (water_delta > 0.0 and water < max_water) or (virus_delta < 0.0 and virus > 0.0) or (stamina_delta > 0.0 and stamina < max_stamina)

func apply_item_effects(healing: float, food_delta: float, water_delta: float, virus_delta: float, stamina_delta: float = 0.0) -> void:
	if healing > 0.0: heal(healing)
	elif healing < 0.0: take_damage(-healing)
	if food_delta != 0.0: set_food(food + food_delta)
	if water_delta != 0.0: set_water(water + water_delta)
	if virus_delta != 0.0: set_virus(virus + virus_delta)
	if stamina_delta != 0.0: set_stamina(stamina + stamina_delta)
func consume_food(amount: float) -> void: set_food(food + amount)
func consume_water(amount: float) -> void: set_water(water + amount)

func set_food(value: float) -> void:
	food = clampf(value, 0.0, max_food)
	food_changed.emit(food)

func set_water(value: float) -> void:
	water = clampf(value, 0.0, max_water)
	water_changed.emit(water)

func set_stamina(value: float) -> void:
	var next := clampf(value, 0.0, max_stamina)
	if is_equal_approx(next, stamina): return
	stamina = next
	stamina_changed.emit(stamina)

func consume_stamina(amount: float) -> bool:
	if amount <= 0.0 or stamina < amount: return false
	set_stamina(stamina - amount)
	return true

func set_virus(value: float) -> void:
	virus = clampf(value, 0.0, max_virus)
	virus_changed.emit(virus)

func set_bleeding(value: bool) -> void:
	if is_bleeding == value: return
	is_bleeding = value
	bleeding_changed.emit(value)

func set_broken(value: bool) -> void:
	if is_broken == value: return
	is_broken = value
	broken_changed.emit(value)

func set_temperature(value: float) -> void:
	temperature = clampf(value, temperature_min, temperature_max)
	temperature_changed.emit(temperature)

func get_state() -> Dictionary:
	return {"health": health, "food": food, "water": water, "stamina": stamina, "virus": virus, "temperature": temperature, "is_bleeding": is_bleeding, "is_broken": is_broken, "is_dead": is_dead}

func update_state(state: Dictionary) -> void:
	health = clampf(float(state.get("health", health)), 0.0, max_health)
	set_food(float(state.get("food", food)))
	set_water(float(state.get("water", water)))
	set_stamina(float(state.get("stamina", stamina)))
	set_virus(float(state.get("virus", virus)))
	set_temperature(float(state.get("temperature", temperature)))
	set_bleeding(bool(state.get("is_bleeding", is_bleeding)))
	set_broken(bool(state.get("is_broken", is_broken)))
	is_dead = bool(state.get("is_dead", is_dead))
	health_changed.emit(health)

func respawn() -> void:
	is_dead = false
	health = max_health
	food = max_food
	water = max_water
	stamina = max_stamina
	virus = 0.0
	is_bleeding = false
	is_broken = false
	health_changed.emit(health)
	food_changed.emit(food)
	water_changed.emit(water)
	stamina_changed.emit(stamina)
	virus_changed.emit(virus)
	bleeding_changed.emit(false)
	broken_changed.emit(false)


