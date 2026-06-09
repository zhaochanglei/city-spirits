# City Spirits

City Spirits is a Godot 4.6 Android-first GPS radar capture game prototype. The project is single-player first and intended for small friend playtests through APK builds.

Phase 4 adds a unified location service for PC mock movement and Android foreground location. It does not implement background location, LAN networking, AR, real maps, cloud services, complex inventory, or third-party plugins.

## Current Status

- Main menu with single-player, LAN mode, and collection buttons.
- Single-player mode opens the radar scene.
- Radar scene uses `MockLocationService` and four movement buttons to simulate player movement.
- The player dot stays centered while 5-10 monster points move relative to the mock player position.
- Clicking a monster point opens the capture scene.
- Capture scene displays the selected monster's name, ID, rarity, base capture rate, distance, world position, and hint.
- Capture scene supports normal, precise, and adventure throws.
- Successful captures are saved to `user://save/collection.json`.
- Collection displays locally saved captured monsters.
- Missing save files are created automatically; corrupt JSON falls back to a default save with a warning.
- PC / Editor / Windows uses mock location and keeps the movement buttons visible.
- Android uses foreground location permission and reads Android `LocationManager` last-known GPS/network location through Godot's Android runtime bridge.
- Android permission denial, unavailable providers, low accuracy, and missing fixes show radar status text instead of crashing.

## Run

1. Open this folder with Godot 4.6.
2. Run the project.
3. The main scene is `res://scenes/main_menu/MainMenu.tscn`.

## Project Structure

```text
scenes/
  boot/
  main_menu/
  radar/
  capture/
  collection/
scripts/
  capture/
  collection/
  core/
  location/
  monsters/
  radar/
  save/
  ui/
data/
docs/
tests/
```

## Core Files

- `scripts/core/Constants.gd`：scene paths and shared string constants.
- `scripts/core/EventBus.gd`：cross-scene signals.
- `scripts/core/GameState.gd`：current mode, current scene path, selected monster, and local captured spirit IDs.
- `scripts/save/SaveManager.gd`：JSON save loading, writing, default creation, and corrupt-file fallback.
- `scripts/location/MockLocationService.gd`：mock player position and movement signal.
- `scripts/location/LocationService.gd`：unified PC mock / Android foreground location service.
- `scripts/monsters/MonsterDatabase.gd`：loads monster templates from JSON.
- `scripts/monsters/MonsterSpawner.gd`：creates deterministic radar monster instances and relative radar positions.
- `scripts/radar/RadarController.gd`：radar UI, mock movement, monster point rendering, and capture navigation.
- `scripts/capture/CaptureSystem.gd`：capture chance and throw result calculation.
- `scripts/capture/CaptureController.gd`：selected monster details and capture buttons.
- `scripts/collection/CollectionController.gd`：saved collection list UI.
- `scripts/ui/MainMenu.gd`：main-menu navigation.
- `scripts/ui/PlaceholderScreen.gd`：placeholder scene bookkeeping and return navigation.

## Documentation

- `docs/GAME_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/CODEX_TASKS.md`

## Android Location Permissions

The Android export preset enables:

- `permissions/access_fine_location=true`
- `permissions/access_coarse_location=true`

It does not request `ACCESS_BACKGROUND_LOCATION`.
