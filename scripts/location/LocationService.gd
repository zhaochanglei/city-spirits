extends Node
class_name LocationService

signal location_changed(position: Vector2)
signal status_changed(status: Dictionary)

const MockLocationServiceScript := preload("res://scripts/location/MockLocationService.gd")

const MODE_MOCK := "mock"
const MODE_ANDROID := "android"

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
var android_context: Object
var android_location_manager: Object
var android_poll_elapsed := 0.0


func _ready() -> void:
	if not get_tree().on_request_permissions_result.is_connected(_on_request_permissions_result):
		get_tree().on_request_permissions_result.connect(_on_request_permissions_result)


func _process(delta: float) -> void:
	if runtime_mode != MODE_ANDROID:
		return

	android_poll_elapsed += delta
	if android_poll_elapsed < android_poll_interval_seconds:
		return

	android_poll_elapsed = 0.0
	_poll_android_location()


func start() -> void:
	runtime_mode = _detect_runtime_mode()
	if runtime_mode == MODE_ANDROID:
		_start_android_mode()
	else:
		_start_mock_mode()


func set_runtime_mode_for_tests(mode: String) -> void:
	test_runtime_mode = mode


func set_android_runtime_override(runtime: Object) -> void:
	android_runtime_for_tests = runtime


func refresh_android_location_manager() -> void:
	_setup_android_location_manager()


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
	if granted:
		_set_status(STATUS_WAITING_FOR_FIX, "定位权限已授权，正在等待定位结果。")
		_poll_android_location()
	else:
		_set_status(STATUS_PERMISSION_DENIED, "定位权限被拒绝，雷达无法使用真实位置。")


func ingest_android_location(
	latitude: float,
	longitude: float,
	accuracy_meters: float,
	provider: String = GPS_PROVIDER
) -> bool:
	if accuracy_meters > min_accuracy_meters:
		_set_status(
			STATUS_LOW_ACCURACY,
			"定位精度过低：%.0f m，需要 %.0f m 以内。" % [
				accuracy_meters,
				min_accuracy_meters
			],
			{
				"accuracy_meters": accuracy_meters,
				"provider": provider
			}
		)
		return false

	if not has_android_origin:
		android_origin_latitude = latitude
		android_origin_longitude = longitude
		has_android_origin = true

	current_position = lat_lon_to_local_meters(
		latitude,
		longitude,
		android_origin_latitude,
		android_origin_longitude
	)
	has_position = true
	_set_status(
		STATUS_LOCATION_READY,
		"定位已就绪：%s，精度 %.0f m。" % [provider, accuracy_meters],
		{
			"latitude": latitude,
			"longitude": longitude,
			"accuracy_meters": accuracy_meters,
			"provider": provider
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

	mock_service = MockLocationServiceScript.new()
	add_child(mock_service)
	mock_service.location_changed.connect(_on_mock_location_changed)
	current_position = mock_service.get_current_position()
	has_position = true
	_set_status(STATUS_MOCK_ACTIVE, "PC / Editor 模拟定位模式。")
	location_changed.emit(current_position)


func _start_android_mode() -> void:
	_clear_mock_service()
	has_position = false
	current_position = Vector2.ZERO
	set_process(true)
	_request_android_location_permission()
	_setup_android_location_manager()
	_poll_android_location()


func _clear_mock_service() -> void:
	if mock_service != null:
		mock_service.queue_free()
		mock_service = null


func _on_mock_location_changed(position: Vector2) -> void:
	current_position = position
	has_position = true
	_set_status(STATUS_MOCK_ACTIVE, "PC / Editor 模拟定位模式。")
	location_changed.emit(current_position)


func _request_android_location_permission() -> void:
	android_permission_granted = _has_android_permission(PERMISSION_FINE_LOCATION) or _has_android_permission(PERMISSION_COARSE_LOCATION)
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
	if permission != PERMISSION_FINE_LOCATION and permission != PERMISSION_COARSE_LOCATION:
		return

	if granted:
		apply_android_permission_result(true)
		return

	if permission == PERMISSION_FINE_LOCATION and not _has_android_permission(PERMISSION_COARSE_LOCATION):
		OS.request_permission(PERMISSION_COARSE_LOCATION)
		return

	apply_android_permission_result(false)


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

	android_location_manager = android_context.getSystemService(LOCATION_SERVICE_NAME)
	if android_location_manager == null:
		_set_status(
			STATUS_PROVIDER_UNAVAILABLE,
			"Android 定位服务不可用。"
		)


func _poll_android_location() -> void:
	if runtime_mode != MODE_ANDROID:
		return

	if android_permission_denied:
		_set_status(STATUS_PERMISSION_DENIED, "定位权限被拒绝，雷达无法使用真实位置。")
		return

	if not android_permission_granted:
		android_permission_granted = _has_android_permission(PERMISSION_FINE_LOCATION) or _has_android_permission(PERMISSION_COARSE_LOCATION)
		if not android_permission_granted:
			if android_permission_requested:
				_set_status(STATUS_REQUESTING_PERMISSION, "正在等待前台定位权限授权。")
			return

	if android_location_manager == null:
		_setup_android_location_manager()
		if android_location_manager == null:
			return

	var location := _get_best_last_known_android_location()
	if location.is_empty():
		_set_status(STATUS_WAITING_FOR_FIX, "暂时没有定位结果，请保持 GPS 可用。")
		return

	ingest_android_location(
		float(location.get("latitude", 0.0)),
		float(location.get("longitude", 0.0)),
		float(location.get("accuracy_meters", 9999.0)),
		str(location.get("provider", GPS_PROVIDER))
	)


func _get_best_last_known_android_location() -> Dictionary:
	var gps_location := _get_last_known_android_location(GPS_PROVIDER)
	var network_location := _get_last_known_android_location(NETWORK_PROVIDER)

	if gps_location.is_empty():
		return network_location
	if network_location.is_empty():
		return gps_location

	if float(gps_location.get("accuracy_meters", 9999.0)) <= float(network_location.get("accuracy_meters", 9999.0)):
		return gps_location
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

	return {
		"latitude": float(location.getLatitude()),
		"longitude": float(location.getLongitude()),
		"accuracy_meters": accuracy,
		"provider": provider
	}


func _set_status(code: String, message: String, extra: Dictionary = {}) -> void:
	status = {
		"code": code,
		"message": message
	}
	for key in extra:
		status[key] = extra[key]

	status_changed.emit(status.duplicate(true))
