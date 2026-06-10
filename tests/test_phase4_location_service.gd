extends SceneTree

var failures: Array[String] = []


class FakeAndroidRuntime:
	var activity := FakeAndroidActivity.new()

	func getActivity() -> Object:
		return activity


class FakeAndroidActivity:
	var location_manager := FakeLocationManager.new()

	func getSystemService(service_name: String) -> Object:
		if service_name == "location":
			return location_manager
		return null


class FakeLocationManager:
	var requested_provider := ""
	var locations := {}

	func getLastKnownLocation(provider: String) -> Object:
		requested_provider = provider
		return locations.get(provider, null)


class FakeJavaBridgeLocation:
	var latitude := 31.0
	var longitude := 121.0
	var accuracy := 18.0
	var time_millis := 0

	func getLatitude() -> float:
		return latitude

	func getLongitude() -> float:
		return longitude

	func getAccuracy() -> float:
		return accuracy

	func getTime() -> int:
		return time_millis


class FakeAndroidLocationPlugin:
	signal location_update(latitude, longitude, accuracy_meters, provider, time_millis)
	signal location_status_changed(code, message, provider)

	var start_called := false
	var stop_called := false

	func startLocationUpdates(_min_time_millis: int, _min_distance_meters: float) -> bool:
		start_called = true
		location_status_changed.emit("updates_started", "Plugin updates started", "gps")
		return true

	func stopLocationUpdates() -> void:
		stop_called = true


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
	_test_android_runtime_activity_context(location_service_script)
	_test_android_location_accuracy_from_bridge(location_service_script)
	_test_android_prefers_fresher_location_over_stale_network_cache(location_service_script)
	_test_android_prefers_acceptable_gps_over_network_cache(location_service_script)
	_test_android_plugin_location_updates(location_service_script)
	_test_android_fallback_poll_updates_after_plugin_live_location(location_service_script)
	_test_android_fallback_poll_ignores_stale_location_after_plugin_live_location(location_service_script)


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


func _test_android_runtime_activity_context(location_service_script: Script) -> void:
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_runtime_override(FakeAndroidRuntime.new())
	service.apply_android_permission_result(true)
	service.refresh_android_location_manager()

	_assert(
		service.has_android_location_manager(),
		"Android runtime getActivity() is accepted as the location context"
	)

	service.free()


func _test_android_location_accuracy_from_bridge(location_service_script: Script) -> void:
	var runtime := FakeAndroidRuntime.new()
	runtime.activity.location_manager.locations["gps"] = FakeJavaBridgeLocation.new()

	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_runtime_override(runtime)
	service.start()
	service.apply_android_permission_result(true)
	service.refresh_android_location_manager()
	service.poll_android_location_now()

	_assert(service.has_current_position(), "Android Java bridge location with getAccuracy() is accepted")
	_assert(
		service.get_status().get("code", "") == "location_ready",
		"Android Java bridge getAccuracy() avoids the 9999m fallback"
	)

	service.free()


func _test_android_prefers_fresher_location_over_stale_network_cache(location_service_script: Script) -> void:
	var runtime := FakeAndroidRuntime.new()
	var network_location := FakeJavaBridgeLocation.new()
	network_location.latitude = 31.0
	network_location.longitude = 121.0
	network_location.accuracy = 25.0
	network_location.time_millis = 1000

	var gps_location := FakeJavaBridgeLocation.new()
	gps_location.latitude = 31.00018
	gps_location.longitude = 121.0
	gps_location.accuracy = 40.0
	gps_location.time_millis = 20000

	runtime.activity.location_manager.locations["network"] = network_location
	runtime.activity.location_manager.locations["gps"] = gps_location

	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_runtime_override(runtime)
	service.start()
	service.apply_android_permission_result(true)
	service.refresh_android_location_manager()
	service.poll_android_location_now()

	var next_gps_location := FakeJavaBridgeLocation.new()
	next_gps_location.latitude = 31.00036
	next_gps_location.longitude = 121.0
	next_gps_location.accuracy = 42.0
	next_gps_location.time_millis = 40000
	runtime.activity.location_manager.locations["gps"] = next_gps_location
	service.poll_android_location_now()

	var current_position: Vector2 = service.get_current_position()
	_assert(current_position.y < -15.0, "Fresher GPS updates move the Android radar position")
	_assert(
		service.get_status().get("provider", "") == "gps",
		"Fresher GPS result wins over a stale but slightly more accurate network cache"
	)

	service.free()


func _test_android_prefers_acceptable_gps_over_network_cache(location_service_script: Script) -> void:
	var runtime := FakeAndroidRuntime.new()
	var network_location := FakeJavaBridgeLocation.new()
	network_location.latitude = 31.0
	network_location.longitude = 121.0
	network_location.accuracy = 25.0
	network_location.time_millis = 50000

	var gps_location := FakeJavaBridgeLocation.new()
	gps_location.latitude = 31.00018
	gps_location.longitude = 121.0
	gps_location.accuracy = 45.0
	gps_location.time_millis = 45000

	runtime.activity.location_manager.locations["network"] = network_location
	runtime.activity.location_manager.locations["gps"] = gps_location

	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_runtime_override(runtime)
	service.start()
	service.apply_android_permission_result(true)
	service.refresh_android_location_manager()
	service.poll_android_location_now()

	_assert(
		service.get_status().get("provider", "") == "gps",
		"Acceptable GPS fix is preferred over a slightly newer network cache"
	)

	service.free()


func _test_android_plugin_location_updates(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.0, 121.0, 18.0, "gps", 123450)
	plugin.location_update.emit(31.00027, 121.0, 18.0, "gps", 123456)

	_assert(plugin.start_called, "Android location plugin starts updates after permission is granted")
	_assert(service.has_android_location_plugin(), "Android location plugin override is registered")
	_assert(service.has_current_position(), "Android plugin location update is accepted")
	_assert(
		service.get_status().get("provider", "") == "gps",
		"Android plugin location update marks gps as the active provider"
	)
	_assert(
		service.get_current_position().y < -20.0,
		"Android plugin location update moves the radar-relative position"
	)

	var diagnostics: Dictionary = service.get_diagnostics()
	_assert(diagnostics.get("plugin_update_count", 0) == 2, "Diagnostics count Android plugin location updates")
	_assert(
		diagnostics.get("last_location_source", "") == "plugin",
		"Diagnostics report plugin as the latest Android location source"
	)
	_assert(
		diagnostics.get("last_plugin_status", {}).get("code", "") == "updates_started",
		"Diagnostics preserve the latest Android plugin status"
	)
	_assert(
		diagnostics.get("last_plugin_location", {}).get("provider", "") == "gps",
		"Diagnostics preserve the latest Android plugin location"
	)

	service.free()


func _test_android_fallback_poll_updates_after_plugin_live_location(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var runtime := FakeAndroidRuntime.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.set_android_runtime_override(runtime)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.0, 121.0, 18.0, "gps", 10000)

	var fresher_gps_location := FakeJavaBridgeLocation.new()
	fresher_gps_location.latitude = 31.00045
	fresher_gps_location.longitude = 121.0
	fresher_gps_location.accuracy = 18.0
	fresher_gps_location.time_millis = 30000
	runtime.activity.location_manager.locations["gps"] = fresher_gps_location

	service.refresh_android_location_manager()
	service.poll_android_location_now()

	_assert(
		service.get_current_position().y < -40.0,
		"Fallback polling continues to refresh movement after plugin live location starts"
	)
	_assert(
		service.get_status().get("location_source", "") == "last_known",
		"Newer fallback location becomes the latest Android location source"
	)

	service.free()


func _test_android_fallback_poll_ignores_stale_location_after_plugin_live_location(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var runtime := FakeAndroidRuntime.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.set_android_runtime_override(runtime)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.0, 121.0, 18.0, "gps", 10000)
	plugin.location_update.emit(31.00045, 121.0, 18.0, "gps", 30000)

	var stale_gps_location := FakeJavaBridgeLocation.new()
	stale_gps_location.latitude = 31.0
	stale_gps_location.longitude = 121.0
	stale_gps_location.accuracy = 18.0
	stale_gps_location.time_millis = 10000
	runtime.activity.location_manager.locations["gps"] = stale_gps_location

	service.refresh_android_location_manager()
	service.poll_android_location_now()

	_assert(
		service.get_current_position().y < -40.0,
		"Stale fallback polling does not move the player back after newer plugin location"
	)
	_assert(
		service.get_status().get("location_source", "") == "plugin",
		"Stale fallback polling keeps the newer plugin location source"
	)

	service.free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
