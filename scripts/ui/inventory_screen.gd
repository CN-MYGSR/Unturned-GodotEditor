extends UIScreen
class_name InventoryScreen

# GDScript port of the inventory page of
# Unturned/UI/Player/PlayerDashboardInventoryUI.cs:
#   - backpack slot wall (reusable SleekInventory control)
#   - capacity/weight summary from the view model
#   - item detail panel with use/equip/attach actions
#   - U3 Inventory equipment slots (primary/secondary/melee/clothing)
#   - attachment slots of the equipped firearm (sight/grip/tactical/barrel/magazine)
# The screen owns all inventory presentation; GameHUD only opens/closes it and
# reacts to item_activated.

signal item_activated(item_id: StringName)

const GRID_COLUMNS := 6
const EQUIPMENT_COLUMNS := 5
const ATTACHMENT_COLUMNS := 5

var model: SleekInventoryModel
var inventory: PlayerInventory
var equipment: PlayerEquipment
var equipment_model: PlayerEquipmentModel
var attachment_model: PlayerAttachmentModel
var grid: SleekInventory
var equipment_grid: SleekInventory
var attachment_grid: SleekInventory
var title_label: SleekLabel
var capacity_label: SleekLabel
var detail_name: SleekLabel
var detail_description: Label
var use_button: SleekButton
var equipment_label: SleekLabel
var attachment_label: SleekLabel
var close_button: SleekButton

var _selected_index := -1

func _ready() -> void:
	super._ready()
	_build()

func open() -> void:
	super.open()
	_refresh_all()

func bind_inventory(new_inventory: PlayerInventory) -> void:
	inventory = new_inventory
	if equipment != null:
		refresh_equipment()
	_refresh_all()

func bind_model(new_model: SleekInventoryModel) -> void:
	if model != null and model.changed.is_connected(_on_model_changed):
		model.changed.disconnect(_on_model_changed)
	model = new_model
	_selected_index = -1
	if model != null:
		if not model.changed.is_connected(_on_model_changed):
			model.changed.connect(_on_model_changed)
		if grid != null:
			grid.bind_model(model)
		if title_label != null:
			title_label.text = model.get_display_name()
	_refresh_all()

func bind_equipment(new_equipment: PlayerEquipment) -> void:
	if equipment != null and is_instance_valid(equipment):
		if equipment.equipment_changed.is_connected(_on_equipment_changed):
			equipment.equipment_changed.disconnect(_on_equipment_changed)
		if equipment.weapon_changed.is_connected(_on_weapon_changed):
			equipment.weapon_changed.disconnect(_on_weapon_changed)
		if equipment.attachment_changed.is_connected(_on_attachment_changed):
			equipment.attachment_changed.disconnect(_on_attachment_changed)
	equipment = new_equipment
	if equipment != null and is_instance_valid(equipment):
		equipment.equipment_changed.connect(_on_equipment_changed)
		equipment.weapon_changed.connect(_on_weapon_changed)
		equipment.attachment_changed.connect(_on_attachment_changed)
	refresh_equipment()
	_refresh_all()

func refresh_equipment() -> void:
	if equipment_model != null:
		equipment_model.bind(null)
	if attachment_model != null:
		attachment_model.bind(null)
	if equipment == null:
		equipment_model = null
		attachment_model = null
		return
	equipment_model = PlayerEquipmentModel.new(equipment)
	attachment_model = PlayerAttachmentModel.new(equipment)
	if equipment_grid != null:
		equipment_grid.bind_model(equipment_model)
	if attachment_grid != null:
		attachment_grid.bind_model(attachment_model)

func _exit_tree() -> void:
	if equipment != null and is_instance_valid(equipment):
		if equipment.equipment_changed.is_connected(_on_equipment_changed):
			equipment.equipment_changed.disconnect(_on_equipment_changed)
		if equipment.weapon_changed.is_connected(_on_weapon_changed):
			equipment.weapon_changed.disconnect(_on_weapon_changed)
		if equipment.attachment_changed.is_connected(_on_attachment_changed):
			equipment.attachment_changed.disconnect(_on_attachment_changed)
	if equipment_model != null:
		equipment_model.bind(null)
	if attachment_model != null:
		attachment_model.bind(null)

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = SleekTheme.SCREEN_DIM
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := SleekPanel.new()
	panel.corner_radius = 10
	SleekLayout.apply(panel, Vector2(-450, -310), Vector2(0.5, 0.5), Vector2(900, 620), Vector2.ZERO)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	title_label = SleekLabel.new()
	title_label.text = "背包"
	title_label.set_font_size(SleekTheme.FontSize.LARGE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	close_button = SleekButton.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	capacity_label = SleekLabel.new()
	capacity_label.set_font_size(SleekTheme.FontSize.SMALL)
	capacity_label.set_text_color(SleekTheme.MUTED)
	layout.add_child(capacity_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var scroll := SleekScrollBox.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	grid = SleekInventory.new()
	grid.columns = GRID_COLUMNS
	grid.slot_size = Vector2(76, 76)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.slot_pressed.connect(_on_slot_pressed)
	grid.slot_activated.connect(_on_slot_activated)
	scroll.add_element(grid)

	var detail := SleekPanel.new()
	detail.custom_minimum_size = Vector2(360, 0)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail)

	var detail_layout := VBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 6)
	detail.add_child(detail_layout)

	detail_name = SleekLabel.new()
	detail_name.text = "未选择"
	detail_name.set_font_size(SleekTheme.FontSize.MEDIUM)
	detail_layout.add_child(detail_name)

	detail_description = Label.new()
	detail_description.text = "点击左侧格位查看物品。"
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.custom_minimum_size.y = 44
	detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_description.add_theme_color_override("font_color", SleekTheme.MUTED)
	detail_layout.add_child(detail_description)

	use_button = SleekButton.new()
	use_button.text = "使用"
	use_button.set_accent(true)
	use_button.set_clickable(false)
	use_button.pressed.connect(_on_use_pressed)
	detail_layout.add_child(use_button)

	equipment_label = SleekLabel.new()
	equipment_label.text = "装备"
	equipment_label.set_font_size(SleekTheme.FontSize.SMALL)
	equipment_label.set_text_color(SleekTheme.MUTED)
	detail_layout.add_child(equipment_label)

	equipment_grid = SleekInventory.new()
	equipment_grid.columns = EQUIPMENT_COLUMNS
	equipment_grid.slot_size = Vector2(56, 56)
	equipment_grid.slot_activated.connect(_on_equipment_slot_activated)
	detail_layout.add_child(equipment_grid)

	attachment_label = SleekLabel.new()
	attachment_label.text = "附件"
	attachment_label.set_font_size(SleekTheme.FontSize.SMALL)
	attachment_label.set_text_color(SleekTheme.MUTED)
	detail_layout.add_child(attachment_label)

	attachment_grid = SleekInventory.new()
	attachment_grid.columns = ATTACHMENT_COLUMNS
	attachment_grid.slot_size = Vector2(56, 56)
	attachment_grid.slot_activated.connect(_on_attachment_slot_activated)
	detail_layout.add_child(attachment_grid)

func _refresh_all() -> void:
	if capacity_label != null:
		capacity_label.text = model.get_display_summary() if model != null else ""
	if model != null and _selected_index >= model.get_slot_capacity():
		_selected_index = -1
		if grid != null:
			grid.select(-1)
	_refresh_detail()
	_refresh_equipment_summary()

func _refresh_equipment_summary() -> void:
	if equipment_label != null:
		equipment_label.text = "装备  ·  " + equipment_model.get_display_summary() if equipment_model != null else "装备"
	if attachment_label != null:
		attachment_label.text = "附件  ·  " + attachment_model.get_display_summary() if attachment_model != null else "附件"

func _refresh_detail() -> void:
	var stack: SleekItemStack = model.get_stack(_selected_index) if model != null else null
	var has_item := stack != null and not stack.is_empty()
	var definition := _definition_for(stack.item_id) if has_item else null
	if detail_name != null:
		detail_name.text = stack.display_name if has_item else "未选择"
	if detail_description != null:
		if not has_item:
			detail_description.text = "点击左侧格位查看物品。"
		else:
			var lines: PackedStringArray = []
			if not stack.description.is_empty(): lines.append(stack.description)
			lines.append("数量 ×%d" % stack.amount)
			if definition is AttachmentDefinition:
				var attachment := definition as AttachmentDefinition
				lines.append("附件类型：%s" % _attachment_kind_label(attachment.kind))
			elif definition is GunDefinition:
				var gun := definition as GunDefinition
				lines.append("伤害 %.0f · 射程 %.0f m" % [gun.damage, gun.range])
			elif definition != null and definition.is_equipment():
				lines.append("可装备到：%s" % String(definition.equipment_slot))
			detail_description.text = "\n".join(lines)
	if use_button != null:
		var enabled := has_item
		var label := "使用"
		if definition is AttachmentDefinition:
			label = "安装附件"
			enabled = equipment != null and equipment.get_active_gun() != null
		elif definition != null and definition.is_equipment():
			label = "装备"
		use_button.text = label
		use_button.set_clickable(enabled)

func _definition_for(item_id: StringName) -> ItemDefinition:
	if inventory == null: return null
	return inventory.definitions.get(item_id) as ItemDefinition

func _actor() -> Node3D:
	if equipment == null or not is_instance_valid(equipment): return null
	return equipment.get_parent() as Node3D

func _attachment_kind_label(kind: int) -> String:
	match kind:
		AttachmentDefinition.Kind.SIGHT: return "瞄具"
		AttachmentDefinition.Kind.GRIP: return "握把"
		AttachmentDefinition.Kind.TACTICAL: return "战术"
		AttachmentDefinition.Kind.BARREL: return "枪管"
		AttachmentDefinition.Kind.MAGAZINE: return "弹匣"
	return "未知"

func _on_model_changed() -> void:
	_refresh_all()

func _on_slot_pressed(index: int) -> void:
	_selected_index = index
	_refresh_detail()

func _on_slot_activated(index: int) -> void:
	_selected_index = index
	_activate_selected_item()

func _on_use_pressed() -> void:
	_activate_selected_item()

func _activate_selected_item() -> void:
	if model == null:
		return
	var stack: SleekItemStack = model.get_stack(_selected_index)
	if stack == null or stack.is_empty():
		return
	var definition := _definition_for(stack.item_id)
	if definition is AttachmentDefinition:
		if equipment == null or not is_instance_valid(equipment): return
		equipment.attach_attachment((definition as AttachmentDefinition).kind_name(), stack.item_id, _actor())
		_refresh_all()
		return
	if definition != null and definition.is_equipment():
		if equipment == null or not is_instance_valid(equipment): return
		equipment.equip_from_inventory(_selected_index)
		_refresh_all()
		return
	item_activated.emit(stack.item_id)

func _on_equipment_slot_activated(index: int) -> void:
	if equipment == null or not is_instance_valid(equipment) or equipment_model == null: return
	var slot := equipment_model.slot_for_index(index)
	if slot.is_empty(): return
	equipment.unequip(slot)
	_refresh_all()

func _on_attachment_slot_activated(index: int) -> void:
	if equipment == null or not is_instance_valid(equipment) or attachment_model == null: return
	var kind := attachment_model.kind_for_index(index)
	if kind.is_empty(): return
	equipment.detach_attachment(kind, _actor())
	_refresh_all()

func _on_equipment_changed() -> void:
	if equipment != null and not is_instance_valid(equipment):
		equipment = null
	_refresh_all()

func _on_weapon_changed(_item_id: StringName) -> void:
	_refresh_all()

func _on_attachment_changed(_kind: StringName, _attachment_id: StringName) -> void:
	_refresh_all()

func _on_close_pressed() -> void:
	request_close()


