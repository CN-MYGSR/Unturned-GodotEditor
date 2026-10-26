extends PanelContainer
class_name SleekPanel

# GDScript port of the panel/box container used by the C# Sleek widgets.
# (SDG.Glazier/SleekBox.cs + the SleekFullscreenBox pattern.)

@export var panel_color := SleekTheme.PANEL
@export var corner_radius := 8

func _ready() -> void:
	apply_style()

func apply_style() -> void:
	add_theme_stylebox_override("panel", SleekTheme.panel_style(panel_color, corner_radius))

func set_panel_color(value: Color) -> void:
	panel_color = value
	apply_style()

func set_corner_radius(value: int) -> void:
	corner_radius = value
	apply_style()
