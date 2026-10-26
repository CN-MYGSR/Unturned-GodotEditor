extends Interactable
class_name InteractableDialogue

signal dialogue_requested(actor: Node3D, dialogue_id: StringName, target: InteractableDialogue)

@export var dialogue_id: StringName
@export var display_name := ""
@export var unmet_condition_text := ""
@export var required_actor_meta := ""
@export var required_actor_meta_value: Variant

func can_interact(actor: Node3D) -> bool:
	return super.can_interact(actor) and _conditions_met(actor)

func check_hint(actor: Node3D = null) -> Dictionary:
	if actor != null and not _conditions_met(actor):
		return {"visible": not unmet_condition_text.is_empty(), "text": unmet_condition_text, "color": Color.WHITE}
	return {"visible": true, "text": interaction_name, "color": highlight_color}

func use(actor: Node3D) -> bool:
	if dialogue_id.is_empty():
		return false
	dialogue_requested.emit(actor, dialogue_id, self)
	var services := get_node_or_null("/root/GameServices")
	if services != null:
		services.request_dialogue(&"start", {"dialogue_id": dialogue_id, "target": str(get_path()), "actor": str(actor.get_path())})
	return true

func get_dialogue_target_name() -> String:
	return display_name if not display_name.is_empty() else interaction_name

func _conditions_met(actor: Node3D) -> bool:
	if required_actor_meta.is_empty():
		return true
	return actor.has_meta(required_actor_meta) and actor.get_meta(required_actor_meta) == required_actor_meta_value

