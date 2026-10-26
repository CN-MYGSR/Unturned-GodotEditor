extends Node3D
## 启动后等待若干帧完成渲染，把视口截图存到项目根目录，然后退出。
## 用法：Godot --path <项目> --quit-after 120  （配合本脚本挂到主场景根节点）

const SHOT_PATH := "res://screenshot_main.png"
const WARMUP_FRAMES := 12

var _frames := 0

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return
	# Stop processing before quitting from inside a frame callback; deferred quit
	# avoids shutdown races when this script is used for headless boot checks.
	set_process(false)
	# Headless runs have no viewport texture to capture; exit cleanly so scene
	# boot checks (`--headless --quit-after N`) do not report false errors.
	if DisplayServer.get_name() == "headless":
		call_deferred("_quit")
		return
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	if err == OK:
		print("[SHOT] saved: ", SHOT_PATH, "  size=", img.get_width(), "x", img.get_height())
	else:
		print("[SHOT] failed err=", err)
	call_deferred("_quit")

func _quit() -> void:
	get_tree().quit(0)
