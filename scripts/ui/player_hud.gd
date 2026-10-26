extends Control
class_name PlayerHUD

# GDScript port of the always-visible in-game HUD subset of
# Unturned/UI/Player/PlayerLifeUI.cs: life/food/water bars, crosshair, hotbar and
# the interaction prompt. It only *presents* state; gameplay decisions
# (using items, opening screens, pausing) stay in scripts/ui/game_hud.gd.

var life: PlayerLife
var inventory_model: SleekInventoryModel

var health_bar: SleekProgress
var food_bar: SleekProgress
var water_bar: SleekProgress
var stamina_bar: SleekProgress
var hotbar: SleekHotbar
var crosshair: Label
var prompt_label: SleekLabel
var hint_label: SleekLabel
var weapon_label: SleekLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func bind_life(new_life: PlayerLife) -> void:
	if life != null:
		if life.health_changed.is_connected(_on_health_changed):
			life.health_changed.disconnect(_on_health_changed)
		if life.food_changed.is_connected(_on_food_changed):
			life.food_changed.disconnect(_on_food_changed)
		if life.water_changed.is_connected(_on_water_changed):
			life.water_changed.disconnect(_on_water_changed)
		if life.stamina_changed.is_connected(_on_stamina_changed):
			life.stamina_changed.disconnect(_on_stamina_changed)
	life = new_life
	if life != null:
		life.health_changed.connect(_on_health_changed)
		life.food_changed.connect(_on_food_changed)
		life.water_changed.connect(_on_water_changed)
		life.stamina_changed.connect(_on_stamina_changed)
		_on_health_changed(life.health)
		_on_food_changed(life.food)
		_on_water_changed(life.water)
		_on_stamina_changed(life.stamina)
	elif health_bar != null and food_bar != null and water_bar != null and stamina_bar != null:
		health_bar.set_amount(0.0, 1.0)
		food_bar.set_amount(0.0, 1.0)
		water_bar.set_amount(0.0, 1.0)
		stamina_bar.set_amount(0.0, 1.0)

func bind_inventory_model(new_model: SleekInventoryModel) -> void:
	inventory_model = new_model
	if hotbar != null:
		hotbar.bind_model(inventory_model)

func set_interaction_prompt(text: String, color: Color = SleekTheme.ACCENT) -> void:
	if prompt_label == null:
		return
	prompt_label.text = text
	prompt_label.set_text_color(color)
	prompt_label.visible = not text.is_empty()

func set_interaction_hint(text: String, color: Color = SleekTheme.MUTED) -> void:
	if hint_label == null:
		return
	hint_label.text = text
	hint_label.set_text_color(color)
	hint_label.visible = not text.is_empty()

func set_weapon_status(text: String, color: Color = SleekTheme.TEXT) -> void:
	if weapon_label == null:
		return
	weapon_label.text = text
	weapon_label.set_text_color(color)
	weapon_label.visible = not text.is_empty()
func _build() -> void:
	_build_status_panel()
	_build_crosshair()
	_build_hotbar()
	_build_prompt()
	_build_hint()
	_build_weapon_status()

func _build_status_panel() -> void:
	var status := SleekPanel.new()
	SleekLayout.apply(status, Vector2(24, -176), Vector2(0.0, 1.0), Vector2(282, 152), Vector2.ZERO)
	add_child(status)
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 8)
	status.add_child(rows)
	health_bar = _add_status_row(rows, "生命", SleekTheme.COLOR_R)
	food_bar = _add_status_row(rows, "饥饿", SleekTheme.COLOR_O)
	water_bar = _add_status_row(rows, "口渴", SleekTheme.COLOR_B)
	stamina_bar = _add_status_row(rows, "耐力", SleekTheme.COLOR_Y)

func _add_status_row(parent: VBoxContainer, title: String, color: Color) -> SleekProgress:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := SleekLabel.new()
	label.text = title
	label.custom_minimum_size.x = 44
	label.set_font_size(SleekTheme.FontSize.SMALL)
	row.add_child(label)
	var bar := SleekProgress.new()
	bar.bar_color = color
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 16
	bar.set_amount(1.0, 1.0)
	row.add_child(bar)
	return bar

func _build_crosshair() -> void:
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.add_theme_color_override("font_color", SleekTheme.TEXT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SleekLayout.apply(crosshair, Vector2(-12, -16), Vector2(0.5, 0.5), Vector2(24, 32), Vector2.ZERO)
	add_child(crosshair)

func _build_hotbar() -> void:
	hotbar = SleekHotbar.new()
	SleekLayout.apply(hotbar, Vector2(-307, -96), Vector2(0.5, 1.0), Vector2(614, 56), Vector2.ZERO)
	add_child(hotbar)

func _build_prompt() -> void:
	prompt_label = SleekLabel.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.set_font_size(SleekTheme.FontSize.MEDIUM)
	SleekLayout.apply(prompt_label, Vector2(-300, -152), Vector2(0.5, 1.0), Vector2(600, 36), Vector2.ZERO)
	add_child(prompt_label)
	prompt_label.visible = false

func _build_hint() -> void:
	hint_label = SleekLabel.new()
	hint_label.text = "[TAB] 背包   [ESC] 暂停   [E] 交互   [R] 换弹   [V] 射击模式"
	hint_label.set_font_size(SleekTheme.FontSize.SMALL)
	hint_label.set_text_color(SleekTheme.MUTED)
	SleekLayout.apply(hint_label, Vector2(24, 24), Vector2.ZERO, Vector2(560, 24), Vector2.ZERO)
	add_child(hint_label)

func _build_weapon_status() -> void:
	weapon_label = SleekLabel.new()
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.set_font_size(SleekTheme.FontSize.MEDIUM)
	SleekLayout.apply(weapon_label, Vector2(-434, 24), Vector2(1.0, 0.0), Vector2(410, 28), Vector2.ZERO)
	add_child(weapon_label)
	weapon_label.visible = false

func _on_health_changed(value: float) -> void:
	if health_bar != null and life != null:
		health_bar.set_amount(value, life.max_health)

func _on_food_changed(value: float) -> void:
	if food_bar != null and life != null:
		food_bar.set_amount(value, life.max_food)

func _on_water_changed(value: float) -> void:
	if water_bar != null and life != null:
		water_bar.set_amount(value, life.max_water)

func _on_stamina_changed(value: float) -> void:
	if stamina_bar != null and life != null:
		stamina_bar.set_amount(value, life.max_stamina)
