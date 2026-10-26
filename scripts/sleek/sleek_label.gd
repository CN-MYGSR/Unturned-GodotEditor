extends Label
class_name SleekLabel

# GDScript port of SDG.Glazier/SleekLabel.cs (ISleekLabel):
#   Text / FontSize / TextAlignment / TextColor / AllowRichText
# (TextContrastContext is a uGUI-only feature and has no Godot equivalent.)

@export var font_size_index := SleekTheme.FontSize.DEFAULT
@export var text_color := SleekTheme.TEXT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_style()

func apply_style() -> void:
	add_theme_font_size_override("font_size", SleekTheme.font_size(font_size_index))
	add_theme_color_override("font_color", text_color)

func set_font_size(index: int) -> void:
	font_size_index = index
	apply_style()

func set_text_color(value: Color) -> void:
	text_color = value
	apply_style()

func set_alignment(value: int) -> void:
	horizontal_alignment = value
