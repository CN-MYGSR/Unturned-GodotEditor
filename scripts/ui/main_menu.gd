extends Control
class_name MainMenu

# 原版 Unturned 主菜单布局的 Godot 迁移版：
#   Menu.unity -> MenuTitleUI（顶部标题/版本）
#   MenuDashboardUI（左侧 Play / Survivors / Configuration / Workshop / Exit + 右侧新闻面板）
# 参考 U3-SDK：UI/Menu/MenuTitleUI.cs、MenuDashboardUI.cs。

const GAME_SCENE := "res://scenes/main.tscn"
const BACKGROUND_PATH := "res://screenshot_main.png"

const MENU_LEFT := 10.0
const BUTTON_WIDTH := 200.0
const BUTTON_HEIGHT := 50.0
const CONTENT_LEFT := 220.0

var title_label: SleekLabel
var author_label: SleekLabel
var version_label: SleekLabel
var stat_button: SleekButton

var play_button: SleekButton
var survivors_button: SleekButton
var configuration_button: SleekButton
var workshop_button: SleekButton
var exit_button: SleekButton

var content_panel: SleekPanel
var content_title: SleekLabel
var content_body: Label

var page_backdrop: ColorRect
var page_panel: SleekPanel
var page_title: SleekLabel
var page_body: Label
var close_page_button: SleekButton

var _stat_index := 0
var _stat_lines := [
	"资源迁移：POLYGON 士兵 / KayKit 骷髅 / Unturned 角色与僵尸",
	"地图：原版资产地图 · 40 × 40m · 昼夜环境",
	"版本：Godot 4.7.2 · 本地单机原型 · U3-SDK 参考",
	"操作：WASD 移动 · Shift 冲刺 · E 交互 · TAB 背包",
]

var _selected_map := 0
var _map_buttons: Array[SleekButton] = []

# 官方地图列表来自 Unturned 安装目录的 Localization/Schinese/Maps/*.dat。
# scene 为空的官方地图需要先把地图资产导入 Godot（当前工程里没有原版地图文件）。
const MAP_CATALOG := [
	{"id": "local", "name": "原版资产地图", "difficulty": "本地", "scene": "res://scenes/main.tscn", "available": true, "preview": "res://screenshot_main.png",
		"description": "本地可玩的原版迁移资产地图：POLYGON 士兵 / KayKit 骷髅 / Unturned 角色与僵尸，可拾取长矛、衬衫、步枪、弹匣、红点、握把与消音器。"},
	{"id": "pei", "name": "PEI", "difficulty": "新手", "scene": "res://scenes/maps/pei.tscn", "available": true, "preview": "res://data/maps/PEI/preview.png",
		"description": "加拿大东海岸上的阳光之岛。这里的几个平民小镇有着小型的驻军。旅游景点包括海滩、城堡和帆船。推荐新的幸存者进入。"},
	{"id": "washington", "name": "Washington", "difficulty": "进阶", "scene": "", "available": false,
		"description": "加拿大西南方向的多雨国家。这里有几个大型民用城镇以及广泛的驻军。旅游景点包括西雅图、高尔夫球场和赛车场。推荐经验较为丰富的幸存者进入。"},
	{"id": "yukon", "name": "Yukon", "difficulty": "困难", "scene": "", "available": false,
		"description": "处于加拿大西北部，是一块荒芜且被冻结着的领土。贫瘠冰冻的荒原上散落着一些营地和小木屋。旅游景点包括滑雪场、滑冰场和已定位的火车。推荐经验丰富的幸存者进入。"},
	{"id": "russia", "name": "Russia", "difficulty": "进阶", "scene": "", "available": false,
		"description": "邻国为加拿大的多生物群系国家。平民拥有着巨大的多样性。目的地有着不同的驻军。旅游景点包括历史古迹、风景如画的乡村和攀岩地点。推荐经验丰富的幸存者进入。"},
	{"id": "germany", "name": "Germany", "difficulty": "进阶", "scene": "", "available": false,
		"description": "位于加拿大北部的多山国家。现代化的城市有着活跃的军事活动。旅游景点包括令人惊叹的美景、徒步旅行的高山小道和当地的啤酒节。推荐经验较为丰富的幸存者进入。"},
	{"id": "alpha_valley", "name": "Alpha Valley", "difficulty": "PvP", "scene": "", "available": false,
		"description": "在战斗中成为最后站在 3.0 更新后创建的第一个地图的团队吧！推荐经验丰富的幸存者进入。"},
	{"id": "monolith", "name": "Monolith", "difficulty": "PvP", "scene": "", "available": false,
		"description": "在战斗中成为最后站在慢慢地被迫到神殿的中心的一个圆形竞技场的团队吧！推荐有经验的幸存者进入。"},
	{"id": "paintball", "name": "Paintball Arena", "difficulty": "PvP", "scene": "", "available": false,
		"description": "在战斗中成为最后站在一个奇异的彩色积木的团队吧！不论谁建造了它，都必须一直吃浆果才能建成。推荐经验丰富的幸存者进入。"},
	{"id": "destruction", "name": "Destruction", "difficulty": "测试", "scene": "", "available": false,
		"description": "所有物体被转换为支持破坏的演示地图。爆炸就是艺术！将一切核平吧。"},
	{"id": "tutorial", "name": "Tutorial", "difficulty": "教学", "scene": "", "available": false,
		"description": "Unturned 的新手教学地图：学习移动、采集、制作与生存基础。"},
]

var play_backdrop: ColorRect
var play_panel: SleekPanel
var map_grid: GridContainer
var map_preview: TextureRect
var map_title_label: SleekLabel
var map_meta_label: SleekLabel
var map_desc_label: Label
var map_status_label: SleekLabel
var map_start_button: SleekButton
var map_back_button: SleekButton
var map_close_button: SleekButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	for argument in OS.get_cmdline_args():
		if argument == "--map=pei" or argument == "--pei":
			call_deferred("_start_pei_map")
			break

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if play_panel != null and play_panel.visible:
			_on_map_start_pressed()
		else:
			_open_play_menu()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		if play_panel != null and play_panel.visible:
			_close_play_menu()
			get_viewport().set_input_as_handled()
		elif page_panel != null and page_panel.visible:
			_hide_page()
			get_viewport().set_input_as_handled()

func _build() -> void:
	_build_background()
	_build_title()
	_build_stat_button()
	_build_left_buttons()
	_build_content_panel()
	_build_page_overlay()
	_build_play_overlay()

func _build_background() -> void:
	var background := TextureRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture: Texture2D = load(BACKGROUND_PATH)
	if texture != null:
		background.texture = texture
	add_child(background)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.05, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

func _build_title() -> void:
	var title_box := SleekPanel.new()
	title_box.name = "TitleBox"
	title_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_box.offset_left = MENU_LEFT
	title_box.offset_right = -MENU_LEFT
	title_box.offset_top = MENU_LEFT
	title_box.offset_bottom = 110.0
	add_child(title_box)

	var title_content := Control.new()
	title_content.name = "TitleContent"
	title_box.add_child(title_content)

	title_label = SleekLabel.new()
	title_label.name = "TitleLabel"
	title_label.text = "UNTURNED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_bottom = 70.0
	title_content.add_child(title_label)
	title_label.add_theme_font_size_override("font_size", 58)

	author_label = SleekLabel.new()
	author_label.name = "AuthorLabel"
	author_label.text = "by Smartly Dressed Games · Godot 4.7 迁移版"
	author_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	author_label.offset_top = 64.0
	author_label.offset_bottom = 96.0
	author_label.set_font_size(SleekTheme.FontSize.SMALL)
	author_label.set_text_color(SleekTheme.MUTED)
	title_content.add_child(author_label)

	version_label = SleekLabel.new()
	version_label.name = "VersionLabel"
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.8.0"))
	version_label.set_font_size(SleekTheme.FontSize.SMALL)
	version_label.set_text_color(SleekTheme.MUTED)
	version_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version_label.offset_left = -180.0
	version_label.offset_top = 10.0
	version_label.offset_right = -14.0
	version_label.offset_bottom = 38.0
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_content.add_child(version_label)

func _build_stat_button() -> void:
	stat_button = SleekButton.new()
	stat_button.name = "StatButton"
	stat_button.text = _stat_lines[0]
	stat_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stat_button.offset_left = MENU_LEFT
	stat_button.offset_right = -MENU_LEFT
	stat_button.offset_top = 120.0
	stat_button.offset_bottom = 160.0
	stat_button.pressed.connect(_on_stat_pressed)
	add_child(stat_button)

func _build_left_buttons() -> void:
	play_button = _make_button("PLAY", 170.0, _open_play_menu)
	play_button.name = "PlayButton"
	play_button.set_accent(true)

	survivors_button = _make_button("SURVIVORS", 230.0, _on_survivors_pressed)
	survivors_button.name = "SurvivorsButton"

	configuration_button = _make_button("CONFIGURATION", 290.0, _on_configuration_pressed)
	configuration_button.name = "ConfigurationButton"

	workshop_button = _make_button("WORKSHOP", 350.0, _on_workshop_pressed)
	workshop_button.name = "WorkshopButton"

	exit_button = _make_button("EXIT", -50.0, _quit_game)
	exit_button.name = "ExitButton"
	exit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	exit_button.offset_left = MENU_LEFT
	exit_button.offset_top = -60.0
	exit_button.offset_right = MENU_LEFT + BUTTON_WIDTH
	exit_button.offset_bottom = -10.0

func _make_button(label: String, y: float, callback: Callable) -> SleekButton:
	var button := SleekButton.new()
	button.text = label
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = MENU_LEFT
	button.offset_top = y
	button.offset_right = MENU_LEFT + BUTTON_WIDTH
	button.offset_bottom = y + BUTTON_HEIGHT
	button.add_theme_font_size_override("font_size", SleekTheme.font_size(SleekTheme.FontSize.MEDIUM))
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build_content_panel() -> void:
	content_panel = SleekPanel.new()
	content_panel.name = "NewsPanel"
	content_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_panel.offset_left = CONTENT_LEFT
	content_panel.offset_top = 170.0
	content_panel.offset_right = -MENU_LEFT
	content_panel.offset_bottom = -MENU_LEFT
	add_child(content_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	content_panel.add_child(layout)

	content_title = SleekLabel.new()
	content_title.text = "GODOT MIGRATION · 原版资产地图"
	content_title.set_font_size(SleekTheme.FontSize.LARGE)
	layout.add_child(content_title)

	var divider := HSeparator.new()
	layout.add_child(divider)

	content_body = Label.new()
	content_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_body.add_theme_color_override("font_color", SleekTheme.MUTED)
	content_body.text = "欢迎回来，幸存者。\n\n原版 Unturned 资产已迁移：角色 / 僵尸 / 武器 / 载具 / 场景模型。\n当前地图为原版资产地图（40 × 40m），包含可操控玩家、拾取物与基础僵尸。\n\n· PLAY  开始游戏\n· SURVIVORS  幸存者与技能\n· CONFIGURATION  配置\n· WORKSHOP  创意工坊\n· EXIT  退出\n\n提示：主菜单布局参考 U3-SDK MenuTitleUI / MenuDashboardUI；多人、Steam 与创意工坊尚未接入。"
	layout.add_child(content_body)

func _build_page_overlay() -> void:
	page_backdrop = ColorRect.new()
	page_backdrop.name = "PageBackdrop"
	page_backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	page_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	page_backdrop.visible = false
	add_child(page_backdrop)

	page_panel = SleekPanel.new()
	page_panel.name = "PagePanel"
	SleekLayout.apply(page_panel, Vector2(-320, -220), Vector2(0.5, 0.5), Vector2(640, 440), Vector2.ZERO)
	page_panel.visible = false
	add_child(page_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	page_panel.add_child(layout)

	page_title = SleekLabel.new()
	page_title.set_font_size(SleekTheme.FontSize.LARGE)
	layout.add_child(page_title)

	var divider := HSeparator.new()
	layout.add_child(divider)

	page_body = Label.new()
	page_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_body.add_theme_color_override("font_color", SleekTheme.MUTED)
	layout.add_child(page_body)

	close_page_button = SleekButton.new()
	close_page_button.name = "ClosePageButton"
	close_page_button.text = "返回 BACK"
	close_page_button.set_accent(true)
	close_page_button.custom_minimum_size = Vector2(0, 44)
	close_page_button.pressed.connect(_hide_page)
	layout.add_child(close_page_button)

func _show_page(title: String, body: String) -> void:
	page_title.text = title
	page_body.text = body
	page_panel.visible = true
	page_backdrop.visible = true

func _hide_page() -> void:
	page_panel.visible = false
	page_backdrop.visible = false

func _on_stat_pressed() -> void:
	_stat_index = (_stat_index + 1) % _stat_lines.size()
	stat_button.text = _stat_lines[_stat_index]

func _on_survivors_pressed() -> void:
	_show_page("SURVIVORS · 幸存者", "角色外观、技能树、任务与背包页面已迁移基础数据层。\n\n完整角色编辑器依赖 U3 的 Steam 库存 / 服务器权威数据，当前为本地单机原型，暂未接入。")

func _on_configuration_pressed() -> void:
	_show_page("CONFIGURATION · 配置", "音频、画质、按键绑定页面尚未迁移。\n\n当前使用项目默认设置：1280 × 720，Forward+ 渲染，鼠标锁定由游戏场景控制。")

func _on_workshop_pressed() -> void:
	_show_page("WORKSHOP · 创意工坊", "Steam 创意工坊尚未接入。\n\n迁移资产通过本地 assets/（POLYGON / KayKit / Unturned）与 data/ JSON 加载；后续可通过 U3 的 Workshop 元数据格式继续扩展。")

func _build_play_overlay() -> void:
	play_backdrop = ColorRect.new()
	play_backdrop.name = "PlayBackdrop"
	play_backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	play_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	play_backdrop.visible = false
	add_child(play_backdrop)

	play_panel = SleekPanel.new()
	play_panel.name = "PlayPanel"
	SleekLayout.apply(play_panel, Vector2(-510, -320), Vector2(0.5, 0.5), Vector2(1020, 640), Vector2.ZERO)
	play_panel.visible = false
	add_child(play_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	play_panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var header_label := SleekLabel.new()
	header_label.text = "PLAY · SELECT MAP / 选择地图"
	header_label.set_font_size(SleekTheme.FontSize.LARGE)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_label)

	map_close_button = SleekButton.new()
	map_close_button.name = "MapCloseButton"
	map_close_button.text = "返回"
	map_close_button.custom_minimum_size = Vector2(100, 36)
	map_close_button.pressed.connect(_close_play_menu)
	header.add_child(map_close_button)

	var divider := HSeparator.new()
	layout.add_child(divider)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	map_grid = GridContainer.new()
	map_grid.name = "MapGrid"
	map_grid.columns = 3
	map_grid.add_theme_constant_override("h_separation", 8)
	map_grid.add_theme_constant_override("v_separation", 8)
	map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(map_grid)

	var detail := VBoxContainer.new()
	detail.name = "MapDetail"
	detail.custom_minimum_size = Vector2(320, 0)
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)

	map_preview = TextureRect.new()
	map_preview.name = "MapPreview"
	map_preview.custom_minimum_size = Vector2(0, 180)
	map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_preview.visible = false
	detail.add_child(map_preview)

	map_title_label = SleekLabel.new()
	map_title_label.text = "选择地图"
	map_title_label.set_font_size(SleekTheme.FontSize.LARGE)
	detail.add_child(map_title_label)

	map_meta_label = SleekLabel.new()
	map_meta_label.set_font_size(SleekTheme.FontSize.SMALL)
	map_meta_label.set_text_color(SleekTheme.ACCENT)
	detail.add_child(map_meta_label)

	map_desc_label = Label.new()
	map_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_desc_label.add_theme_color_override("font_color", SleekTheme.MUTED)
	detail.add_child(map_desc_label)

	map_status_label = SleekLabel.new()
	map_status_label.set_font_size(SleekTheme.FontSize.SMALL)
	detail.add_child(map_status_label)

	map_start_button = SleekButton.new()
	map_start_button.name = "MapStartButton"
	map_start_button.text = "开始游戏 START"
	map_start_button.set_accent(true)
	map_start_button.custom_minimum_size = Vector2(0, 48)
	map_start_button.pressed.connect(_on_map_start_pressed)
	detail.add_child(map_start_button)

	var hint := SleekLabel.new()
	hint.text = "PEI 已导入原版地形/出生点；其余官方地图需要先导入对应原版地图资产。"
	hint.set_font_size(SleekTheme.FontSize.SMALL)
	hint.set_text_color(SleekTheme.MUTED)
	layout.add_child(hint)

	for index in MAP_CATALOG.size():
		var entry: Dictionary = MAP_CATALOG[index]
		var card := SleekButton.new()
		card.custom_minimum_size = Vector2(200, 64)
		card.text = "%s · %s" % [str(entry["name"]), str(entry["difficulty"])]
		card.add_theme_font_size_override("font_size", SleekTheme.font_size(SleekTheme.FontSize.SMALL))
		card.pressed.connect(_select_map.bind(index))
		map_grid.add_child(card)
		_map_buttons.append(card)

	_select_map(0)

func _open_play_menu() -> void:
	if play_panel == null:
		return
	play_panel.visible = true
	play_backdrop.visible = true
	_select_map(_selected_map)

func _close_play_menu() -> void:
	if play_panel == null:
		return
	play_panel.visible = false
	play_backdrop.visible = false

func _select_map(index: int) -> void:
	if MAP_CATALOG.is_empty():
		return
	_selected_map = clampi(index, 0, MAP_CATALOG.size() - 1)
	for button_index in _map_buttons.size():
		_map_buttons[button_index].set_accent(button_index == _selected_map)

	var entry: Dictionary = MAP_CATALOG[_selected_map]
	map_title_label.text = str(entry["name"])
	map_meta_label.text = "难度：%s · 来源：Unturned 原版地图列表" % str(entry["difficulty"])
	map_desc_label.text = str(entry["description"])
	var preview_path: String = str(entry.get("preview", ""))
	if not preview_path.is_empty() and ResourceLoader.exists(preview_path):
		map_preview.texture = load(preview_path)
		map_preview.visible = true
	else:
		map_preview.texture = null
		map_preview.visible = false

	var available: bool = bool(entry.get("available", false))
	var scene_path: String = str(entry.get("scene", ""))
	if available and not scene_path.is_empty():
		map_status_label.text = "✓ 可游玩：已导入原版地图"
		map_status_label.set_text_color(SleekTheme.ACCENT)
		map_start_button.set_clickable(true)
	else:
		map_status_label.text = "⚠ 缺少原版地图资产：需要 Unturned 地图文件并导入 Godot"
		map_status_label.set_text_color(SleekTheme.DANGER)
		map_start_button.set_clickable(false)

func _on_map_start_pressed() -> void:
	if map_start_button == null or not map_start_button.is_clickable():
		return
	var entry: Dictionary = MAP_CATALOG[_selected_map]
	var scene_path: String = str(entry.get("scene", ""))
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)

func _start_game() -> void:
	_on_map_start_pressed()

func _start_pei_map() -> void:
	if ResourceLoader.exists("res://scenes/maps/pei.tscn"):
		get_tree().change_scene_to_file("res://scenes/maps/pei.tscn")

func _quit_game() -> void:
	get_tree().quit()





