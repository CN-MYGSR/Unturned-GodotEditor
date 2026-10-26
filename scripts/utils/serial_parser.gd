extends RefCounted
class_name SerialParser

static func split_start(serial: String) -> Dictionary:
	var index := serial.find(" ")
	return {"ok": index >= 0, "start": serial.substr(0, index) if index >= 0 else "", "end": serial.substr(index + 1) if index >= 0 else ""}

static func split_end(serial: String) -> Dictionary:
	var index := serial.rfind(" ")
	return {"ok": index >= 0, "start": serial.substr(0, index) if index >= 0 else "", "end": serial.substr(index + 1) if index >= 0 else ""}

static func components(serial: String, delimiter := ",") -> PackedStringArray:
	if delimiter.is_empty(): return PackedStringArray([serial])
	return serial.split(delimiter, true)

static func serialize(values: Array, delimiter := ",") -> String:
	var parts := PackedStringArray()
	for value in values: parts.append(str(value))
	return delimiter.join(parts)

static func is_valid_ip(value: String) -> bool:
	if value.contains(":"):
		return value.is_valid_ip_address()
	var parts := value.split(".")
	if parts.size() != 4: return false
	for part in parts:
		if not part.is_valid_int() or (part.length() > 1 and part.begins_with("0")): return false
		if int(part) < 0 or int(part) > 255: return false
	return true
