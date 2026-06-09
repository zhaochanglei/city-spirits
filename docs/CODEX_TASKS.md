# Codex Tasks

## Phase 1 Completed Skeleton

- [x] Create main menu, radar, capture, and collection scenes.
- [x] Add core autoload scripts for constants, events, and game state.
- [x] Wire single-player mode to the radar scene.
- [x] Wire collection button to the collection scene.
- [x] Add placeholder UI for radar, capture, and collection.
- [x] Add project specification and architecture notes.
- [x] Update README.

## Phase 2 Completed Single-Player Radar Prototype

- [x] Add `MockLocationService` for simulated player movement.
- [x] Add monster templates in `data/monsters.json`.
- [x] Add `MonsterDatabase` and `MonsterSpawner`.
- [x] Render 5-10 monster points around a centered player in `RadarScene`.
- [x] Add up, down, left, and right buttons for simulated movement.
- [x] Recompute monster point positions after simulated movement.
- [x] Open `CaptureScene` when a monster point is clicked.
- [x] Display selected monster name, ID, distance, world position, and hint in `CaptureScene`.
- [x] Keep `CollectionScene` as a placeholder.

## Phase 3 Completed Capture, Save, and Collection

- [x] Add `CaptureSystem` for capture success and failure results.
- [x] Show monster rarity, base capture rate, and distance in `CaptureScene`.
- [x] Add normal, precise, and adventure throw buttons.
- [x] Mark adventure throw failures as escaped.
- [x] Save successful captures to local JSON.
- [x] Create a default save when no save file exists.
- [x] Fall back to a default save with warning when JSON is corrupt.
- [x] Display captured monsters in `CollectionScene`.
- [x] Keep GPS, LAN, real maps, AR, and complex inventory out of scope.

## Phase 4 Completed Android Foreground Location

- [x] Add `LocationService` as the unified location entry point.
- [x] Keep PC / Editor / Windows on mock location mode.
- [x] Keep mock movement buttons visible in mock mode.
- [x] Hide mock movement buttons in Android mode.
- [x] Request Android foreground location permission.
- [x] Read Android last-known GPS/network location through the Android runtime bridge.
- [x] Convert Android latitude/longitude to local radar meters.
- [x] Show status text for denied permission, unavailable provider, low accuracy, and missing fixes.
- [x] Enable `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` in Android export permissions.
- [x] Do not request background location.

## Suggested Next Tasks

- [ ] Add Android export smoke checklist for friend-playtest APK builds.
- [ ] Plan GPS permission and location adapter separately before implementation.
- [ ] Plan LAN discovery and synchronization separately before implementation.
- [ ] Add a capture result animation pass.
- [ ] Add a small test-data reset option for local playtests.
- [ ] Test GPS behavior on an actual Android APK and record device-specific notes.

## Guardrails

- Keep the game playable without GPS during early development.
- Keep LAN code isolated from single-player flow.
- Do not add cloud services.
- Do not add real-map or AR dependencies.
- Avoid third-party plugins unless explicitly approved later.
