extends Node
class_name PlayerVoice

# U3 PlayerVoice equivalent for local single-player: an event table of voice
# clips (hurt/death/equip/attack...) played through one AudioStreamPlayer3D.
# Events are emitted as signals even when no audio player is wired, so headless
# tests and subtitle systems can observe them.

signal voice_started(stream: AudioStream)
signal voice_finished
signal voice_event(event_id: StringName, stream: AudioStream)

@export var player_path: NodePath = ^"../VoiceAudio"
@export var max_distance := 24.0
@export var voice_bus: StringName = &"Voice"
@export var default_pitch := 1.0
@export var event_cooldown := 0.15
var muted := false

var _player: AudioStreamPlayer3D
var _events: Dictionary = {}
var _next_event_msec: Dictionary = {}
var _last_health := -1.0

func _ready() -> void:
	_resolve_player()

func _resolve_player() -> void:
	_player = get_node_or_null(player_path) as AudioStreamPlayer3D
	if _player != null:
		_player.max_distance = max_distance
		_player.bus = voice_bus
		if not _player.finished.is_connected(_on_finished):
			_player.finished.connect(_on_finished)

func bind_player(new_player: AudioStreamPlayer3D) -> void:
	_player = new_player
	_resolve_player()

func register_event(event_id: StringName, stream: AudioStream) -> void:
	if event_id.is_empty() or stream == null: return
	_events[event_id] = stream

func register_events(events: Dictionary) -> void:
	for event_id in events:
		register_event(StringName(event_id), events[event_id] as AudioStream)

func has_event(event_id: StringName) -> bool:
	return _events.has(event_id)

func get_event(event_id: StringName) -> AudioStream:
	return _events.get(event_id)

func play_event(event_id: StringName, pitch_scale := 1.0) -> bool:
	if muted: return false
	var stream := get_event(event_id)
	if stream == null: return false
	var now := Time.get_ticks_msec()
	if now < int(_next_event_msec.get(event_id, 0)): return false
	_next_event_msec[event_id] = now + int(maxf(event_cooldown, 0.0) * 1000.0)
	_play_stream(stream, pitch_scale)
	voice_event.emit(event_id, stream)
	return true

func speak(stream: AudioStream, pitch_scale := 1.0) -> bool:
	if muted or stream == null: return false
	_play_stream(stream, pitch_scale)
	return true

func stop_speaking() -> void:
	if _player != null: _player.stop()

func set_muted(value: bool) -> void:
	muted = value
	if muted: stop_speaking()

func bind_life(life: PlayerLife) -> void:
	if life == null: return
	if not life.health_changed.is_connected(_on_health_changed):
		life.health_changed.connect(_on_health_changed)
	if not life.died.is_connected(_on_died):
		life.died.connect(_on_died)
	_last_health = life.health

func bind_equipment(equipment: PlayerEquipment) -> void:
	if equipment == null: return
	if not equipment.equipped.is_connected(_on_equipped):
		equipment.equipped.connect(_on_equipped)

func _play_stream(stream: AudioStream, pitch_scale: float) -> void:
	if _player != null:
		_player.stream = stream
		_player.pitch_scale = pitch_scale * default_pitch
		_player.play()
	voice_started.emit(stream)

func _on_finished() -> void:
	voice_finished.emit()

func _on_health_changed(value: float) -> void:
	if _last_health >= 0.0 and value < _last_health:
		play_event(&"hurt")
	_last_health = value

func _on_died() -> void:
	play_event(&"death")

func _on_equipped(_slot: StringName, _item_id: StringName) -> void:
	play_event(&"equip")
