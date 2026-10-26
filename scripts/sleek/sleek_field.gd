extends LineEdit
class_name SleekField

# GDScript port of SDG.Glazier/SleekField.cs / SleekStringField.cs.

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = 28.0
	add_theme_stylebox_override("normal", SleekTheme.button_style(SleekTheme.BACKGROUND, 4))
	add_theme_stylebox_override("focus", SleekTheme.button_style(SleekTheme.PANEL_HOVER, 4))
	add_theme_color_override("font_color", SleekTheme.TEXT)
	add_theme_color_override("font_placeholder_color", SleekTheme.MUTED)
	add_theme_color_override("caret_color", SleekTheme.TEXT)
