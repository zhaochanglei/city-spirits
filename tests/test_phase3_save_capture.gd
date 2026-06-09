extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_run_tests()

	if failures.is_empty():
		print("PHASE3 SAVE CAPTURE TESTS PASS")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var capture_system_script := _load_script("res://scripts/capture/CaptureSystem.gd")
	var save_manager_script := _load_script("res://scripts/save/SaveManager.gd")

	if not failures.is_empty():
		return

	_test_capture_system(capture_system_script)
	_test_save_manager_default_and_persistence(save_manager_script)
	_test_save_manager_corrupt_json_fallback(save_manager_script)


func _load_script(path: String) -> Script:
	var resource := load(path)
	var script := resource as Script
	_assert(script != null, "Expected script to load: %s" % path)
	if script == null:
		return null

	_assert(script.can_instantiate(), "Expected script to compile and instantiate: %s" % path)
	return script


func _test_capture_system(capture_system_script: Script) -> void:
	var capture_system: Object = capture_system_script.new()
	var monster := {
		"id": "mist_imp",
		"name": "雾巷小鬼",
		"base_capture_rate": 0.4,
		"distance_meters": 32.0
	}

	var chance: float = capture_system.get_capture_chance(monster, 1.2)
	_assert(is_equal_approx(chance, 0.48), "Capture chance applies throw multiplier")

	var success: Dictionary = capture_system.attempt_capture(monster, 1.0, 0.2, false)
	_assert(success.get("success", false), "Low roll captures the monster")
	_assert(not success.get("escaped", true), "Successful capture does not mark escaped")

	var failure: Dictionary = capture_system.attempt_capture(monster, 1.0, 0.9, false)
	_assert(not failure.get("success", true), "High roll fails the capture")
	_assert(not failure.get("escaped", true), "Normal failed throw does not mark escaped")

	var escaped: Dictionary = capture_system.attempt_capture(monster, 1.5, 0.9, true)
	_assert(not escaped.get("success", true), "High adventure roll fails the capture")
	_assert(escaped.get("escaped", false), "Adventure failed throw marks monster escaped")


func _test_save_manager_default_and_persistence(save_manager_script: Script) -> void:
	var save_path := "user://save/test_phase3_collection.json"
	_delete_user_file(save_path)

	var save_manager: Node = save_manager_script.new()
	save_manager.save_path = save_path
	root.add_child(save_manager)

	var default_data: Dictionary = save_manager.load_data()
	_assert(default_data.has("captured_monsters"), "Default save has captured_monsters")
	_assert(default_data.get("captured_monsters", []).is_empty(), "Default save starts empty")

	var monster := {
		"id": "mist_imp",
		"name": "雾巷小鬼",
		"rarity": "common",
		"base_capture_rate": 0.4
	}
	save_manager.add_captured_monster(monster)

	var reloaded: Node = save_manager_script.new()
	reloaded.save_path = save_path
	root.add_child(reloaded)

	var captured: Array = reloaded.get_captured_monsters()
	_assert(captured.size() == 1, "Captured monster persists after reload")
	_assert(captured[0].get("id", "") == "mist_imp", "Persisted monster keeps its ID")

	save_manager.free()
	reloaded.free()
	_delete_user_file(save_path)


func _test_save_manager_corrupt_json_fallback(save_manager_script: Script) -> void:
	var save_path := "user://save/test_phase3_corrupt.json"
	_write_user_file(save_path, "{this is not valid json")

	var save_manager: Node = save_manager_script.new()
	save_manager.save_path = save_path
	root.add_child(save_manager)

	var data: Dictionary = save_manager.load_data()
	_assert(data.get("captured_monsters", []).is_empty(), "Corrupt JSON falls back to default data")

	var repaired: Dictionary = _read_json_file(save_path)
	_assert(repaired.has("captured_monsters"), "Corrupt JSON is repaired on disk")

	save_manager.free()
	_delete_user_file(save_path)


func _write_user_file(path: String, text: String) -> void:
	var base_dir := path.get_base_dir()
	if base_dir.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _read_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	return {}


func _delete_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
