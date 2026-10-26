extends Node
class_name UseableItem

signal use_started(actor: Node, item_id: StringName)
signal use_finished(actor: Node, item_id: StringName, succeeded: bool)

@export var cooldown := 0.25
var _next_use_msec := 0
var consumes_item := false

func can_use(_actor: Node, _definition: ItemDefinition, _state: Dictionary = {}) -> bool:
	return Time.get_ticks_msec() >= _next_use_msec

func use_item(actor: Node, definition: ItemDefinition, _state: Dictionary = {}) -> bool:
	if not can_use(actor, definition): return false
	_next_use_msec = Time.get_ticks_msec() + int(maxf(cooldown, definition.use_cooldown) * 1000.0)
	use_started.emit(actor, definition.item_id)
	use_finished.emit(actor, definition.item_id, true)
	return true

# Presentation port: forwards an animation action + voice event to the player's
# PlayerPresentation node when one is present. Safe no-op in headless tests.
func play_presentation(actor: Node, action: StringName, voice_event: StringName = &"") -> void:
	if actor == null: return
	var presentation := actor.get_node_or_null("Presentation")
	if presentation != null and presentation.has_method("play_action"):
		presentation.call("play_action", action, voice_event)



