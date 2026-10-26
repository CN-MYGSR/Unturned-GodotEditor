extends CanvasLayer
class_name GameHUD

# Thin composition root for the player UI.
# Port boundary from Unturned/Player/PlayerUI.cs + PlayerLifeUI.cs:
#   - owns the SleekWindow root and the GameUIManager
#   - instantiates the HUD and the screens, and wires player signals
#   - routes input (TAB / ESC / hotbar keys) and cursor state
# It deliberately contains no inventory layout or item logic: those live in
# InventoryScreen, PlayerHUD and the reusable scripts/sleek widgets.

@export var life_path: NodePath = ^"../Player/Life"
@export var inventory_path: NodePath = ^"../Player/Inventory"
@export var player_path: NodePath = ^"../Player"
@export var equipment_path: NodePath = ^"../Player/Equipment"

var life: PlayerLife
var inventory: PlayerInventory
var player_controller: PlayerController
var equipment: PlayerEquipment
var inventory_model: PlayerInventoryModel
var ui_manager: GameUIManager
var window: SleekWindow
var hud: PlayerHUD
var inventory_screen: InventoryScreen
var pause_screen: PauseScreen
var death_screen: DeathScreen

var _focused_interactable: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	bind_player(get_node_or_null(life_path) as PlayerLife, get_node_or_null(inventory_path) as PlayerInventory)
	bind_player_controller(get_node_or_null(player_path) as PlayerController)
	bind_equipment(get_node_or_null(equipment_path) as PlayerEquipment)
	_sync_mouse_mode()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_TAB:
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE:
		_handle_escape()
		get_viewport().set_input_as_handled()
	elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		_select_hotbar(key_event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_0:
		_select_hotbar(9)
		get_viewport().set_input_as_handled()

# Gameplay input for the equipped firearm: LMB primary, RMB aim, R reload,
# V fire mode. Only while the cursor is captured and no screen is open.
func _unhandled_input(event: InputEvent) -> void:
	if ui_manager == null or not ui_manager.active_screen.is_empty() or equipment == null:
		return
	if event is InputEventMouseButton and _is_mouse_captured():
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				equipment.primary_down(player_controller)
			else:
				equipment.primary_up()
			get_viewport().set_input_as_handled()
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			if mouse.pressed:
				equipment.secondary_down(player_controller)
			else:
				equipment.secondary_up(player_controller)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo: return
		if key.keycode == KEY_R:
			equipment.reload(player_controller)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_V:
			equipment.toggle_firemode(player_controller)
			get_viewport().set_input_as_handled()

func _is_mouse_captured() -> bool:
	return DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _build_interface() -> void:
	window = SleekWindow.new()
	window.name = "SleekWindow"
	add_child(window)

	ui_manager = GameUIManager.new()
	ui_manager.name = "UIManager"
	add_child(ui_manager)
	ui_manager.active_screen_changed.connect(_on_active_screen_changed)

	hud = PlayerHUD.new()
	hud.name = "PlayerHUD"
	window.add_child(hud)
	hud.hotbar.slot_activated.connect(_on_hotbar_activated)

	inventory_screen = InventoryScreen.new()
	inventory_screen.name = "InventoryScreen"
	inventory_screen.item_activated.connect(_use_item)
	inventory_screen.close_requested.connect(close_inventory)
	window.add_child(inventory_screen)

	pause_screen = PauseScreen.new()
	pause_screen.name = "PauseScreen"
	pause_screen.resume_requested.connect(close_pause)
	pause_screen.quit_requested.connect(_quit_game)
	window.add_child(pause_screen)

	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	death_screen.respawn_requested.connect(respawn)
	death_screen.quit_requested.connect(_quit_game)
	window.add_child(death_screen)

	ui_manager.register_screen(&"inventory", inventory_screen)
	ui_manager.register_screen(&"pause", pause_screen)
	ui_manager.register_screen(&"death", death_screen)

func bind_player(new_life: PlayerLife, new_inventory: PlayerInventory) -> void:
	if life != null and life.died.is_connected(_on_player_died):
		life.died.disconnect(_on_player_died)
	life = new_life
	inventory = new_inventory
	if inventory_model == null:
		inventory_model = PlayerInventoryModel.new()
	inventory_model.bind(inventory)
	if hud != null:
		hud.bind_life(life)
		hud.bind_inventory_model(inventory_model)
	if inventory_screen != null:
		inventory_screen.bind_inventory(inventory)
		inventory_screen.bind_model(inventory_model)
	if equipment != null:
		equipment.bind_inventory(inventory)
	if life != null and not life.died.is_connected(_on_player_died):
		life.died.connect(_on_player_died)

func bind_equipment(new_equipment: PlayerEquipment) -> void:
	if equipment != null:
		if equipment.equipment_changed.is_connected(_on_equipment_changed):
			equipment.equipment_changed.disconnect(_on_equipment_changed)
		if equipment.weapon_changed.is_connected(_on_weapon_changed):
			equipment.weapon_changed.disconnect(_on_weapon_changed)
		if equipment.ammo_changed.is_connected(_on_ammo_changed):
			equipment.ammo_changed.disconnect(_on_ammo_changed)
		if equipment.firemode_changed.is_connected(_on_firemode_changed):
			equipment.firemode_changed.disconnect(_on_firemode_changed)
		if equipment.aiming_changed.is_connected(_on_aiming_changed):
			equipment.aiming_changed.disconnect(_on_aiming_changed)
		if equipment.recoil_applied.is_connected(_on_recoil_applied):
			equipment.recoil_applied.disconnect(_on_recoil_applied)
	equipment = new_equipment
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)
		equipment.weapon_changed.connect(_on_weapon_changed)
		equipment.ammo_changed.connect(_on_ammo_changed)
		equipment.firemode_changed.connect(_on_firemode_changed)
		equipment.aiming_changed.connect(_on_aiming_changed)
		equipment.recoil_applied.connect(_on_recoil_applied)
		equipment.bind_inventory(inventory)
		if inventory_screen != null:
			inventory_screen.bind_equipment(equipment)
	_refresh_weapon_label()

func bind_player_controller(new_controller: PlayerController) -> void:
	if player_controller != null and player_controller.focused_interactable_changed.is_connected(_on_focused_interactable_changed):
		player_controller.focused_interactable_changed.disconnect(_on_focused_interactable_changed)
	player_controller = new_controller
	if player_controller != null:
		if not player_controller.focused_interactable_changed.is_connected(_on_focused_interactable_changed):
			player_controller.focused_interactable_changed.connect(_on_focused_interactable_changed)
		_focused_interactable = player_controller.focused_interactable
	_refresh_prompt()

func get_active_screen() -> StringName:
	return ui_manager.active_screen if ui_manager != null else &""

func toggle_inventory() -> void:
	if ui_manager.active_screen == &"pause" or ui_manager.active_screen == &"death":
		return
	ui_manager.toggle_screen(&"inventory")
	_refresh_prompt()

func open_inventory() -> void:
	if ui_manager.active_screen == &"pause" or ui_manager.active_screen == &"death":
		return
	ui_manager.open_screen(&"inventory")
	_refresh_prompt()

func close_inventory() -> void:
	ui_manager.close_screen(&"inventory")
	_refresh_prompt()

func open_pause() -> void:
	if ui_manager.active_screen == &"death":
		return
	if ui_manager.open_screen(&"pause"):
		get_tree().paused = true
	_refresh_prompt()

func close_pause() -> void:
	ui_manager.close_screen(&"pause")
	get_tree().paused = false
	_refresh_prompt()

func respawn() -> void:
	ui_manager.close_screen(&"death")
	get_tree().paused = false
	if life != null:
		life.respawn()
	_refresh_prompt()

func _handle_escape() -> void:
	match ui_manager.active_screen:
		&"pause":
			close_pause()
		&"inventory":
			close_inventory()
		&"death":
			pass
		_:
			open_pause()

func _select_hotbar(index: int) -> void:
	if hud != null:
		hud.hotbar.select(index)
	if inventory == null:
		return
	if index < 0 or index >= inventory.hotbar.size():
		return
	var inventory_slot := int(inventory.hotbar[index])
	if inventory_slot < 0:
		return
	inventory.set_active_slot(inventory_slot)
	if equipment != null:
		equipment.equip_from_inventory(inventory_slot)

# Mirrors equipment state onto the HUD hotbar (SleekSlot equipped highlight).
func _on_equipment_changed() -> void:
	if hud == null or inventory == null or equipment == null:
		return
	for hotbar_index in mini(inventory.hotbar.size(), hud.hotbar.get_slot_count()):
		var inventory_slot := int(inventory.hotbar[hotbar_index])
		if inventory_slot < 0 or inventory_slot >= inventory.slots.size():
			hud.hotbar.get_slot(hotbar_index).set_equipped(false)
			continue
		var item_id := StringName(inventory.slots[inventory_slot].get("item_id", ""))
		hud.hotbar.get_slot(hotbar_index).set_equipped(equipment.is_equipped(item_id))

func _on_hotbar_activated(slot_index: int) -> void:
	if inventory_model == null:
		return
	var stack := inventory_model.get_stack(slot_index)
	if stack != null and not stack.is_empty():
		_use_item(stack.item_id)

# ---------------------------------------------------------------------------
# Firearm HUD / camera feedback
# ---------------------------------------------------------------------------

func _on_weapon_changed(_item_id: StringName) -> void:
	_refresh_weapon_label()

func _on_ammo_changed(_ammo: int, _capacity: int) -> void:
	_refresh_weapon_label()

func _on_firemode_changed(_mode: int, _mode_name: StringName) -> void:
	_refresh_weapon_label()

func _on_aiming_changed(aiming: bool, zoom: float) -> void:
	if player_controller != null:
		player_controller.set_aim(aiming, zoom)

func _on_recoil_applied(amount: Vector2) -> void:
	if player_controller != null:
		player_controller.apply_recoil(amount)

func _refresh_weapon_label() -> void:
	if hud == null: return
	var gun := equipment.get_active_gun() if equipment != null else null
	if gun == null:
		hud.set_weapon_status("")
		return
	hud.set_weapon_status("%s   %d / %d   [%s]" % [gun.get_gun().display_name, gun.get_ammo(), gun.get_capacity(), _firemode_label(gun.get_firemode())])

func _firemode_label(mode: int) -> String:
	match mode:
		GunDefinition.FireMode.SAFETY: return "保险"
		GunDefinition.FireMode.SEMI: return "半自动"
		GunDefinition.FireMode.AUTO: return "全自动"
		GunDefinition.FireMode.BURST: return "点射"
	return "半自动"

func _use_item(item_id: StringName) -> void:
	if inventory == null or life == null or life.is_dead:
		return
	var actor: Node = player_controller if player_controller != null else life
	inventory.use_item(item_id, actor)

func _on_player_died() -> void:
	close_pause()
	ui_manager.open_screen(&"death")
	_refresh_prompt()

func _on_focused_interactable_changed(target: Node3D) -> void:
	_focused_interactable = target
	_refresh_prompt()

func _on_active_screen_changed(screen_name: StringName) -> void:
	_sync_mouse_mode()
	if hud != null:
		hud.visible = screen_name.is_empty()
	_refresh_prompt()

func _refresh_prompt() -> void:
	if hud == null:
		return
	var ui_open := ui_manager != null and not ui_manager.active_screen.is_empty()
	var can_focus := _focused_interactable != null and is_instance_valid(_focused_interactable) and bool(_focused_interactable.get("interaction_enabled")) and _focused_interactable.has_method("check_hint")
	if ui_open or not can_focus:
		hud.set_interaction_prompt("")
		return
	var hint: Dictionary = _focused_interactable.call("check_hint", player_controller)
	if not bool(hint.get("visible", false)):
		hud.set_interaction_prompt("")
		return
	hud.set_interaction_prompt("[E] " + str(hint.get("text", _focused_interactable.get("interaction_name"))), hint.get("color", Color.WHITE))

func _sync_mouse_mode() -> void:
	var should_show_cursor := ui_manager != null and not ui_manager.active_screen.is_empty()
	_set_mouse_mode(Input.MOUSE_MODE_VISIBLE if should_show_cursor else Input.MOUSE_MODE_CAPTURED)

func _set_mouse_mode(mode: int) -> void:
	# Headless test runs have no DisplayServer mouse to lock.
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = mode

func _quit_game() -> void:
	get_tree().quit()


