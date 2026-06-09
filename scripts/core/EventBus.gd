extends Node

signal game_mode_selected(mode: String)
signal screen_changed(scene_path: String)
signal capture_started(spirit_id: String)
signal spirit_collected(spirit_id: String)
signal mock_location_changed(position: Vector2)
signal monster_selected(monster_id: String)
signal collection_updated()
