extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_run_tests()

	if failures.is_empty():
		print("PHASE4 LOCATION SERVICE TESTS PASS")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _run_tests() -> void:
	var location_service_script := _load_script("res://scripts/location/LocationService.gd")

	if not failures.is_empty():
		return

	_test_mock_mode(location_service_script)
	_test_lat_lon_to_local_meters(location_service_script)
	_test_android_status_handling(location_service_script)


func _load_script(path: String) -> Script:
	var resource := load(path)
	var script := resource as Script
	_assert(script != null, "Expected script to load: %s" % path)
	if script == null:
		return null

	_assert(script.can_instantiate(), "Expected script to compile and instantiate: %s" % path)
	return script


func _test_mock_mode(location_service_script: Script) -> void:
	var service: Node = location_service_script.new()
	service.set_runtime_mode_for_tests("mock")
	root.add_child(service)
	service.start()

	_assert(service.is_simulation_available(), "Mock mode enables simulated movement")
	_assert(service.get_current_position() == Vector2.ZERO, "Mock mode starts at origin")

	service.move_by(Vector2(25.0, -10.0))
	_assert(
		service.get_current_position() == Vector2(25.0, -10.0),
		"LocationService delegates movement to mock location service"
	)
	_assert(service.get_status().get("code", "") == "mock_active", "Mock mode reports active status")

	service.free()


func _test_lat_lon_to_local_meters(location_service_script: Script) -> void:
	var service: Node = location_service_script.new()

	var local_position: Vector2 = service.lat_lon_to_local_meters(
		31.0009,
		121.001,
		31.0,
		121.0
	)

	_assert(local_position.x > 90.0 and local_position.x < 100.0, "Longitude converts to east meters")
	_assert(local_position.y < -95.0 and local_position.y > -105.0, "Latitude converts to north as negative Y")

	service.free()


func _test_android_status_handling(location_service_script: Script) -> void:
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.start()

	service.apply_android_permission_result(false)
	_assert(
		service.get_status().get("code", "") == "permission_denied",
		"Denied Android permission is reported without crashing"
	)

	var accepted_low_accuracy: bool = service.ingest_android_location(
		31.0,
		121.0,
		150.0,
		"gps"
	)
	_assert(not accepted_low_accuracy, "Low-accuracy Android location is rejected")
	_assert(
		service.get_status().get("code", "") == "low_accuracy",
		"Low-accuracy Android location reports low_accuracy status"
	)

	var accepted_good_location: bool = service.ingest_android_location(
		31.0,
		121.0,
		20.0,
		"gps"
	)
	_assert(accepted_good_location, "Accurate Android location is accepted")
	_assert(service.has_current_position(), "Accepted Android location marks current position available")
	_assert(service.get_status().get("code", "") == "location_ready", "Accurate Android location reports ready status")

	service.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
