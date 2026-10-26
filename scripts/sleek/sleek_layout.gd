extends RefCounted
class_name SleekLayout

# GDScript port of the transform contract of SDG.Glazier's ISleekElement:
#   position = parent_size * PositionScale + PositionOffset
#   size     = parent_size * SizeScale     + SizeOffset
# Godot anchors already encode the "scale" part and offsets encode the "offset"
# part, so the mapping is 1:1 and layout numbers from the C# UI code can be
# carried over without translation.
#
# Only use this on controls that are free-positioned (direct children of a plain
# Control / CanvasItem). Container-managed children (VBox/HBox/Grid) must keep
# their normal container layout.

static func apply(control: Control, position_offset := Vector2.ZERO, position_scale := Vector2.ZERO, size_offset := Vector2.ZERO, size_scale := Vector2.ZERO) -> void:
	control.anchor_left = position_scale.x
	control.anchor_top = position_scale.y
	control.anchor_right = position_scale.x + size_scale.x
	control.anchor_bottom = position_scale.y + size_scale.y
	control.offset_left = position_offset.x
	control.offset_top = position_offset.y
	control.offset_right = position_offset.x + size_offset.x
	control.offset_bottom = position_offset.y + size_offset.y

static func apply_centered(control: Control, size: Vector2) -> void:
	apply(control, -size * 0.5, Vector2(0.5, 0.5), size, Vector2.ZERO)

static func apply_full_rect(control: Control, inset := 0.0) -> void:
	apply(control, Vector2(inset, inset), Vector2.ZERO, Vector2(-inset * 2.0, -inset * 2.0), Vector2.ONE)
