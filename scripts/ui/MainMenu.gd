extends Control

@onready var single_player_button: Button = %SinglePlayerButton
@onready var lan_button: Button = %LanButton
@onready var collection_button: Button = %CollectionButton


func _ready() -> void:
	GameState.set_current_scene(Constants.SCENE_MAIN_MENU)
	single_player_button.pressed.connect(_on_single_player_pressed)
	lan_button.pressed.connect(_on_lan_pressed)
	collection_button.pressed.connect(_on_collection_pressed)


func _on_single_player_pressed() -> void:
	GameState.start_mode(Constants.MODE_SINGLE_PLAYER)
	_change_scene(Constants.SCENE_RADAR)


func _on_lan_pressed() -> void:
	GameState.start_mode(Constants.MODE_LAN)
	_change_scene(Constants.SCENE_RADAR)


func _on_collection_pressed() -> void:
	_change_scene(Constants.SCENE_COLLECTION)


func _change_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s: %s" % [scene_path, error])
