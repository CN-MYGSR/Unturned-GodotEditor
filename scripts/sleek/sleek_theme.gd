extends RefCounted
class_name SleekTheme

# GDScript port of the SDG.Glazier palette layer:
#   - SDG.Glazier/SleekCustomization.cs (background / foreground / font / bad)
#   - Unturned/Constants/Palette.cs (COLOR_W..COLOR_P)
#   - Unturned/Tools/ItemTool.cs getQualityColor()
# Values are kept intentionally close to the C# originals so layout/colour
# numbers from the C# UI code can be carried over directly.

const BACKGROUND := Color("171d24")
const PANEL := Color("242d37")
const PANEL_HOVER := Color("303c48")
const PANEL_LIGHT := Color("3d4a58")
const SCREEN_DIM := Color(0.0, 0.0, 0.0, 0.45)
const ACCENT := Color("8caf68")
const TEXT := Color("edf1e8")
const MUTED := Color("aab5bc")
const DANGER := Color("c86b61")

const COLOR_W := Color("b4b4b4")
const COLOR_R := Color("bf1f1f")
const COLOR_G := Color("1f871f")
const COLOR_B := Color("3298c8")
const COLOR_O := Color("ab8019")
const COLOR_Y := Color("dcb413")
const COLOR_P := Color("6a466d")

# Mirrors ESleekFontSize (SDG.Glazier/SleekFontSize.cs).
enum FontSize { SMALL, DEFAULT, MEDIUM, LARGE, MAX }
const FONT_SIZES := [12, 15, 18, 24, 30]

static func font_size(size: int) -> int:
	var index := clampi(size, 0, FONT_SIZES.size() - 1)
	return int(FONT_SIZES[index])

# Port of ItemTool.getQualityColor: red -> yellow -> green.
static func quality_color(quality: float) -> Color:
	var clamped := clampf(quality, 0.0, 1.0)
	if clamped < 0.5:
		return COLOR_R.lerp(COLOR_Y, clamped * 2.0)
	return COLOR_Y.lerp(COLOR_G, (clamped - 0.5) * 2.0)

static func panel_style(color: Color = PANEL, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	return style

static func button_style(color: Color, radius := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style

static func slot_style(color: Color = BACKGROUND, radius := 4) -> StyleBoxFlat:
	var style := button_style(color, radius)
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	return style

static func selection_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
