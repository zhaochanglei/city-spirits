extends Node
class_name MonsterDatabase

var monsters: Array[Dictionary] = []


func load_from_file(path: String = Constants.MONSTER_DATA_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open monster data: %s" % path)
		monsters = []
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Monster data must be a JSON array: %s" % path)
		monsters = []
		return false

	var loaded: Array[Dictionary] = []
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var monster := _normalize_monster(entry)
		if not str(monster.get("id", "")).is_empty():
			loaded.append(monster)

	monsters = loaded
	return not monsters.is_empty()


func get_all_monsters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for monster in monsters:
		result.append(monster.duplicate(true))
	return result


func get_monster_by_id(monster_id: String) -> Dictionary:
	for monster in monsters:
		if monster.get("id", "") == monster_id:
			return monster.duplicate(true)

	return {}


func _normalize_monster(raw_monster: Dictionary) -> Dictionary:
	return {
		"id": str(raw_monster.get("id", "")),
		"name": str(raw_monster.get("name", "")),
		"rarity": str(raw_monster.get("rarity", "common")),
		"base_capture_rate": float(raw_monster.get("base_capture_rate", 0.4)),
		"hint": str(raw_monster.get("hint", ""))
	}
