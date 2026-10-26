extends Node
class_name GameUIManager

# GDScript port of the screen bookkeeping in Unturned/Player/PlayerUI.cs +
# Unturned/UI/Player/PlayerDashboardUI.cs: one active fullscreen screen at a
# time, opened/closed by name. Screens are plain UIScreen controls, so new
# screens (e.g. crafting/skills/information from U3) can be registered without
# touching the HUD.

signal screen_opened(screen_name: StringName)
signal screen_closed(screen_name: StringName)
signal active_screen_changed(screen_name: StringName)

var screens: Dictionary = {}
var active_screen: StringName = &""

func register_screen(screen_name: StringName, screen: Control) -> bool:
	if screen_name.is_empty() or screen == null or screens.has(screen_name):
		return false
	screens[screen_name] = screen
	screen.visible = false
	return true

func open_screen(screen_name: StringName) -> bool:
	if not screens.has(screen_name):
		return false
	if active_screen == screen_name:
		return true
	if not active_screen.is_empty():
		_hide_screen(active_screen)
	active_screen = screen_name
	_show_screen(screen_name)
	screen_opened.emit(screen_name)
	active_screen_changed.emit(active_screen)
	return true

func close_screen(screen_name: StringName = &"") -> bool:
	var target := active_screen if screen_name.is_empty() else screen_name
	if target.is_empty() or not screens.has(target):
		return false
	_hide_screen(target)
	if active_screen == target:
		active_screen = &""
	screen_closed.emit(target)
	active_screen_changed.emit(active_screen)
	return true

func toggle_screen(screen_name: StringName) -> bool:
	if active_screen == screen_name:
		return close_screen(screen_name)
	return open_screen(screen_name)

func close_active() -> bool:
	return close_screen()

func close_all() -> void:
	for screen_name in screens.keys():
		_hide_screen(StringName(screen_name))
	active_screen = &""
	active_screen_changed.emit(active_screen)

func is_open(screen_name: StringName) -> bool:
	return active_screen == screen_name

func get_screen(screen_name: StringName) -> Control:
	return screens.get(screen_name) as Control

func _show_screen(screen_name: StringName) -> void:
	var screen := screens[screen_name] as Control
	if screen == null:
		return
	if screen.has_method("open"):
		screen.call("open")
	else:
		screen.visible = true

func _hide_screen(screen_name: StringName) -> void:
	var screen := screens.get(screen_name) as Control
	if screen == null:
		return
	if screen.has_method("close"):
		screen.call("close")
	else:
		screen.visible = false
