# City Spirits

City Spirits is a Godot 4.6 Android-first GPS radar capture game prototype. The project is single-player first and intended for small friend playtests through APK builds.

Phase 1 is a clean project skeleton. It does not implement GPS, LAN networking, AR, real maps, cloud services, or third-party plugins.

## Current Status

- Main menu with single-player, LAN mode, and collection buttons.
- Single-player mode opens the radar scene.
- Collection opens the collection scene.
- Radar, capture, and collection scenes contain placeholder UI.
- Core autoload scripts are in place for constants, events, and game state.

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
  core/
  ui/
docs/
```

## Core Files

- `scripts/core/Constants.gd`：scene paths and shared string constants.
- `scripts/core/EventBus.gd`：cross-scene signals.
- `scripts/core/GameState.gd`：current mode, current scene path, and local captured spirit IDs.
- `scripts/ui/MainMenu.gd`：main-menu navigation.
- `scripts/ui/PlaceholderScreen.gd`：placeholder scene bookkeeping and return navigation.

## Documentation

- `docs/GAME_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/CODEX_TASKS.md`
