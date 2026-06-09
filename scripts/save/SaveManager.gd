extends Node

var save_path := Constants.SAVE_COLLECTION_PATH
var data: Dictionary = {}
var last_load_used_fallback := false


func _ready() -> void:
	load_data()


func get_default_data() -> Dictionary:
	return {
		"version": 1,
		"captured_monsters": []
	}


func load_data() -> Dictionary:
	last_load_used_fallback = false

	if not FileAccess.file_exists(save_path):
		data = get_default_data()
		save_data(data)
		return data.duplicate(true)

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read save file. Falling back to default save: %s" % save_path)
		return _fallback_to_default()

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Save file JSON is invalid. Falling back to default save: %s" % save_path)
		return _fallback_to_default()

	data = _normalize_data(json.data)
	return data.duplicate(true)


func save_data(next_data: Dictionary) -> bool:
	_ensure_save_dir()

	data = _normalize_data(next_data)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % save_path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	return true


func get_captured_monsters() -> Array[Dictionary]:
	if data.is_empty():
		load_data()

	var captured: Array[Dictionary] = []
	for monster in data.get("captured_monsters", []):
		if typeof(monster) == TYPE_DICTIONARY:
			captured.append(monster.duplicate(true))
	return captured


func add_captured_monster(monster: Dictionary) -> bool:
	if data.is_empty():
		load_data()

	var normalized := _normalize_captured_monster(monster)
	var monster_id := str(normalized.get("id", ""))
	if monster_id.is_empty() or has_captured_monster(monster_id):
		return false

	var captured: Array = data.get("captured_monsters", [])
	captured.append(normalized)
	data["captured_monsters"] = captured
	return save_data(data)


func has_captured_monster(monster_id: String) -> bool:
	if monster_id.is_empty():
		return false

	for monster in get_captured_monsters():
		if str(monster.get("id", "")) == monster_id:
			return true

	return false


func reset_to_default() -> bool:
	data = get_default_data()
	return save_data(data)


func _fallback_to_default() -> Dictionary:
	last_load_used_fallback = true
	data = get_default_data()
	save_data(data)
	return data.duplicate(true)


func _normalize_data(raw_data: Dictionary) -> Dictionary:
	var normalized := get_default_data()
	normalized["version"] = int(raw_data.get("version", 1))

	var captured: Array[Dictionary] = []
	var raw_captured: Variant = raw_data.get("captured_monsters", [])
	if typeof(raw_captured) == TYPE_ARRAY:
		for monster in raw_captured:
			if typeof(monster) == TYPE_DICTIONARY:
				var normalized_monster := _normalize_captured_monster(monster)
				if not str(normalized_monster.get("id", "")).is_empty():
					captured.append(normalized_monster)

	normalized["captured_monsters"] = captured
	return normalized


func _normalize_captured_monster(monster: Dictionary) -> Dictionary:
	return {
		"id": str(monster.get("id", "")),
		"name": str(monster.get("name", "")),
		"rarity": str(monster.get("rarity", "common")),
		"base_capture_rate": float(monster.get("base_capture_rate", 0.35)),
		"captured_at_unix": int(monster.get("captured_at_unix", Time.get_unix_time_from_system()))
	}


func _ensure_save_dir() -> void:
	var base_dir := save_path.get_base_dir()
	if base_dir.begins_with("user://"):
		var absolute_dir := ProjectSettings.globalize_path(base_dir)
		DirAccess.make_dir_recursive_absolute(absolute_dir)
