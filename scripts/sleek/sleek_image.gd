extends TextureRect
class_name SleekImage

# GDScript port of SDG.Glazier/SleekImageTexture.cs (ISleekImage):
#   Texture / TintColor

@export var tint_color := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	modulate = tint_color

func set_tint(value: Color) -> void:
	tint_color = value
	modulate = value
