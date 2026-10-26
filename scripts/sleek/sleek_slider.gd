extends HSlider
class_name SleekSlider

# GDScript port of SDG.Glazier/SleekSlider.cs (ISleekSlider).

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(120, 20)

func set_slider_value(value: float) -> void:
	set_value_no_signal(value)
