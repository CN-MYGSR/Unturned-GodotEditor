extends Node
class_name GameSaveManager

signal save_completed(path: String)
signal load_completed(path: String, success: bool)
signal save_failed(path: String, error: Error)

@export var save_path := "user://world_save.json"
var _providers: Dictionary = {}

func register_provider(provider_id: StringName, provider: Node) -> void:
	if not provider_id.is_empty() and provider != null and provider.has_method("get_state") and provider.has_method("update_state"):
		_providers[provider_id] = weakref(provider)

func unregister_provider(provider_id: StringName) -> void:
	_providers.erase(provider_id)

func save_game(path := "") -> bool:
	var target := save_path if path.is_empty() else path
	var data := {"format": 1, "saved_at_unix": int(Time.get_unix_time_from_system()), "providers": {}}
	for provider_id in _providers:
		var reference: WeakRef = _providers[provider_id]
		var provider := reference.get_ref() as Node
		if provider == null:
			continue
		data.providers[str(provider_id)] = provider.call("get_state")
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		save_failed.emit(target, FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	save_completed.emit(target)
	return true

func load_game(path := "") -> bool:
	var target := save_path if path.is_empty() else path
	if not FileAccess.file_exists(target):
		load_completed.emit(target, false)
		return false
	var file := FileAccess.open(target, FileAccess.READ)
	if file == null:
		load_completed.emit(target, false)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("providers") is Dictionary:
		load_completed.emit(target, false)
		return false
	for provider_id in parsed.providers:
		var key := StringName(provider_id)
		if not _providers.has(key):
			continue
		var provider := (_providers[key] as WeakRef).get_ref() as Node
		if provider != null:
			provider.call("update_state", parsed.providers[provider_id])
	load_completed.emit(target, true)
	return true
