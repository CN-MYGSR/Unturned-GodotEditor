extends Button
class_name SleekButton

# GDScript port of SDG.Glazier/SleekButton.cs (ISleekButton):
#   Text / FontSize / TextColor       -> Button text + theme overrides
#   BackgroundColor                  -> background_color
#   IsClickable                      -> set_clickable() / disabled
#   IsRaycastTarget                  -> set_raycast_target()
#   OnClicked                        -> clicked signal (native `pressed` also works)

signal clicked(button)

@export var accent := false
@export var background_color := SleekTheme.PANEL
@export var font_size_index := SleekTheme.FontSize.DEFAULT

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_style()
	add_theme_color_override("font_color", SleekTheme.TEXT)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", SleekTheme.TEXT)
	add_theme_color_override("font_disabled_color", SleekTheme.MUTED)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	clicked.emit(self)

func apply_style() -> void:
	var normal := SleekTheme.ACCENT if accent else background_color
	add_theme_stylebox_override("normal", SleekTheme.button_style(normal))
	add_theme_stylebox_override("hover", SleekTheme.button_style(normal.lightened(0.12)))
	add_theme_stylebox_override("pressed", SleekTheme.button_style(normal.darkened(0.12)))
	add_theme_stylebox_override("disabled", SleekTheme.button_style(normal.darkened(0.40)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_font_size_override("font_size", SleekTheme.font_size(font_size_index))

func set_accent(value: bool) -> void:
	accent = value
	apply_style()

func set_background_color(value: Color) -> void:
	background_color = value
	apply_style()

# ISleekButton.IsClickable
func set_clickable(value: bool) -> void:
	disabled = not value

func is_clickable() -> bool:
	return not disabled

# ISleekButton.IsRaycastTarget
func set_raycast_target(value: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
