extends Node

var current_mode := ""
var current_scene_path := ""
var captured_spirits: Array[String] = []
var selected_monster: Dictionary = {}


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


func select_monster(monster: Dictionary) -> void:
	selected_monster = monster.duplicate(true)
	var monster_id := str(selected_monster.get("id", ""))
	EventBus.monster_selected.emit(monster_id)
	EventBus.capture_started.emit(monster_id)


func get_selected_monster() -> Dictionary:
	return selected_monster.duplicate(true)


func clear_selected_monster() -> void:
	selected_monster = {}


func reset_session() -> void:
	current_mode = ""
	current_scene_path = ""
	selected_monster = {}
