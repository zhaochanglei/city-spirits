# Codex Tasks

## Phase 1 Completed Skeleton

- [x] Create main menu, radar, capture, and collection scenes.
- [x] Add core autoload scripts for constants, events, and game state.
- [x] Wire single-player mode to the radar scene.
- [x] Wire collection button to the collection scene.
- [x] Add placeholder UI for radar, capture, and collection.
- [x] Add project specification and architecture notes.
- [x] Update README.

## Suggested Next Tasks

- [ ] Define the first local spirit data format in `data/spirits`.
- [ ] Add a simple radar mock that spawns deterministic placeholder spirits without GPS.
- [ ] Add capture scene entry from radar using mock spirit IDs.
- [ ] Persist collected spirits locally with `ConfigFile` or a small save resource.
- [ ] Add Android export smoke checklist for friend-playtest APK builds.
- [ ] Plan GPS permission and location adapter separately before implementation.
- [ ] Plan LAN discovery and synchronization separately before implementation.

## Guardrails

- Keep the game playable without GPS during early development.
- Keep LAN code isolated from single-player flow.
- Do not add cloud services.
- Do not add real-map or AR dependencies.
- Avoid third-party plugins unless explicitly approved later.
