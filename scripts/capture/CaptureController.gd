extends Control

const CaptureSystemScript := preload("res://scripts/capture/CaptureSystem.gd")

var capture_system: RefCounted = CaptureSystemScript.new()

@onready var back_button: Button = %BackButton
@onready var name_label: Label = %NameLabel
@onready var id_label: Label = %IdLabel
@onready var rarity_label: Label = %RarityLabel
@onready var capture_rate_label: Label = %CaptureRateLabel
@onready var distance_label: Label = %DistanceLabel
@onready var position_label: Label = %PositionLabel
@onready var hint_label: Label = %HintLabel
@onready var result_label: Label = %ResultLabel
@onready var normal_throw_button: Button = %NormalThrowButton
@onready var precise_throw_button: Button = %PreciseThrowButton
@onready var adventure_throw_button: Button = %AdventureThrowButton


func _ready() -> void:
	GameState.set_current_scene(Constants.SCENE_CAPTURE)
	back_button.pressed.connect(_on_back_pressed)
	normal_throw_button.pressed.connect(_on_normal_throw_pressed)
	precise_throw_button.pressed.connect(_on_precise_throw_pressed)
	adventure_throw_button.pressed.connect(_on_adventure_throw_pressed)
	_update_monster_details()


func _update_monster_details() -> void:
	var monster := GameState.get_selected_monster()
	if monster.is_empty():
		name_label.text = "未选择怪物"
		id_label.text = "ID: -"
		rarity_label.text = "稀有度: -"
		capture_rate_label.text = "基础捕捉率: -"
		distance_label.text = "距离: -"
		position_label.text = "坐标: -"
		hint_label.text = "请从雷达界面点击一个怪物点进入。"
		result_label.text = "没有可捕捉目标。"
		_set_throw_buttons_enabled(false)
		return

	var world_position: Vector2 = monster.get("world_position", Vector2.ZERO)
	var monster_id := str(monster.get("id", ""))
	var base_capture_rate := float(monster.get("base_capture_rate", 0.35))
	name_label.text = str(monster.get("name", "Unknown"))
	id_label.text = "ID: %s" % monster_id
	rarity_label.text = "稀有度: %s" % _format_rarity(str(monster.get("rarity", "common")))
	capture_rate_label.text = "基础捕捉率: %.0f%%" % (base_capture_rate * 100.0)
	distance_label.text = "距离: %.1f m" % float(monster.get("distance_meters", 0.0))
	position_label.text = "世界坐标: X %.0f m / Y %.0f m" % [world_position.x, world_position.y]
	hint_label.text = str(monster.get("hint", "观察它的节奏，选择一种投掷方式。"))

	if GameState.has_captured_monster(monster_id):
		result_label.text = "已收录到图鉴。"
		_set_throw_buttons_enabled(false)
	else:
		result_label.text = "选择一种投掷方式。"
		_set_throw_buttons_enabled(true)


func _on_normal_throw_pressed() -> void:
	_attempt_throw(Constants.THROW_NORMAL_MULTIPLIER, false)


func _on_precise_throw_pressed() -> void:
	_attempt_throw(Constants.THROW_PRECISE_MULTIPLIER, false)


func _on_adventure_throw_pressed() -> void:
	_attempt_throw(Constants.THROW_ADVENTURE_MULTIPLIER, true)


func _attempt_throw(throw_multiplier: float, escape_on_failure: bool) -> void:
	var monster := GameState.get_selected_monster()
	if monster.is_empty():
		result_label.text = "没有可捕捉目标。"
		_set_throw_buttons_enabled(false)
		return

	var result: Dictionary = capture_system.attempt_capture(
		monster,
		throw_multiplier,
		-1.0,
		escape_on_failure
	)
	var chance := float(result.get("chance", 0.0))
	var roll := float(result.get("roll", 0.0))

	if result.get("success", false):
		GameState.add_captured_monster(monster)
		result_label.text = "捕捉成功！已加入图鉴。概率 %.0f%% / 判定 %.0f%%" % [
			chance * 100.0,
			roll * 100.0
		]
		_set_throw_buttons_enabled(false)
		return

	if result.get("escaped", false):
		result_label.text = "捕捉失败，怪物逃跑了。概率 %.0f%% / 判定 %.0f%%" % [
			chance * 100.0,
			roll * 100.0
		]
		_set_throw_buttons_enabled(false)
		return

	result_label.text = "捕捉失败，可以继续尝试。概率 %.0f%% / 判定 %.0f%%" % [
		chance * 100.0,
		roll * 100.0
	]


func _set_throw_buttons_enabled(enabled: bool) -> void:
	normal_throw_button.disabled = not enabled
	precise_throw_button.disabled = not enabled
	adventure_throw_button.disabled = not enabled


func _format_rarity(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"uncommon":
			return "少见"
		"rare":
			return "稀有"
		_:
			return rarity


func _on_back_pressed() -> void:
	var error := get_tree().change_scene_to_file(Constants.SCENE_RADAR)
	if error != OK:
		push_error("Failed to return to radar: %s" % error)
