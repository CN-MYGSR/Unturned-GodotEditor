extends Control
class_name UIScreen

# Base class for fullscreen player UI screens (dashboard / pause / death).
# Mirrors the open/close state machine used by the C# Player*UI classes, but the
# screen itself owns its widgets so no layout logic leaks into the HUD.

signal opened
signal closed
signal close_requested

var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = is_open

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func request_close() -> void:
	close_requested.emit()
