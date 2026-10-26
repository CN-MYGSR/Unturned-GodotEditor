extends CheckButton
class_name SleekToggle

# GDScript port of SDG.Glazier/SleekToggle.cs (ISleekToggle).

@export var text_color := SleekTheme.TEXT

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", text_color)

func set_toggled(value: bool) -> void:
	set_pressed_no_signal(value)

func is_toggled() -> bool:
	return button_pressed
