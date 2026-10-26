extends SceneTree

# 原版风格主菜单测试：标题、侧边按钮、新闻面板、子页面、开始游戏切换地图。

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/main_menu.tscn", "project starts in the main menu")
	_check(ResourceLoader.exists("res://scenes/main.tscn"), "original asset map scene exists")
	_check(ResourceLoader.exists("res://scenes/maps/pei.tscn"), "PEI original map scene exists")
	_check(FileAccess.file_exists("res://data/maps/PEI/height.bin"), "PEI heightmap data exists")
	_check(not ResourceLoader.exists("res://scenes/survival_test.tscn"), "old test map scene is removed")
	_check(MainMenu.GAME_SCENE == "res://scenes/main.tscn", "main menu starts the original asset map")

	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	_check(menu_scene != null, "main menu scene loads")
	if menu_scene == null:
		_finish()
		return
	var menu := menu_scene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame

	# U3 MenuTitleUI / MenuDashboardUI layout
	_check(menu.title_label != null and menu.title_label.text == "UNTURNED", "title shows UNTURNED")
	_check(menu.author_label != null and menu.author_label.text.contains("Godot"), "author line shows migration credit")
	_check(menu.version_label != null and menu.version_label.text.contains("0.8"), "version label shows project version")
	_check(menu.play_button != null and menu.play_button.text == "PLAY", "dashboard has PLAY button")
	_check(menu.survivors_button != null, "dashboard has SURVIVORS button")
	_check(menu.configuration_button != null, "dashboard has CONFIGURATION button")
	_check(menu.workshop_button != null, "dashboard has WORKSHOP button")
	_check(menu.exit_button != null, "dashboard has EXIT button")
	_check(menu.stat_button != null and not menu.stat_button.text.is_empty(), "stat ticker is populated")
	_check(menu.content_panel != null and menu.content_title != null, "news/content panel is built")

	# Page overlays (original dashboard opens sub-screens)
	_check(menu.page_panel != null and not menu.page_panel.visible, "sub page starts hidden")
	menu._on_survivors_pressed()
	_check(menu.page_panel.visible and menu.page_title.text.contains("SURVIVORS"), "SURVIVORS opens a sub page")
	menu._hide_page()
	_check(not menu.page_panel.visible, "sub page closes")
	menu._on_configuration_pressed()
	_check(menu.page_panel.visible and menu.page_title.text.contains("CONFIGURATION"), "CONFIGURATION opens a sub page")
	menu._hide_page()

	# Stat ticker cycles like U3 MenuTitleUI
	var first_stat: String = menu.stat_button.text
	menu._on_stat_pressed()
	_check(menu.stat_button.text != first_stat, "stat ticker cycles entries")

	# PLAY -> map select -> local map
	menu._open_play_menu()
	_check(menu.play_panel != null and menu.play_panel.visible, "PLAY opens the map selection screen")
	_check(menu._map_buttons.size() >= 5, "map selection lists official Unturned maps")
	menu._select_map(1)
	_check(menu.map_start_button.is_clickable(), "PEI original map can start")
	_check(menu.map_status_label.text.contains("可游玩"), "PEI is reported as playable")
	_check(menu.map_preview.visible, "PEI preview image is shown")
	menu._select_map(2)
	_check(not menu.map_start_button.is_clickable(), "official maps without assets cannot start")
	_check(menu.map_status_label.text.contains("缺少"), "missing official map assets are reported")
	menu._select_map(0)
	_check(menu.map_start_button.is_clickable(), "local original-asset map can start")
	menu._close_play_menu()
	_check(not menu.play_panel.visible, "map selection closes")

	# PLAY transitions into the map
	menu._start_game()
	await process_frame
	await process_frame
	await process_frame
	_check(root.get_node_or_null("OriginalMap") != null, "PLAY switches to the original asset map")
	menu.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("Main menu tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error("Main menu test failed: " + failure)
	quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


