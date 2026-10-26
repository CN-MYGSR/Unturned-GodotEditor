extends "res://scripts/sleek/sleek_scroll_box.gd"
class_name SleekList

# GDScript port of Unturned/Sleek/SleekList.cs: a scroll box of entries.

func add_entry(entry: Control) -> void:
	add_element(entry)

func clear_entries() -> void:
	remove_all_elements()
