extends Control
class_name SleekWindow

# GDScript port of Unturned/Sleek/SleekWindow.cs: the fullscreen root that all
# player UI screens are parented to. Cursor locking itself stays in the game HUD
# (Godot's Input.mouse_mode), this control only owns the fullscreen rect.

var _cursor_locked := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SleekLayout.apply_full_rect(self)

func set_cursor_locked(value: bool) -> void:
	_cursor_locked = value

func is_cursor_locked() -> bool:
	return _cursor_locked

func add_element(element: Control) -> void:
	add_child(element)
