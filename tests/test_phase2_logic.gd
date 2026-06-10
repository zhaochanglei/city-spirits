extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_run_tests()

	if failures.is_empty():
		print("PHASE2 LOGIC TESTS PASS")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var location_script := _load_script("res://scripts/location/MockLocationService.gd")
	var database_script := _load_script("res://scripts/monsters/MonsterDatabase.gd")
	var spawner_script := _load_script("res://scripts/monsters/MonsterSpawner.gd")
	var radar_math_script := _load_script("res://scripts/radar/RadarUiMath.gd")

	if not failures.is_empty():
		return

	_test_mock_location_service(location_script)
	_test_monster_database(database_script)
	_test_monster_spawner(database_script, spawner_script)
	_test_radar_heading_helpers(radar_math_script)


func _load_script(path: String) -> Script:
	var resource := load(path)
	var script := resource as Script
	_assert(script != null, "Expected script to load: %s" % path)
	if script == null:
		return null

	_assert(script.can_instantiate(), "Expected script to compile and instantiate: %s" % path)
	return script


func _test_mock_location_service(location_script: Script) -> void:
	var location: Object = location_script.new()

	_assert(location.get_current_position() == Vector2.ZERO, "Mock location starts at the origin")

	location.move_by(Vector2(25.0, -10.0))
	_assert(
		location.get_current_position() == Vector2(25.0, -10.0),
		"Mock location moves by the requested delta"
	)

	location.reset()
	_assert(location.get_current_position() == Vector2.ZERO, "Mock location resets to the origin")
	location.free()


func _test_monster_database(database_script: Script) -> void:
	var database: Object = database_script.new()

	_assert(database.load_from_file("res://data/monsters.json"), "Monster database loads JSON data")

	var monsters: Array = database.get_all_monsters()
	_assert(monsters.size() >= 10, "Monster database contains at least 10 templates")

	var found: Dictionary = database.get_monster_by_id("mist_imp")
	_assert(found.get("id", "") == "mist_imp", "Monster database looks up monsters by ID")
	_assert(not found.get("name", "").is_empty(), "Monster templates include display names")
	database.free()


func _test_monster_spawner(database_script: Script, spawner_script: Script) -> void:
	var database: Object = database_script.new()
	database.load_from_file("res://data/monsters.json")

	var spawner: Object = spawner_script.new()
	var spawned: Array = spawner.spawn_monsters(Vector2.ZERO, database.get_all_monsters())

	_assert(spawned.size() >= 5, "Spawner creates at least 5 radar monsters")
	_assert(spawned.size() <= 10, "Spawner creates no more than 10 radar monsters")

	var first: Dictionary = spawned[0]
	_assert(first.has("id"), "Spawned monsters keep template ID")
	_assert(first.has("name"), "Spawned monsters keep template name")
	_assert(first.get("world_position") is Vector2, "Spawned monsters have world positions")

	var center := Vector2(100.0, 100.0)
	var initial_screen: Vector2 = spawner.get_radar_position(first, Vector2.ZERO, center, 1.0)
	var moved_screen: Vector2 = spawner.get_radar_position(first, Vector2(25.0, 0.0), center, 1.0)
	_assert(
		moved_screen == initial_screen - Vector2(25.0, 0.0),
		"Radar screen position shifts opposite to simulated player movement"
	)

	var distance: float = spawner.get_distance_meters(first, Vector2.ZERO)
	_assert(distance > 0.0, "Spawner reports positive monster distance")
	database.free()


func _test_radar_heading_helpers(radar_math_script: Script) -> void:
	var radar_math: Object = radar_math_script.new()

	_assert(
		radar_math.has_method("get_heading_from_motion"),
		"Radar UI math exposes movement heading helper"
	)
	_assert(
		radar_math.has_method("get_arrow_rotation_for_heading"),
		"Radar UI math exposes arrow rotation helper"
	)
	if not radar_math.has_method("get_heading_from_motion") or not radar_math.has_method("get_arrow_rotation_for_heading"):
		return

	var fallback_heading := Vector2.UP
	var east_heading: Vector2 = radar_math.get_heading_from_motion(Vector2.ZERO, Vector2(10.0, 0.0), fallback_heading)
	_assert(east_heading.is_equal_approx(Vector2.RIGHT), "Radar heading follows eastward movement")

	var unchanged_heading: Vector2 = radar_math.get_heading_from_motion(Vector2.ZERO, Vector2(0.1, 0.1), fallback_heading)
	_assert(unchanged_heading.is_equal_approx(Vector2.UP), "Radar heading keeps fallback for tiny GPS jitter")

	var east_rotation: float = radar_math.get_arrow_rotation_for_heading(Vector2.RIGHT)
	_assert(absf(east_rotation - (PI * 0.5)) < 0.001, "Radar arrow rotates toward eastward movement")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
