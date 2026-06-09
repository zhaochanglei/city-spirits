extends Control

@onready var back_button: Button = %BackButton
@onready var count_label: Label = %CountLabel
@onready var empty_label: Label = %EmptyLabel
@onready var collection_list: VBoxContainer = %CollectionList


func _ready() -> void:
	GameState.set_current_scene(Constants.SCENE_COLLECTION)
	back_button.pressed.connect(_on_back_pressed)
	GameState.load_collection()
	EventBus.collection_updated.connect(_refresh_collection)
	_refresh_collection()


func _refresh_collection() -> void:
	for child in collection_list.get_children():
		child.queue_free()

	var monsters := GameState.get_captured_monsters()
	count_label.text = "已捕捉: %d" % monsters.size()
	empty_label.visible = monsters.is_empty()

	for monster in monsters:
		collection_list.add_child(_create_monster_row(monster))


func _create_monster_row(monster: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(320.0, 72.0)
	row.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "%s  (%s)" % [
		monster.get("name", "Unknown"),
		monster.get("id", "")
	]
	title.add_theme_font_size_override("font_size", 22)
	row.add_child(title)

	var detail := Label.new()
	detail.text = "稀有度: %s    基础捕捉率: %.0f%%" % [
		_format_rarity(str(monster.get("rarity", "common"))),
		float(monster.get("base_capture_rate", 0.35)) * 100.0
	]
	row.add_child(detail)

	return row


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
	var error := get_tree().change_scene_to_file(Constants.SCENE_MAIN_MENU)
	if error != OK:
		push_error("Failed to return to main menu: %s" % error)
