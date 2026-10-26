extends UIScreen
class_name DeathScreen

# GDScript port of the death screen subset of
# Unturned/UI/Player/PlayerDeathUI.cs (respawn / quit).

signal respawn_requested
signal quit_requested

func _ready() -> void:
	super._ready()
	_build()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.16, 0.02, 0.02, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := SleekPanel.new()
	SleekLayout.apply(panel, Vector2(-220, -130), Vector2(0.5, 0.5), Vector2(440, 260), Vector2.ZERO)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title := SleekLabel.new()
	title.text = "你死了"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_font_size(SleekTheme.FontSize.MAX)
	title.set_text_color(SleekTheme.DANGER)
	layout.add_child(title)

	var note := SleekLabel.new()
	note.text = "生命值归零。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.set_font_size(SleekTheme.FontSize.SMALL)
	note.set_text_color(SleekTheme.MUTED)
	layout.add_child(note)

	var respawn := SleekButton.new()
	respawn.text = "重生"
	respawn.set_accent(true)
	respawn.custom_minimum_size.y = 40
	respawn.pressed.connect(_on_respawn_pressed)
	layout.add_child(respawn)

	var quit := SleekButton.new()
	quit.text = "退出游戏"
	quit.custom_minimum_size.y = 40
	quit.pressed.connect(_on_quit_pressed)
	layout.add_child(quit)

func _on_respawn_pressed() -> void:
	respawn_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()
