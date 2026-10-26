extends "res://scripts/sleek/sleek_panel.gd"
class_name SleekBox

# GDScript port of SDG.Glazier/SleekBox.cs (ISleekBox : ISleekLabel):
# a panel with an optional centered text label.

var _label: Label = null
var _text := ""

var text: String:
	get:
		return _text
	set(value):
		_text = value
		_refresh_text()

func _ready() -> void:
	super._ready()
	_refresh_text()

func _refresh_text() -> void:
	if _text.is_empty():
		if _label != null:
			_label.visible = false
		return
	_ensure_label()
	if _label != null:
		_label.visible = true
		_label.text = _text

func _ensure_label() -> void:
	if _label != null or not is_inside_tree():
		return
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)

func set_text(value: String) -> void:
	text = value
