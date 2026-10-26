extends Control
class_name SleekProgress

# GDScript port of Unturned/Sleek/SleekProgress.cs:
# a background image, a foreground image scaled by `state`, and a centered label.
# Also mirrors ERoundingMode -> RoundingMode and the `suffix` / `measure` mode.

enum RoundingMode { ROUND, FLOOR, CEIL }

var rounding_mode := RoundingMode.ROUND

var _suffix := ""
var suffix: String:
	get:
		return _suffix
	set(value):
		_suffix = value
		_apply()

var _state := 0.0
var state: float:
	get:
		return _state
	set(value):
		_state = clampf(value, 0.0, 1.0)
		_apply()

var _bar_color := SleekTheme.ACCENT
var bar_color: Color:
	get:
		return _bar_color
	set(value):
		_bar_color = value
		_apply()

var _measure := 0
var measure: int:
	get:
		return _measure
	set(value):
		_measure = value
		_apply()

var _background: ColorRect
var _foreground: ColorRect
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(80, 14)
	_build()
	_apply()

func _build() -> void:
	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_foreground = ColorRect.new()
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_foreground)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", SleekTheme.TEXT)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

func _apply() -> void:
	if _foreground == null:
		return
	_foreground.anchor_left = 0.0
	_foreground.anchor_top = 0.0
	_foreground.anchor_right = _state
	_foreground.anchor_bottom = 1.0
	_foreground.offset_left = 0.0
	_foreground.offset_top = 0.0
	_foreground.offset_right = 0.0
	_foreground.offset_bottom = 0.0
	if _background != null:
		_background.color = Color(_bar_color.r, _bar_color.g, _bar_color.b, 0.45)
	_foreground.color = _bar_color
	if _label != null:
		_label.text = _format_value()

func _format_value() -> String:
	if _suffix.is_empty():
		var percent := _state * 100.0
		match rounding_mode:
			RoundingMode.FLOOR:
				return "%d%%" % int(floor(percent))
			RoundingMode.CEIL:
				return "%d%%" % int(ceil(percent))
			_:
				return "%d%%" % int(round(percent))
	return "%d%s" % [_measure, _suffix]

# Convenience for HUD code written against the previous ProgressBar-based draft.
func set_amount(current: float, maximum: float) -> void:
	state = current / maximum if maximum > 0.0 else 0.0

func set_suffix(value: String) -> void:
	suffix = value
	_apply()

func set_rounding_mode(value: int) -> void:
	rounding_mode = value
	_apply()

func get_label_text() -> String:
	return _label.text if _label != null else ""
