extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var body := VehicleController.new()
	body.seat_paths = [NodePath("SeatDriver"), NodePath("SeatPassenger")]
	body.fuel = 50.0
	var driver_seat := Marker3D.new()
	driver_seat.name = "SeatDriver"
	var passenger_seat := Marker3D.new()
	passenger_seat.name = "SeatPassenger"
	body.add_child(driver_seat)
	body.add_child(passenger_seat)
	root.add_child(body)
	var actor := CharacterBody3D.new()
	root.add_child(actor)
	await process_frame
	_expect(body.enter(actor), "vehicle accepts actor into open driver seat")
	_expect(body.get_driver() == actor, "vehicle assigns driver seat")
	_expect(body.exit(actor), "driver can exit vehicle")
	_expect(not actor.has_meta("vehicle"), "exit clears vehicle metadata")
	_expect(body.add_fuel(10.0) <= 0.0, "vehicle accepts fuel within capacity")
	_expect(body.repair(20.0) == 0.0, "vehicle repair does not exceed full health")
	body.lock_owner_id = &"owner"
	body.locked = true
	_expect(not body.enter(actor), "locked vehicle rejects non-owner")
	actor.set_meta("owner_id", "owner")
	_expect(body.enter(actor), "vehicle owner can enter locked vehicle")
	body.apply_damage(15.0)
	_expect(is_equal_approx(body.health, body.max_health - 15.0), "vehicle damage updates health")
	_expect(body.add_trunk_stack(&"fuel", 4, 10) == 0, "vehicle trunk stores item stack")
	var state := body.get_state()
	var restored := VehicleController.new()
	root.add_child(restored)
	await process_frame
	restored.update_state(state)
	_expect(is_equal_approx(restored.health, body.health), "vehicle health restores from state")
	_expect(restored.trunk.size() == 1, "vehicle trunk restores from state")
	var gateway := U3ServiceGateway.new()
	root.add_child(gateway)
	var request_id := gateway.request_persistence(&"save_vehicle", {"state": state})
	_expect(gateway.has_pending_request(request_id), "service gateway tracks pending request")
	_expect(gateway.resolve(request_id, true), "service gateway resolves pending request")
	_expect(not gateway.has_pending_request(request_id), "resolved service request is cleared")
	if failures.is_empty():
		print("Vehicle tests passed")
		quit(0)
		return
	for failure in failures:
		push_error("Vehicle test failed: " + failure)
	quit(1)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


