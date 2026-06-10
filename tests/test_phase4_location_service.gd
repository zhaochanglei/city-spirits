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
	signal location_update(latitude, longitude, accuracy_meters, provider, time_millis, source)
	signal location_status_changed(code, message, provider)

	var start_called := false
	var stop_called := false
	var last_min_time_millis := -1
	var last_min_distance_meters := -1.0

	func startLocationUpdates(min_time_millis: int, min_distance_meters: float) -> bool:
		start_called = true
		last_min_time_millis = min_time_millis
		last_min_distance_meters = min_distance_meters
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
	_test_android_last_known_plugin_updates_diagnostics_without_origin(location_service_script)
	_test_android_stale_live_location_is_rejected(location_service_script)
	_test_android_fresh_live_location_updates_target_and_smooth_display(location_service_script)


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
		"gps",
		_fresh_time_millis(),
		"live"
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
		"gps",
		_fresh_time_millis(),
		"live"
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
	var last_known := FakeJavaBridgeLocation.new()
	last_known.time_millis = _fresh_time_millis()
	runtime.activity.location_manager.locations["gps"] = last_known

	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_runtime_override(runtime)
	service.start()
	service.apply_android_permission_result(true)
	service.refresh_android_location_manager()
	service.poll_android_location_now()

	_assert(not service.has_current_position(), "Android Java bridge last-known location does not drive radar position")
	_assert(
		service.get_diagnostics().get("last_known_gps", {}).get("accuracy_meters", 0.0) == 18.0,
		"Android Java bridge getAccuracy() updates last-known diagnostics"
	)

	service.free()


func _test_android_prefers_fresher_location_over_stale_network_cache(location_service_script: Script) -> void:
	var runtime := FakeAndroidRuntime.new()
	var network_location := FakeJavaBridgeLocation.new()
	network_location.latitude = 31.0
	network_location.longitude = 121.0
	network_location.accuracy = 25.0
	network_location.time_millis = _fresh_time_millis(-9000)

	var gps_location := FakeJavaBridgeLocation.new()
	gps_location.latitude = 31.00018
	gps_location.longitude = 121.0
	gps_location.accuracy = 28.0
	gps_location.time_millis = _fresh_time_millis(-3000)

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
	var diagnostics: Dictionary = service.get_diagnostics()
	_assert(not service.has_current_position(), "Fresher last-known GPS does not move the Android radar position")
	_assert(
		diagnostics.get("last_selected_last_known_location", {}).get("provider", "") == "gps",
		"Fresher GPS result wins over a stale but slightly more accurate network cache"
	)

	service.free()


func _test_android_prefers_acceptable_gps_over_network_cache(location_service_script: Script) -> void:
	var runtime := FakeAndroidRuntime.new()
	var network_location := FakeJavaBridgeLocation.new()
	network_location.latitude = 31.0
	network_location.longitude = 121.0
	network_location.accuracy = 25.0
	network_location.time_millis = _fresh_time_millis(-1000)

	var gps_location := FakeJavaBridgeLocation.new()
	gps_location.latitude = 31.00018
	gps_location.longitude = 121.0
	gps_location.accuracy = 29.0
	gps_location.time_millis = _fresh_time_millis(-3000)

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
		service.get_diagnostics().get("last_selected_last_known_location", {}).get("provider", "") == "gps",
		"Acceptable GPS fix is preferred over a slightly newer network cache"
	)
	_assert(not service.has_current_position(), "Acceptable last-known GPS does not set the player position")

	service.free()


func _test_android_plugin_location_updates(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.0, 121.0, 18.0, "gps", _fresh_time_millis(-1000), "live")
	plugin.location_update.emit(31.00027, 121.0, 18.0, "gps", _fresh_time_millis(), "live")

	_assert(plugin.start_called, "Android location plugin starts updates after permission is granted")
	_assert(plugin.last_min_time_millis == 1000, "Android location plugin is requested with 1000ms update interval")
	_assert(absf(plugin.last_min_distance_meters - 0.5) < 0.001, "Android location plugin is requested with 0.5m distance interval")
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
		diagnostics.get("last_location_source", "") == "live",
		"Diagnostics report live as the latest Android location source"
	)
	_assert(
		diagnostics.get("last_plugin_location", {}).get("source", "") == "live",
		"Diagnostics preserve live as the Android plugin location source"
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


func _test_android_last_known_plugin_updates_diagnostics_without_origin(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.00045, 121.0, 18.0, "gps", _fresh_time_millis(), "last_known")

	var diagnostics: Dictionary = service.get_diagnostics()
	_assert(not service.has_current_position(), "Android plugin last-known update does not set current position")
	_assert(
		not bool(diagnostics.get("plugin_live_location_received", false)),
		"Android plugin last-known update does not mark live location received"
	)
	_assert(
		diagnostics.get("origin_latitude", 0.0) == 0.0 and diagnostics.get("origin_longitude", 0.0) == 0.0,
		"Android plugin last-known update does not set the Android origin"
	)
	_assert(
		diagnostics.get("last_plugin_location", {}).get("source", "") == "last_known",
		"Android plugin last-known update is preserved in diagnostics"
	)

	service.free()


func _test_android_stale_live_location_is_rejected(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.00045, 121.0, 18.0, "gps", _fresh_time_millis(-6000), "live")

	_assert(not service.has_current_position(), "Stale live Android location does not set current position")
	_assert(
		service.get_status().get("code", "") == "stale_location",
		"Stale live Android location reports stale_location status"
	)
	var stale_status_time: int = int(service.get_status().get("time_millis", 0))

	plugin.location_update.emit(31.0009, 121.0, 18.0, "gps", _fresh_time_millis(-11000), "live")
	_assert(not service.has_current_position(), "Hard-stale live Android location still does not set current position")
	_assert(
		int(service.get_status().get("time_millis", 0)) == stale_status_time,
		"Hard-stale live Android location is rejected without refreshing stale status"
	)

	service.free()


func _test_android_fresh_live_location_updates_target_and_smooth_display(location_service_script: Script) -> void:
	var plugin := FakeAndroidLocationPlugin.new()
	var service: Node = location_service_script.new()
	root.add_child(service)
	service.set_runtime_mode_for_tests("android")
	service.set_android_location_plugin_override(plugin)
	service.start()
	service.apply_android_permission_result(true)

	plugin.location_update.emit(31.0, 121.0, 18.0, "gps", _fresh_time_millis(-1000), "last_known")
	_assert(not service.has_current_position(), "Fresh last-known Android plugin update still does not set current position")

	plugin.location_update.emit(31.0, 121.0, 18.0, "gps", _fresh_time_millis(-500), "live")
	plugin.location_update.emit(31.00045, 121.0, 18.0, "gps", _fresh_time_millis(), "live")

	_assert(service.has_current_position(), "Fresh live Android plugin update sets current position")
	_assert(service.get_current_position().y < -40.0, "Fresh live Android plugin update moves target position")
	var target_after_live: Vector2 = service.get_current_position()
	plugin.location_update.emit(31.001, 121.0, 18.0, "gps", _fresh_time_millis(), "last_known")
	_assert(
		service.get_current_position().is_equal_approx(target_after_live),
		"Last-known Android plugin update after live does not change target position"
	)
	_assert(
		service.get_status().get("location_source", "") == "live",
		"Last-known Android plugin update after live does not downgrade live status"
	)
	_assert(
		service.has_method("get_display_position"),
		"LocationService exposes display position for smooth radar rendering"
	)
	if service.has_method("get_display_position"):
		var initial_display_position: Vector2 = service.get_display_position()
		service._process(0.1)
		var smoothed_display_position: Vector2 = service.get_display_position()
		_assert(smoothed_display_position.y < initial_display_position.y, "Display position moves toward target position")
		_assert(smoothed_display_position.y > service.get_current_position().y, "Display position smooths instead of snapping to target")

	service.free()


func _fresh_time_millis(offset_millis: int = 0) -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) + offset_millis


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
