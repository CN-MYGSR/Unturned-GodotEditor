extends UIScreen
class_name PauseScreen

# GDScript port of the pause menu subset of Unturned/UI/Player/PlayerPauseUI.cs
# (return to game + quit). Music/audio/options tabs are out of migration scope.

signal resume_requested
signal quit_requested

func _ready() -> void:
	super._ready()
	_build()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = SleekTheme.SCREEN_DIM
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := SleekPanel.new()
	SleekLayout.apply(panel, Vector2(-150, -170), Vector2(0.5, 0.5), Vector2(300, 340), Vector2.ZERO)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title := SleekLabel.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_font_size(SleekTheme.FontSize.LARGE)
	layout.add_child(title)

	var resume := SleekButton.new()
	resume.text = "返回游戏"
	resume.set_accent(true)
	resume.custom_minimum_size.y = 40
	resume.pressed.connect(_on_resume_pressed)
	layout.add_child(resume)

	var quit := SleekButton.new()
	quit.text = "退出游戏"
	quit.custom_minimum_size.y = 40
	quit.pressed.connect(_on_quit_pressed)
	layout.add_child(quit)

	var note := SleekLabel.new()
	note.text = "本地生存测试"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.set_font_size(SleekTheme.FontSize.SMALL)
	note.set_text_color(SleekTheme.MUTED)
	layout.add_child(note)

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()
