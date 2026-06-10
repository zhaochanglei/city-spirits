extends Node
class_name LocationService

signal location_changed(position: Vector2)
signal status_changed(status: Dictionary)

const MockLocationServiceScript := preload("res://scripts/location/MockLocationService.gd")

const MODE_MOCK := "mock"
const MODE_ANDROID := "android"
const ANDROID_LOCATION_PLUGIN_SINGLETON := "CitySpiritsLocationPlugin"

const STATUS_MOCK_ACTIVE := "mock_active"
const STATUS_REQUESTING_PERMISSION := "requesting_permission"
const STATUS_PERMISSION_DENIED := "permission_denied"
const STATUS_PROVIDER_UNAVAILABLE := "provider_unavailable"
const STATUS_WAITING_FOR_FIX := "waiting_for_fix"
const STATUS_LOW_ACCURACY := "low_accuracy"
const STATUS_LOCATION_READY := "location_ready"

const PERMISSION_FINE_LOCATION := "android.permission.ACCESS_FINE_LOCATION"
const PERMISSION_COARSE_LOCATION := "android.permission.ACCESS_COARSE_LOCATION"
const LOCATION_SERVICE_NAME := "location"
const GPS_PROVIDER := "gps"
const NETWORK_PROVIDER := "network"
const EARTH_RADIUS_METERS := 6378137.0
const LOCATION_FRESHNESS_PRIORITY_WINDOW_MILLIS := 15000
const DEBUG_TAG := "[CitySpirits][LocationService]"

@export var min_accuracy_meters := 75.0
@export var android_poll_interval_seconds := 3.0

var runtime_mode := ""
var current_position := Vector2.ZERO
var has_position := false
var status := {
	"code": "",
	"message": ""
}
var mock_service: Node
var test_runtime_mode := ""
var android_permission_granted := false
var android_permission_denied := false
var android_permission_requested := false
var android_origin_latitude := 0.0
var android_origin_longitude := 0.0
var has_android_origin := false
var android_runtime: Object
var android_runtime_for_tests: Object
var android_location_plugin: Object
var android_location_plugin_for_tests: Object
var android_plugin_updates_started := false
var android_plugin_live_location_received := false
var android_plugin_update_count := 0
var android_fallback_poll_count := 0
var android_last_plugin_location := {}
var android_last_selected_last_known_location := {}
var android_last_known_locations := {
	GPS_PROVIDER: {},
	NETWORK_PROVIDER: {}
}
var android_last_plugin_status := {}
var android_context: Object
var android_location_manager: Object
var android_poll_elapsed := 0.0


func _ready() -> void:
	if not get_tree().on_request_permissions_result.is_connected(_on_request_permissions_result):
		get_tree().on_request_permissions_result.connect(_on_request_permissions_result)


func _process(delta: float) -> void:
	if runtime_mode != MODE_ANDROID:
		return

	if android_plugin_live_location_received:
		return

	android_poll_elapsed += delta
	if android_poll_elapsed < android_poll_interval_seconds:
		return

	android_poll_elapsed = 0.0
	_poll_android_location()


func start() -> void:
	runtime_mode = _detect_runtime_mode()
	_debug_log("start runtime_mode=%s" % runtime_mode)
	if runtime_mode == MODE_ANDROID:
		_start_android_mode()
	else:
		_start_mock_mode()


func set_runtime_mode_for_tests(mode: String) -> void:
	test_runtime_mode = mode


func set_android_runtime_override(runtime: Object) -> void:
	android_runtime_for_tests = runtime


func set_android_location_plugin_override(plugin: Object) -> void:
	android_location_plugin_for_tests = plugin


func refresh_android_location_manager() -> void:
	_setup_android_location_manager()


func has_android_location_plugin() -> bool:
	return android_location_plugin != null


func has_android_location_manager() -> bool:
	return android_location_manager != null


func poll_android_location_now() -> void:
	_poll_android_location()


func get_runtime_mode() -> String:
	return runtime_mode


func is_simulation_available() -> bool:
	return runtime_mode == MODE_MOCK


func get_current_position() -> Vector2:
	return current_position


func has_current_position() -> bool:
	return has_position


func get_status() -> Dictionary:
	return status.duplicate(true)


func get_status_text() -> String:
	return str(status.get("message", ""))


func get_diagnostics() -> Dictionary:
	return {
		"runtime_mode": runtime_mode,
		"status_code": str(status.get("code", "")),
		"status_message": str(status.get("message", "")),
		"plugin_available": android_location_plugin != null,
		"plugin_updates_started": android_plugin_updates_started,
		"plugin_live_location_received": android_plugin_live_location_received,
		"plugin_update_count": android_plugin_update_count,
		"fallback_poll_count": android_fallback_poll_count,
		"last_location_source": str(status.get("location_source", "")),
		"last_provider": str(status.get("provider", "")),
		"last_accuracy_meters": float(status.get("accuracy_meters", 0.0)),
		"last_latitude": float(status.get("latitude", 0.0)),
		"last_longitude": float(status.get("longitude", 0.0)),
		"last_time_millis": int(status.get("time_millis", 0)),
		"origin_latitude": android_origin_latitude,
		"origin_longitude": android_origin_longitude,
		"relative_x": current_position.x,
		"relative_y": current_position.y,
		"last_plugin_location": _get_fresh_location_snapshot(android_last_plugin_location),
		"last_selected_last_known_location": _get_fresh_location_snapshot(android_last_selected_last_known_location),
		"last_known_gps": _get_fresh_location_snapshot(android_last_known_locations.get(GPS_PROVIDER, {})),
		"last_known_network": _get_fresh_location_snapshot(android_last_known_locations.get(NETWORK_PROVIDER, {})),
		"last_plugin_status": android_last_plugin_status.duplicate(true)
	}


func _debug_log(message: String) -> void:
	print("%s %s" % [DEBUG_TAG, message])


func _get_now_millis() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _format_android_location_debug(
	source: String,
	latitude: float,
	longitude: float,
	accuracy_meters: float,
	provider: String,
	time_millis: int
) -> String:
	var age_millis := _get_now_millis() - time_millis
	return "%s provider=%s lat=%.6f lon=%.6f acc=%.1fm age=%dms" % [
		source,
		provider,
		latitude,
		longitude,
		accuracy_meters,
		age_millis
	]


func _build_location_snapshot(
	latitude: float,
	longitude: float,
	accuracy_meters: float,
	provider: String,
	time_millis: int
) -> Dictionary:
	return {
		"provider": provider,
		"latitude": latitude,
		"longitude": longitude,
		"accuracy_meters": accuracy_meters,
		"time_millis": time_millis
	}


func _get_fresh_location_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}

	var updated_snapshot := snapshot.duplicate(true)
	updated_snapshot["age_millis"] = _get_now_millis() - int(snapshot.get("time_millis", 0))
	return updated_snapshot


func move_by(delta: Vector2) -> void:
	if mock_service == null:
		_set_status(
			STATUS_PROVIDER_UNAVAILABLE,
			"Android 模式不支持模拟移动。"
		)
		return

	mock_service.move_by(delta)


func apply_android_permission_result(granted: bool) -> void:
	android_permission_granted = granted
	android_permission_denied = not granted
	_debug_log("apply_android_permission_result granted=%s" % granted)
	if granted:
		_start_android_location_updates()
		_set_status(STATUS_WAITING_FOR_FIX, "定位权限已授权，正在等待定位结果。")
		_poll_android_location()
	else:
		_stop_android_location_updates()
		_set_status(STATUS_PERMISSION_DENIED, "定位权限被拒绝，雷达无法使用真实位置。")


func ingest_android_location(
	latitude: float,
	longitude: float,
	accuracy_meters: float,
	provider: String = GPS_PROVIDER,
	time_millis: int = 0,
	location_source: String = ""
) -> bool:
	_debug_log(
		"ingest_android_location source=%s provider=%s lat=%.6f lon=%.6f acc=%.1f time=%d origin_set=%s" % [
			location_source,
			provider,
			latitude,
			longitude,
			accuracy_meters,
			time_millis,
			has_android_origin
		]
	)
	if accuracy_meters > min_accuracy_meters:
		_debug_log(
			"reject_low_accuracy provider=%s acc=%.1f threshold=%.1f" % [
				provider,
				accuracy_meters,
				min_accuracy_meters
			]
		)
		_set_status(
			STATUS_LOW_ACCURACY,
			"定位精度过低：%.0f m，需要 %.0f m 以内。" % [
				accuracy_meters,
				min_accuracy_meters
			],
			{
				"accuracy_meters": accuracy_meters,
				"provider": provider,
				"time_millis": time_millis,
				"location_source": location_source
			}
		)
		return false

	if not has_android_origin:
		android_origin_latitude = latitude
		android_origin_longitude = longitude
		has_android_origin = true
		_debug_log("set_android_origin lat=%.6f lon=%.6f" % [latitude, longitude])

	current_position = lat_lon_to_local_meters(
		latitude,
		longitude,
		android_origin_latitude,
		android_origin_longitude
	)
	has_position = true
	_debug_log(
		"accepted_android_location provider=%s relative_x=%.2f relative_y=%.2f" % [
			provider,
			current_position.x,
			current_position.y
		]
	)
	_set_status(
		STATUS_LOCATION_READY,
		"定位已就绪：%s，精度 %.0f m。" % [provider, accuracy_meters],
		{
			"latitude": latitude,
			"longitude": longitude,
			"accuracy_meters": accuracy_meters,
			"provider": provider,
			"time_millis": time_millis,
			"location_source": location_source
		}
	)
	location_changed.emit(current_position)
	return true


func lat_lon_to_local_meters(
	latitude: float,
	longitude: float,
	origin_latitude: float,
	origin_longitude: float
) -> Vector2:
	var latitude_delta_rad := deg_to_rad(latitude - origin_latitude)
	var longitude_delta_rad := deg_to_rad(longitude - origin_longitude)
	var average_latitude_rad := deg_to_rad((latitude + origin_latitude) * 0.5)
	var east_meters := longitude_delta_rad * EARTH_RADIUS_METERS * cos(average_latitude_rad)
	var north_meters := latitude_delta_rad * EARTH_RADIUS_METERS
	return Vector2(east_meters, -north_meters)


func _detect_runtime_mode() -> String:
	if not test_runtime_mode.is_empty():
		return test_runtime_mode

	if OS.get_name() == "Android" and not Engine.is_editor_hint():
		return MODE_ANDROID

	return MODE_MOCK


func _start_mock_mode() -> void:
	set_process(false)
	_clear_mock_service()
	_reset_android_diagnostics()

	mock_service = MockLocationServiceScript.new()
	add_child(mock_service)
	mock_service.location_changed.connect(_on_mock_location_changed)
	current_position = mock_service.get_current_position()
	has_position = true
	_set_status(STATUS_MOCK_ACTIVE, "PC / Editor 模拟定位模式。")
	location_changed.emit(current_position)


func _start_android_mode() -> void:
	_clear_mock_service()
	_reset_android_diagnostics()
	has_position = false
	current_position = Vector2.ZERO
	set_process(true)
	_debug_log("start_android_mode")
	_request_android_location_permission()
	_setup_android_location_plugin()
	if android_permission_granted:
		_start_android_location_updates()
	_poll_android_location()


func _exit_tree() -> void:
	_stop_android_location_updates()


func _clear_mock_service() -> void:
	if mock_service != null:
		mock_service.queue_free()
		mock_service = null


func _reset_android_diagnostics() -> void:
	has_android_origin = false
	android_origin_latitude = 0.0
	android_origin_longitude = 0.0
	android_plugin_updates_started = false
	android_plugin_live_location_received = false
	android_plugin_update_count = 0
	android_fallback_poll_count = 0
	android_last_plugin_location = {}
	android_last_selected_last_known_location = {}
	android_last_known_locations = {
		GPS_PROVIDER: {},
		NETWORK_PROVIDER: {}
	}
	android_last_plugin_status = {}


func _on_mock_location_changed(position: Vector2) -> void:
	current_position = position
	has_position = true
	_set_status(STATUS_MOCK_ACTIVE, "PC / Editor 模拟定位模式。")
	location_changed.emit(current_position)


func _request_android_location_permission() -> void:
	android_permission_granted = _has_android_permission(PERMISSION_FINE_LOCATION) or _has_android_permission(PERMISSION_COARSE_LOCATION)
	_debug_log("request_android_location_permission already_granted=%s" % android_permission_granted)
	if android_permission_granted:
		_set_status(STATUS_WAITING_FOR_FIX, "定位权限已授权，正在等待定位结果。")
		return

	android_permission_requested = true
	_set_status(STATUS_REQUESTING_PERMISSION, "正在请求前台定位权限。")
	OS.request_permission(PERMISSION_FINE_LOCATION)


func _has_android_permission(permission: String) -> bool:
	if not OS.has_method("get_granted_permissions"):
		return false

	var permissions: PackedStringArray = OS.get_granted_permissions()
	return permissions.has(permission)


func _on_request_permissions_result(permission: String, granted: bool) -> void:
	_debug_log("on_request_permissions_result permission=%s granted=%s" % [permission, granted])
	if permission != PERMISSION_FINE_LOCATION and permission != PERMISSION_COARSE_LOCATION:
		return

	if granted:
		apply_android_permission_result(true)
		return

	if permission == PERMISSION_FINE_LOCATION and not _has_android_permission(PERMISSION_COARSE_LOCATION):
		OS.request_permission(PERMISSION_COARSE_LOCATION)
		return

	apply_android_permission_result(false)


func _setup_android_location_plugin() -> void:
	if android_location_plugin_for_tests != null:
		android_location_plugin = android_location_plugin_for_tests
	elif Engine.has_singleton(ANDROID_LOCATION_PLUGIN_SINGLETON):
		android_location_plugin = Engine.get_singleton(ANDROID_LOCATION_PLUGIN_SINGLETON)
	else:
		android_location_plugin = null
		_debug_log("android_location_plugin unavailable")
		return

	_debug_log("android_location_plugin connected")

	var location_update_callable := Callable(self, "_on_android_plugin_location_update")
	if not android_location_plugin.is_connected("location_update", location_update_callable):
		android_location_plugin.connect("location_update", location_update_callable)

	var status_callable := Callable(self, "_on_android_plugin_status_changed")
	if not android_location_plugin.is_connected("location_status_changed", status_callable):
		android_location_plugin.connect("location_status_changed", status_callable)


func _start_android_location_updates() -> void:
	_setup_android_location_plugin()
	if android_location_plugin == null:
		_debug_log("start_android_location_updates skipped: no plugin")
		return

	android_plugin_live_location_received = false
	var min_time_millis := maxi(int(android_poll_interval_seconds * 1000.0), 1000)
	android_plugin_updates_started = bool(android_location_plugin.startLocationUpdates(min_time_millis, 1.0))
	_debug_log(
		"start_android_location_updates started=%s min_time_ms=%d" % [
			android_plugin_updates_started,
			min_time_millis
		]
	)


func _stop_android_location_updates() -> void:
	if android_location_plugin == null or not android_plugin_updates_started:
		return

	android_location_plugin.stopLocationUpdates()
	android_plugin_updates_started = false
	android_plugin_live_location_received = false
	_debug_log("stop_android_location_updates")


func _setup_android_location_manager() -> void:
	if android_runtime_for_tests != null:
		android_runtime = android_runtime_for_tests
	elif Engine.has_singleton("AndroidRuntime"):
		android_runtime = Engine.get_singleton("AndroidRuntime")
	else:
		_set_status(
			STATUS_PROVIDER_UNAVAILABLE,
			"AndroidRuntime 不可用，无法读取真实定位。"
		)
		return

	if android_runtime == null:
		_set_status(
			STATUS_PROVIDER_UNAVAILABLE,
			"AndroidRuntime 不可用，无法读取真实定位。"
		)
		return

	android_context = android_runtime.getActivity()
	if android_context == null:
		android_context = android_runtime.getApplicationContext()

	if android_context == null:
		_set_status(
			STATUS_PROVIDER_UNAVAILABLE,
			"Android 上下文不可用：getActivity() 和 getApplicationContext() 都为空。"
		)
		return

	_debug_log("requesting Android location manager")
	android_location_manager = android_context.getSystemService(LOCATION_SERVICE_NAME)
	if android_location_manager == null:
		_set_status(
			STATUS_PROVIDER_UNAVAILABLE,
			"Android 定位服务不可用。"
		)


func _on_android_plugin_location_update(
	latitude: float,
	longitude: float,
	accuracy_meters: float,
	provider: String,
	time_millis: int
) -> void:
	android_plugin_live_location_received = true
	android_plugin_update_count += 1
	android_last_plugin_location = _build_location_snapshot(
		latitude,
		longitude,
		accuracy_meters,
		provider,
		time_millis
	)
	_debug_log(_format_android_location_debug("plugin_location_update", latitude, longitude, accuracy_meters, provider, time_millis))
	ingest_android_location(latitude, longitude, accuracy_meters, provider, time_millis, "plugin")


func _on_android_plugin_status_changed(code: String, message: String, provider: String = "") -> void:
	android_last_plugin_status = {
		"code": code,
		"message": message,
		"provider": provider
	}
	_debug_log("plugin_status code=%s provider=%s message=%s" % [code, provider, message])
	match code:
		"permission_missing":
			_set_status(STATUS_PERMISSION_DENIED, message)
		"providers_unavailable", "provider_disabled":
			_set_status(STATUS_PROVIDER_UNAVAILABLE, message, {"provider": provider})
		"provider_enabled", "updates_started":
			if not has_position:
				_set_status(STATUS_WAITING_FOR_FIX, message, {"provider": provider})
		_:
			if not message.is_empty() and not has_position:
				_set_status(STATUS_WAITING_FOR_FIX, message, {"provider": provider})


func _poll_android_location() -> void:
	if runtime_mode != MODE_ANDROID:
		return

	android_fallback_poll_count += 1
	_debug_log(
		"poll_android_location permission_granted=%s plugin_started=%s live_received=%s has_position=%s" % [
			android_permission_granted,
			android_plugin_updates_started,
			android_plugin_live_location_received,
			has_position
		]
	)

	if android_permission_denied:
		_set_status(STATUS_PERMISSION_DENIED, "定位权限被拒绝，雷达无法使用真实位置。")
		return

	if not android_permission_granted:
		android_permission_granted = _has_android_permission(PERMISSION_FINE_LOCATION) or _has_android_permission(PERMISSION_COARSE_LOCATION)
		if not android_permission_granted:
			if android_permission_requested:
				_set_status(STATUS_REQUESTING_PERMISSION, "正在等待前台定位权限授权。")
			return

	if android_plugin_live_location_received and has_position:
		_debug_log("skip_fallback_poll plugin live updates already active")
		return

	if android_location_manager == null:
		_setup_android_location_manager()
		if android_location_manager == null:
			return

	var location := _get_best_last_known_android_location()
	if location.is_empty():
		_debug_log("fallback_last_known_location empty")
		_set_status(STATUS_WAITING_FOR_FIX, "暂时没有定位结果，请保持 GPS 可用。")
		return

	_debug_log(
		_format_android_location_debug(
			"fallback_last_known_selected",
			float(location.get("latitude", 0.0)),
			float(location.get("longitude", 0.0)),
			float(location.get("accuracy_meters", 9999.0)),
			str(location.get("provider", GPS_PROVIDER)),
			int(location.get("time_millis", 0))
		)
	)
	android_last_selected_last_known_location = _build_location_snapshot(
		float(location.get("latitude", 0.0)),
		float(location.get("longitude", 0.0)),
		float(location.get("accuracy_meters", 9999.0)),
		str(location.get("provider", GPS_PROVIDER)),
		int(location.get("time_millis", 0))
	)
	ingest_android_location(
		float(location.get("latitude", 0.0)),
		float(location.get("longitude", 0.0)),
		float(location.get("accuracy_meters", 9999.0)),
		str(location.get("provider", GPS_PROVIDER)),
		int(location.get("time_millis", 0)),
		"last_known"
	)


func _get_best_last_known_android_location() -> Dictionary:
	var gps_location := _get_last_known_android_location(GPS_PROVIDER)
	var network_location := _get_last_known_android_location(NETWORK_PROVIDER)

	if gps_location.is_empty():
		return network_location
	if network_location.is_empty():
		return gps_location

	var gps_time := int(gps_location.get("time_millis", 0))
	var network_time := int(network_location.get("time_millis", 0))
	var time_difference := gps_time - network_time
	var gps_accuracy := float(gps_location.get("accuracy_meters", 9999.0))
	var network_accuracy := float(network_location.get("accuracy_meters", 9999.0))

	if gps_accuracy <= min_accuracy_meters:
		if time_difference >= -LOCATION_FRESHNESS_PRIORITY_WINDOW_MILLIS:
			_debug_log("select_last_known gps_preferred_by_accuracy_window")
			return gps_location

	if abs(time_difference) >= LOCATION_FRESHNESS_PRIORITY_WINDOW_MILLIS:
		if time_difference > 0:
			_debug_log("select_last_known gps_newer_than_network")
			return gps_location
		_debug_log("select_last_known network_newer_than_gps")
		return network_location

	if gps_accuracy <= network_accuracy:
		_debug_log("select_last_known gps_better_or_equal_accuracy")
		return gps_location
	_debug_log("select_last_known network_better_accuracy")
	return network_location


func _get_last_known_android_location(provider: String) -> Dictionary:
	if android_location_manager == null:
		return {}

	var location: Object = android_location_manager.getLastKnownLocation(provider)
	if location == null:
		return {}

	var accuracy := float(location.getAccuracy())
	if accuracy <= 0.0:
		accuracy = 9999.0

	var time_millis := int(location.getTime())
	android_last_known_locations[provider] = _build_location_snapshot(
		float(location.getLatitude()),
		float(location.getLongitude()),
		accuracy,
		provider,
		time_millis
	)
	_debug_log(
		_format_android_location_debug(
			"read_last_known_%s" % provider,
			float(location.getLatitude()),
			float(location.getLongitude()),
			accuracy,
			provider,
			time_millis
		)
	)

	return {
		"latitude": float(location.getLatitude()),
		"longitude": float(location.getLongitude()),
		"accuracy_meters": accuracy,
		"provider": provider,
		"time_millis": time_millis
	}


func _set_status(code: String, message: String, extra: Dictionary = {}) -> void:
	status = {
		"code": code,
		"message": message
	}
	for key in extra:
		status[key] = extra[key]

	var debug_fields: Array[String] = []
	for key in ["provider", "accuracy_meters", "latitude", "longitude", "time_millis"]:
		if status.has(key):
			debug_fields.append("%s=%s" % [key, status.get(key)])
	_debug_log("status code=%s message=%s %s" % [code, message, " ".join(debug_fields)])
	status_changed.emit(status.duplicate(true))
