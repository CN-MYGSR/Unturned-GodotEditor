extends Node
class_name InputBindingStore

signal binding_changed(action: StringName, event: InputEvent)

func bind_key(action: StringName, keycode: Key, physical := true) -> bool:
	if action.is_empty() or not InputMap.has_action(action): return false
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode if physical else KEY_NONE
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	binding_changed.emit(action, event)
	return true

func bind_mouse_button(action: StringName, button: MouseButton) -> bool:
	if action.is_empty() or not InputMap.has_action(action): return false
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	binding_changed.emit(action, event)
	return true

func get_bindings(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action): result.append(event.duplicate())
	return result

func restore_defaults(action: StringName) -> void:
	InputMap.load_from_project_settings()
	binding_changed.emit(action, InputMap.action_get_events(action)[0] if InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty() else null)
