extends Control

const MONSTER_BUTTON_SIZE := Vector2(84.0, 84.0)
const RADAR_FONT_SCALE := 2.0
const RADAR_DEFAULT_FONT_SIZE := 32
const LocationServiceScript := preload("res://scripts/location/LocationService.gd")
const RadarUiMathScript := preload("res://scripts/radar/RadarUiMath.gd")
const MonsterDatabaseScript := preload("res://scripts/monsters/MonsterDatabase.gd")
const MonsterSpawnerScript := preload("res://scripts/monsters/MonsterSpawner.gd")

var location_service: Node
var monster_database: Node
var radar_ui_math: RefCounted = RadarUiMathScript.new()
var monster_spawner: RefCounted = MonsterSpawnerScript.new()
var spawned_monsters: Array[Dictionary] = []
var monster_buttons: Array[Button] = []
var diagnostics_refresh_elapsed := 0.0
var has_last_player_position := false
var last_player_position := Vector2.ZERO
var player_heading := Vector2.UP
var player_arrow_polygon := PackedVector2Array([
	Vector2(0.0, -28.0),
	Vector2(18.0, 22.0),
	Vector2(0.0, 10.0),
	Vector2(-18.0, 22.0)
])

@onready var back_button: Button = %BackButton
@onready var radar_area: Control = %RadarArea
@onready var monster_layer: Control = %MonsterLayer
@onready var player_arrow: Polygon2D = %PlayerDot
@onready var position_label: Label = %PositionLabel
@onready var status_label: Label = %StatusLabel
@onready var diagnostics_label: Label = %DiagnosticsLabel
@onready var move_grid: GridContainer = %MoveGrid
@onready var up_button: Button = %UpButton
@onready var down_button: Button = %DownButton
@onready var left_button: Button = %LeftButton
@onready var right_button: Button = %RightButton


func _ready() -> void:
	GameState.set_current_scene(Constants.SCENE_RADAR)
	_apply_radar_font_scale(self)

	location_service = LocationServiceScript.new()
	monster_database = MonsterDatabaseScript.new()
	add_child(location_service)
	add_child(monster_database)

	back_button.pressed.connect(_on_back_pressed)
	up_button.pressed.connect(_move_up)
	down_button.pressed.connect(_move_down)
	left_button.pressed.connect(_move_left)
	right_button.pressed.connect(_move_right)
	location_service.location_changed.connect(_on_location_changed)
	location_service.status_changed.connect(_on_location_status_changed)
	player_arrow.polygon = player_arrow_polygon
	player_arrow.color = Color(0.956863, 0.894118, 0.45098, 1)
	location_service.start()
	move_grid.visible = location_service.is_simulation_available()
	_update_diagnostics_panel()

	if not monster_database.load_from_file(Constants.MONSTER_DATA_PATH):
		status_label.text = "怪物数据加载失败"
		return

	spawned_monsters = monster_spawner.spawn_monsters(
		location_service.get_current_position(),
		monster_database.get_all_monsters()
	)
	_update_status_text(location_service.get_status())
	call_deferred("_update_radar")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_update_radar")


func _process(delta: float) -> void:
	if location_service == null:
		return

	if location_service.get_runtime_mode() != "android":
		return

	diagnostics_refresh_elapsed += delta
	_update_radar_positions()
	if diagnostics_refresh_elapsed < 0.5:
		return

	diagnostics_refresh_elapsed = 0.0
	_update_diagnostics_panel()


func _move_up() -> void:
	_move_player(Vector2(0.0, -Constants.MOCK_MOVE_STEP_METERS))


func _move_down() -> void:
	_move_player(Vector2(0.0, Constants.MOCK_MOVE_STEP_METERS))


func _move_left() -> void:
	_move_player(Vector2(-Constants.MOCK_MOVE_STEP_METERS, 0.0))


func _move_right() -> void:
	_move_player(Vector2(Constants.MOCK_MOVE_STEP_METERS, 0.0))


func _move_player(delta: Vector2) -> void:
	if not location_service.is_simulation_available():
		return

	location_service.move_by(delta)


func _on_location_changed(position: Vector2) -> void:
	_update_player_heading(position)
	print("[CitySpirits][Radar] location_changed position=%s" % location_service.get_current_position())
	_update_diagnostics_panel()
	_update_radar()


func _on_location_status_changed(next_status: Dictionary) -> void:
	print("[CitySpirits][Radar] status_changed %s" % next_status)
	_update_status_text(next_status)
	_update_diagnostics_panel()


func _update_radar() -> void:
	if radar_area == null or monster_layer == null:
		return

	_ensure_monster_buttons()
	_update_radar_positions()


func _ensure_monster_buttons() -> void:
	if monster_buttons.size() == spawned_monsters.size():
		return

	for child in monster_layer.get_children():
		child.queue_free()
	monster_buttons.clear()

	for monster in spawned_monsters:
		var button := _create_monster_button(monster)
		monster_layer.add_child(button)
		monster_buttons.append(button)


func _update_radar_positions() -> void:
	if radar_area == null or monster_layer == null:
		return

	var player_position := _get_radar_player_position()
	var radar_center := _get_radar_center()
	var pixels_per_meter := _get_pixels_per_meter()

	_update_position_text(player_position)

	player_arrow.position = radar_center
	player_arrow.rotation = radar_ui_math.get_arrow_rotation_for_heading(player_heading)

	var count := mini(monster_buttons.size(), spawned_monsters.size())
	for index in range(count):
		_update_monster_button(
			monster_buttons[index],
			spawned_monsters[index],
			player_position,
			radar_center,
			pixels_per_meter
		)


func _create_monster_button(monster: Dictionary) -> Button:
	var button := Button.new()
	button.text = "M"
	button.add_theme_font_size_override("font_size", RADAR_DEFAULT_FONT_SIZE)
	button.custom_minimum_size = MONSTER_BUTTON_SIZE
	button.size = MONSTER_BUTTON_SIZE
	button.pressed.connect(_on_monster_pressed.bind(monster))
	return button


func _update_monster_button(
	button: Button,
	monster: Dictionary,
	player_position: Vector2,
	radar_center: Vector2,
	pixels_per_meter: float
) -> void:
	var distance: float = monster_spawner.get_distance_meters(monster, player_position)
	var screen_position: Vector2 = monster_spawner.get_radar_position(
		monster,
		player_position,
		radar_center,
		pixels_per_meter
	)

	button.tooltip_text = "%s\nID: %s\n%.1f m" % [
		monster.get("name", "Unknown"),
		monster.get("id", ""),
		distance
	]
	button.position = screen_position - (MONSTER_BUTTON_SIZE * 0.5)


func _on_monster_pressed(monster: Dictionary) -> void:
	var selected_monster: Dictionary = monster_spawner.with_distance(
		monster,
		location_service.get_current_position()
	)
	GameState.select_monster(selected_monster)

	var error := get_tree().change_scene_to_file(Constants.SCENE_CAPTURE)
	if error != OK:
		push_error("Failed to change scene to %s: %s" % [Constants.SCENE_CAPTURE, error])


func _on_back_pressed() -> void:
	var error := get_tree().change_scene_to_file(Constants.SCENE_MAIN_MENU)
	if error != OK:
		push_error("Failed to return to main menu: %s" % error)


func _update_player_heading(next_position: Vector2) -> void:
	if not has_last_player_position:
		last_player_position = next_position
		has_last_player_position = true
		return

	player_heading = radar_ui_math.get_heading_from_motion(
		last_player_position,
		next_position,
		player_heading
	)
	last_player_position = next_position


func _apply_radar_font_scale(root: Node) -> void:
	for child in root.get_children():
		if child is Label or child is Button:
			_scale_text_control(child as Control)
		_apply_radar_font_scale(child)


func _scale_text_control(control: Control) -> void:
	var base_font_size := float(control.get_theme_font_size("font_size"))
	if base_font_size <= 0:
		base_font_size = RADAR_DEFAULT_FONT_SIZE / RADAR_FONT_SCALE
	control.add_theme_font_size_override("font_size", int(round(base_font_size * RADAR_FONT_SCALE)))

	if control.custom_minimum_size.x > 0.0 or control.custom_minimum_size.y > 0.0:
		control.custom_minimum_size *= RADAR_FONT_SCALE


func _update_status_text(next_status: Dictionary) -> void:
	var status_message := str(next_status.get("message", ""))
	if status_message.is_empty():
		status_message = "发现 %d 个雷达信号" % spawned_monsters.size()
	status_label.text = status_message
	status_label.tooltip_text = status_message


func _update_diagnostics_panel() -> void:
	if diagnostics_label == null or location_service == null:
		return

	if not location_service.has_method("get_diagnostics"):
		diagnostics_label.text = "Diagnostics unavailable"
		return

	var diagnostics: Dictionary = location_service.get_diagnostics()
	var lines: Array[String] = [
		"mode=%s | status=%s | plugin_available=%s | live_received=%s" % [
			diagnostics.get("runtime_mode", ""),
			diagnostics.get("status_code", ""),
			diagnostics.get("plugin_available", false),
			diagnostics.get("plugin_live_location_received", false)
		],
		"updates_started=%s | plugin_update_count=%s | fallback_poll_count=%s | source=%s" % [
			diagnostics.get("plugin_updates_started", false),
			diagnostics.get("plugin_update_count", 0),
			diagnostics.get("fallback_poll_count", 0),
			diagnostics.get("last_location_source", "")
		],
		"provider=%s | accuracy=%.1f | lat=%.6f | lon=%.6f | time=%s" % [
			diagnostics.get("last_provider", ""),
			float(diagnostics.get("last_accuracy_meters", 0.0)),
			float(diagnostics.get("last_latitude", 0.0)),
			float(diagnostics.get("last_longitude", 0.0)),
			str(diagnostics.get("last_time_millis", 0))
		],
		"origin_lat=%.6f | origin_lon=%.6f | rel_x=%.2f | rel_y=%.2f" % [
			float(diagnostics.get("origin_latitude", 0.0)),
			float(diagnostics.get("origin_longitude", 0.0)),
			float(diagnostics.get("relative_x", 0.0)),
			float(diagnostics.get("relative_y", 0.0))
		],
		_format_diagnostics_location_line("plugin", diagnostics.get("last_plugin_location", {})),
		_format_diagnostics_location_line("selected_last_known", diagnostics.get("last_selected_last_known_location", {})),
		_format_diagnostics_location_line("last_known_gps", diagnostics.get("last_known_gps", {})),
		_format_diagnostics_location_line("last_known_network", diagnostics.get("last_known_network", {}))
	]

	var plugin_status: Dictionary = diagnostics.get("last_plugin_status", {})
	if diagnostics.get("runtime_mode", "") == "android" and not bool(diagnostics.get("plugin_available", false)):
		lines.append("hint: native location plugin missing from APK; rebuild Android export with Gradle source template")
	lines.append(
		"plugin_status code=%s | provider=%s | message=%s" % [
			plugin_status.get("code", ""),
			plugin_status.get("provider", ""),
			plugin_status.get("message", "")
		]
	)

	diagnostics_label.text = "\n".join(lines)
	diagnostics_label.tooltip_text = diagnostics_label.text


func _format_diagnostics_location_line(label: String, data: Dictionary) -> String:
	if data.is_empty():
		return "%s: none" % label

	return "%s: provider=%s acc=%.1f lat=%.6f lon=%.6f time=%s age_ms=%s" % [
		label,
		data.get("provider", ""),
		float(data.get("accuracy_meters", 0.0)),
		float(data.get("latitude", 0.0)),
		float(data.get("longitude", 0.0)),
		str(data.get("time_millis", 0)),
		str(data.get("age_millis", -1))
	]


func _update_position_text(player_position: Vector2) -> void:
	if location_service.get_runtime_mode() == "android":
		if location_service.has_current_position():
			position_label.text = "GPS 相对位置: X %.0f m / Y %.0f m" % [
				player_position.x,
				player_position.y
			]
		else:
			position_label.text = "GPS 位置: 暂不可用"
		return

	position_label.text = "模拟位置: X %.0f m / Y %.0f m" % [
		player_position.x,
		player_position.y
	]


func _get_radar_player_position() -> Vector2:
	if location_service == null:
		return Vector2.ZERO

	if location_service != null and location_service.has_method("get_display_position"):
		return location_service.get_display_position()

	return location_service.get_current_position()


func _get_radar_center() -> Vector2:
	var radar_size := radar_area.size
	if radar_size.x <= 0.0 or radar_size.y <= 0.0:
		radar_size = radar_area.custom_minimum_size
	return radar_size * 0.5


func _get_pixels_per_meter() -> float:
	var radar_size := radar_area.size
	if radar_size.x <= 0.0 or radar_size.y <= 0.0:
		radar_size = radar_area.custom_minimum_size

	var radius_pixels := minf(radar_size.x, radar_size.y) * 0.5
	return radius_pixels / Constants.RADAR_RANGE_METERS
