extends Node

var current_mode := ""
var current_scene_path := ""
var captured_spirits: Array[String] = []
var captured_monsters: Array[Dictionary] = []
var selected_monster: Dictionary = {}


func _ready() -> void:
	call_deferred("load_collection")


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
	return has_captured_monster(spirit_id)


func load_collection() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		captured_monsters = []
		captured_spirits = []
		return

	captured_monsters = save_manager.get_captured_monsters()
	_sync_captured_spirit_ids()
	EventBus.collection_updated.emit()


func add_captured_monster(monster: Dictionary) -> bool:
	var monster_id := str(monster.get("id", ""))
	if monster_id.is_empty():
		return false

	var save_manager := get_node_or_null("/root/SaveManager")
	var added := false
	if save_manager != null:
		added = save_manager.add_captured_monster(monster)
		captured_monsters = save_manager.get_captured_monsters()
	else:
		added = _append_runtime_monster(monster)

	_sync_captured_spirit_ids()
	if added:
		EventBus.spirit_collected.emit(monster_id)
		EventBus.collection_updated.emit()
	return added


func get_captured_monsters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for monster in captured_monsters:
		result.append(monster.duplicate(true))
	return result


func has_captured_monster(monster_id: String) -> bool:
	if monster_id.is_empty():
		return false

	for monster in captured_monsters:
		if str(monster.get("id", "")) == monster_id:
			return true

	return captured_spirits.has(monster_id)


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


func _append_runtime_monster(monster: Dictionary) -> bool:
	var monster_id := str(monster.get("id", ""))
	if has_captured_monster(monster_id):
		return false

	captured_monsters.append(monster.duplicate(true))
	return true


func _sync_captured_spirit_ids() -> void:
	captured_spirits = []
	for monster in captured_monsters:
		var monster_id := str(monster.get("id", ""))
		if not monster_id.is_empty() and not captured_spirits.has(monster_id):
			captured_spirits.append(monster_id)
