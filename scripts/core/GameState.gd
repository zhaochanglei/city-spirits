extends Node

var current_mode := ""
var current_scene_path := ""
var captured_spirits: Array[String] = []


func start_mode(mode: String) -> void:
	current_mode = mode
	EventBus.game_mode_selected.emit(mode)


func set_current_scene(scene_path: String) -> void:
	current_scene_path = scene_path
	EventBus.screen_changed.emit(scene_path)


func add_captured_spirit(spirit_id: String) -> void:
	if spirit_id.is_empty() or captured_spirits.has(spirit_id):
		return

	captured_spirits.append(spirit_id)
	EventBus.spirit_collected.emit(spirit_id)


func has_spirit(spirit_id: String) -> bool:
	return captured_spirits.has(spirit_id)


func reset_session() -> void:
	current_mode = ""
	current_scene_path = ""
