extends ScrollContainer
class_name SleekScrollBox

# GDScript port of SDG.Glazier/SleekScrollBox.cs (ISleekScrollView):
#   AddChild / RemoveAllChildren -> add_element / remove_all_elements

var content: VBoxContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ensure_content()

func _ensure_content() -> void:
	if content != null:
		return
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	add_child(content)

func add_element(element: Control) -> void:
	_ensure_content()
	content.add_child(element)

func remove_all_elements() -> void:
	_ensure_content()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func get_content() -> VBoxContainer:
	_ensure_content()
	return content
