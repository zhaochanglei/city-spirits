extends Node

const GAME_TITLE := "City Spirits"

const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_RADAR := "res://scenes/radar/RadarScene.tscn"
const SCENE_CAPTURE := "res://scenes/capture/CaptureScene.tscn"
const SCENE_COLLECTION := "res://scenes/collection/CollectionScene.tscn"

const MODE_SINGLE_PLAYER := "single_player"
const MODE_LAN := "lan"

const MONSTER_DATA_PATH := "res://data/monsters.json"
const SAVE_COLLECTION_PATH := "user://save/collection.json"

const MOCK_MOVE_STEP_METERS := 25.0
const RADAR_RANGE_METERS := 180.0
const RADAR_MONSTER_COUNT := 8

const THROW_NORMAL_MULTIPLIER := 1.0
const THROW_PRECISE_MULTIPLIER := 1.2
const THROW_ADVENTURE_MULTIPLIER := 1.5
