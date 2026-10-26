extends "res://scripts/sleek/sleek_button.gd"
class_name SleekSlot

# One reusable inventory/hotbar cell.
# Merges the behaviour of Unturned/Sleek/SleekSlot.cs (dashboard grid cell) and
# Unturned/Sleek/SleekHotbarEntry.cs (hotbar entry: hotkey + equipped state):
#   - icon, stack amount, quality bar, fallback name label
#   - hotkey label + equipped highlight (HOTBAR mode)
#   - selected border (INVENTORY mode)
# The slot is data-driven through SleekItemStack only, so it can be dropped into
# any SleekInventory grid without knowing what the grid is displaying.

signal slot_pressed(slot_index: int)
signal slot_activated(slot_index: int)
signal slot_secondary(slot_index: int, screen_position: Vector2)

enum DisplayMode { INVENTORY, HOTBAR }

const ICON_INSET := 6.0

var slot_index := -1
var display_mode := DisplayMode.INVENTORY
var hotkey_text := ""
var stack: SleekItemStack = null
var selected := false
var equipped := false

var _icon: SleekImage
var _name_label: Label
var _amount_label: Label
var _hotkey_label: Label
var _quality_bar: ColorRect
var _selection: Panel

func _ready() -> void:
	background_color = SleekTheme.BACKGROUND
	super._ready()
	text = ""
	clip_text = true
	_build_children()
	pressed.connect(_on_slot_pressed)
	gui_input.connect(_on_gui_input)
	_refresh()

func _build_children() -> void:
	_icon = SleekImage.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = ICON_INSET
	_icon.offset_top = ICON_INSET
	_icon.offset_right = -ICON_INSET
	_icon.offset_bottom = -ICON_INSET
	add_child(_icon)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", SleekTheme.TEXT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_label.offset_left = 4.0
	_name_label.offset_top = 4.0
	_name_label.offset_right = -4.0
	_name_label.offset_bottom = -16.0
	add_child(_name_label)

	_amount_label = Label.new()
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_amount_label.add_theme_font_size_override("font_size", 11)
	_amount_label.add_theme_color_override("font_color", SleekTheme.TEXT)
	_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_amount_label.offset_left = 4.0
	_amount_label.offset_top = 4.0
	_amount_label.offset_right = -6.0
	_amount_label.offset_bottom = -4.0
	add_child(_amount_label)

	_hotkey_label = Label.new()
	_hotkey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hotkey_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hotkey_label.add_theme_font_size_override("font_size", 11)
	_hotkey_label.add_theme_color_override("font_color", SleekTheme.MUTED)
	_hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotkey_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hotkey_label.offset_left = 4.0
	_hotkey_label.offset_top = 2.0
	_hotkey_label.offset_right = -4.0
	_hotkey_label.offset_bottom = -10.0
	_hotkey_label.visible = false
	add_child(_hotkey_label)

	_quality_bar = ColorRect.new()
	_quality_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quality_bar.anchor_left = 0.0
	_quality_bar.anchor_top = 1.0
	_quality_bar.anchor_right = 1.0
	_quality_bar.anchor_bottom = 1.0
	_quality_bar.offset_left = 6.0
	_quality_bar.offset_top = -5.0
	_quality_bar.offset_right = -6.0
	_quality_bar.offset_bottom = -2.0
	_quality_bar.visible = false
	add_child(_quality_bar)

	_selection = Panel.new()
	_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection.visible = false
	add_child(_selection)

func _refresh() -> void:
	var has_item := has_stack()
	if _icon != null:
		_icon.visible = has_item and stack.icon != null
		_icon.texture = stack.icon if (_icon.visible) else null
	if _name_label != null:
		_name_label.visible = has_item and stack.icon == null
		_name_label.text = stack.display_name if has_item else ""
	if _amount_label != null:
		_amount_label.text = "×%d" % stack.amount if (has_item and stack.amount > 1) else ""
	if _quality_bar != null:
		_quality_bar.visible = has_item and stack.has_quality()
		if _quality_bar.visible:
			_quality_bar.color = SleekTheme.quality_color(stack.quality)
	if _hotkey_label != null:
		_hotkey_label.text = hotkey_text
		_hotkey_label.visible = display_mode == DisplayMode.HOTBAR and not hotkey_text.is_empty()
	tooltip_text = _build_tooltip(has_item)
	_refresh_selection()

func _build_tooltip(has_item: bool) -> String:
	if not has_item:
		return ""
	if stack.description.is_empty():
		return stack.display_name
	return "%s\n%s" % [stack.display_name, stack.description]

func _refresh_selection() -> void:
	if _selection == null:
		return
	if selected:
		_selection.add_theme_stylebox_override("panel", SleekTheme.selection_style(SleekTheme.ACCENT))
		_selection.visible = true
	elif equipped:
		_selection.add_theme_stylebox_override("panel", SleekTheme.selection_style(SleekTheme.TEXT))
		_selection.visible = true
	else:
		_selection.visible = false

func set_slot_index(value: int) -> void:
	slot_index = value

func set_display_mode(value: int) -> void:
	display_mode = value
	_refresh()

func set_stack(new_stack: SleekItemStack) -> void:
	stack = new_stack
	_refresh()

func clear_stack() -> void:
	set_stack(null)

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	_refresh_selection()

func set_equipped(value: bool) -> void:
	if equipped == value:
		return
	equipped = value
	_refresh_selection()

func set_hotkey_text(value: String) -> void:
	hotkey_text = value
	if _hotkey_label != null:
		_hotkey_label.text = value
		_hotkey_label.visible = display_mode == DisplayMode.HOTBAR and not value.is_empty()

func has_stack() -> bool:
	return stack != null and not stack.is_empty()

func get_amount_text() -> String:
	return _amount_label.text if _amount_label != null else ""

func get_hotkey_text() -> String:
	return _hotkey_label.text if _hotkey_label != null else ""

func _on_slot_pressed() -> void:
	slot_pressed.emit(slot_index)
	if has_stack():
		slot_activated.emit(slot_index)

func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		slot_secondary.emit(slot_index, get_global_mouse_position())
