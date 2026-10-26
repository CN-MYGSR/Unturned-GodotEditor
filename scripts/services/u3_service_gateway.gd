extends Node
class_name U3ServiceGateway

signal service_request(request_id: int, service: StringName, operation: StringName, payload: Dictionary)
signal service_response(request_id: int, accepted: bool, payload: Dictionary)

var _next_request_id := 1
var _pending_requests: Dictionary = {}

func request(service: StringName, operation: StringName, payload: Dictionary = {}) -> int:
	if service.is_empty() or operation.is_empty():
		return 0
	var request_id := _next_request_id
	_next_request_id += 1
	_pending_requests[request_id] = {"service": service, "operation": operation}
	service_request.emit(request_id, service, operation, payload.duplicate(true))
	return request_id

func resolve(request_id: int, accepted: bool, payload: Dictionary = {}) -> bool:
	if not _pending_requests.has(request_id):
		return false
	_pending_requests.erase(request_id)
	service_response.emit(request_id, accepted, payload.duplicate(true))
	return true

func has_pending_request(request_id: int) -> bool:
	return _pending_requests.has(request_id)

func pending_request_count() -> int:
	return _pending_requests.size()

func request_identity(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"identity", operation, payload)

func request_authority(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"authority", operation, payload)

func request_persistence(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"persistence", operation, payload)

func request_dialogue(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"dialogue", operation, payload)

func request_quest(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"quest", operation, payload)

func request_workshop(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"workshop", operation, payload)

func request_transport(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"transport", operation, payload)

func request_economy(operation: StringName, payload: Dictionary = {}) -> int:
	return request(&"economy", operation, payload)
