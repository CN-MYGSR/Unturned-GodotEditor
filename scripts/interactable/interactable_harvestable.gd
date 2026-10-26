extends Interactable
class_name InteractableHarvestable

signal harvested(actor: Node3D, item_id: StringName, amount: int)

@export var item_id: StringName
@export_range(1, 999, 1) var yield_amount := 1
@export var regrow_seconds := 0.0

var is_depleted := false
var _initial_yield := 0
var _regrow_timer: Timer

func _ready() -> void:
	_initial_yield = maxi(1, yield_amount)
	if regrow_seconds > 0.0:
		_regrow_timer = Timer.new()
		_regrow_timer.one_shot = true
		_regrow_timer.wait_time = regrow_seconds
		_regrow_timer.timeout.connect(_regrow)
		add_child(_regrow_timer)

func check_interactable() -> bool:
	return super.check_interactable() and not is_depleted

func check_highlight() -> Dictionary:
	return {"enabled": true, "color": Color("9cc779")}

func check_hint(_actor: Node3D = null) -> Dictionary:
	return {"visible": true, "text": "已采集" if is_depleted else interaction_name}

func use(actor: Node3D) -> bool:
	var inventory := _find_inventory(actor)
	if inventory == null or item_id.is_empty():
		return false
	var remainder := inventory.add_item(item_id, yield_amount)
	var collected := yield_amount - remainder
	if collected <= 0:
		return false
	harvested.emit(actor, item_id, collected)
	if remainder > 0:
		yield_amount = remainder
	else:
		is_depleted = true
		if _regrow_timer != null:
			_regrow_timer.start()
		interaction_state_changed.emit(get_state())
	return true

func get_state() -> Dictionary:
	var state := super.get_state()
	state["is_depleted"] = is_depleted
	state["yield_amount"] = yield_amount
	state["initial_yield"] = _initial_yield
	return state

func update_state(state: Dictionary) -> void:
	super.update_state(state)
	if state.has("is_depleted"):
		is_depleted = bool(state.is_depleted)
	if state.has("yield_amount"):
		yield_amount = maxi(0, int(state.yield_amount))
	if state.has("initial_yield"):
		_initial_yield = maxi(1, int(state.initial_yield))
	else:
		_initial_yield = maxi(1, yield_amount)

func _regrow() -> void:
	is_depleted = false
	yield_amount = maxi(1, _initial_yield)
	interaction_state_changed.emit(get_state())

func _find_inventory(actor: Node) -> PlayerInventory:
	var inventory := actor.get_node_or_null("Inventory") as PlayerInventory
	if inventory != null:
		return inventory
	for child in actor.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null
