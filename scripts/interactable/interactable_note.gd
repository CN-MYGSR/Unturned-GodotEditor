extends Interactable
class_name InteractableNote

signal note_opened(actor: Node3D, text: String, note: InteractableNote)
signal quest_object_activated(actor: Node3D, note: InteractableNote)

@export_multiline var note_text := ""
@export var quest_object_id: StringName
@export var require_closed_ui := true

func can_interact(actor: Node3D) -> bool:
	return super.can_interact(actor) and (not require_closed_ui or not bool(actor.get_meta("ui_cursor_visible", false)))

func check_hint(actor: Node3D = null) -> Dictionary:
	var allowed := actor == null or not require_closed_ui or not bool(actor.get_meta("ui_cursor_visible", false))
	return {"visible": allowed, "text": interaction_name, "color": highlight_color}

func use(actor: Node3D) -> bool:
	note_opened.emit(actor, note_text, self)
	if not quest_object_id.is_empty():
		quest_object_activated.emit(actor, self)
		var services := get_node_or_null("/root/GameServices")
		if services != null:
			services.request_quest(&"activate_object", {"object_id": quest_object_id, "actor": str(actor.get_path())})
	return true

