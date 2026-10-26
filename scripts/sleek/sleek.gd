extends RefCounted
class_name Sleek

# GDScript port of the Glazier.Get().Create*() factory (SDG.Glazier/Glazier.cs).
# Screens are built in code in this project, so this keeps the same construction
# vocabulary as the C# UI code instead of hand-instantiating native Godot nodes.

static func create_panel() -> SleekPanel:
	return SleekPanel.new()

static func create_box(text := "") -> SleekBox:
	var element := SleekBox.new()
	element.text = text
	return element

static func create_label(text := "") -> SleekLabel:
	var element := SleekLabel.new()
	element.text = text
	return element

static func create_button(text := "") -> SleekButton:
	var element := SleekButton.new()
	element.text = text
	return element

static func create_image(texture: Texture2D = null) -> SleekImage:
	var element := SleekImage.new()
	element.texture = texture
	return element

static func create_progress(suffix := "") -> SleekProgress:
	var element := SleekProgress.new()
	element.suffix = suffix
	return element

static func create_scroll_box() -> SleekScrollBox:
	return SleekScrollBox.new()

static func create_list() -> SleekList:
	return SleekList.new()

static func create_toggle(text := "") -> SleekToggle:
	var element := SleekToggle.new()
	element.text = text
	return element

static func create_slider() -> SleekSlider:
	return SleekSlider.new()

static func create_field(text := "") -> SleekField:
	var element := SleekField.new()
	element.text = text
	return element

static func create_slot(slot_index := -1) -> SleekSlot:
	var element := SleekSlot.new()
	element.set_slot_index(slot_index)
	return element

static func create_inventory(columns := 6) -> SleekInventory:
	var element := SleekInventory.new()
	element.columns = columns
	return element

static func create_hotbar() -> SleekHotbar:
	return SleekHotbar.new()
