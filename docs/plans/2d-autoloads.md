# Plan: Autoload Management (`autoload_*`)

Part of the 2D game enablement series — see `docs/plans/2d-game-overview.md`.

## Context

Autoloads are how Godot does global game state: `GameManager`, `SignalBus`, `SaveSystem`,
`MusicPlayer`. They live at `autoload/<Name>` in ProjectSettings with values like
`"*res://scripts/game_manager.gd"` (the leading `*` marks "instantiate as a singleton
node"). Doing this through `project_set` is brittle because:

- The `*` prefix is easy to forget.
- The editor's live autoload registry doesn't refresh from `ProjectSettings` alone —
  `EditorInterface.add_autoload_singleton(name, path)` has to be called so the new
  autoload is usable without an editor restart.
- Removal has to go through both `remove_autoload_singleton` and setting clearing.

A small dedicated command set handles these details once and keeps the agent's call sites
clean.

## Design

Three commands, one CLI subcommand group.

- `autoload_list` — returns `[{name, path, singleton}]` for every current autoload.
- `autoload_add` — args: `{name, path, singleton?: true}`.
  - Calls `EditorInterface.add_autoload_singleton(name, path)` when `singleton` is true
    (the common case).
  - For `singleton: false`, sets `ProjectSettings.set_setting("autoload/" + name, path)`
    (no `*` prefix) and saves.
  - Errors if `name` is already registered (use `autoload_remove` then add, or extend to
    `autoload_modify` later if needed).
- `autoload_remove` — args: `{name}`.
  - Calls `EditorInterface.remove_autoload_singleton(name)` + clears the ProjectSettings
    entry + `ProjectSettings.save()`.

## Critical files

| File | Change |
|------|--------|
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | Three small handlers + dispatch entries. No separate codec file needed — the payloads are flat. |
| `cli/cmd/godot-bridge/commands_extra.go` | New `runAutoload` subcommand group and spec entries. |
| `cli/cmd/godot-bridge/main.go` | Register the subcommand group. |
| `skills/godot-bridge/SKILL.md` | Short example: adding a `GameState` autoload. |

## Patterns to reuse

- `BridgeProjectSettings.read_settings` (`bridge_project_settings.gd:6`) for the
  `autoload/` prefix scan inside `autoload_list`. The helper already supports prefix
  queries; we just post-process each raw value to split the `*` singleton marker.
- `_send_ok` / `_send_error` dispatch shape.
- `reorderFlags` + `flag.NewFlagSet` pattern from `commands_extra.go:44`.

## Verification

1. `godot-bridge autoload add --name GameState --path res://scripts/game_state.gd`
2. `godot-bridge autoload list` — `GameState` present with `singleton: true`.
3. `godot-bridge project get --prefix autoload/` — contains `autoload/GameState =
   *res://scripts/game_state.gd`.
4. Write a script that references `GameState.whatever` from another scene; `scene run`
   without restarting Godot — autoload resolves.
5. `godot-bridge autoload remove --name GameState` — disappears from both the live
   registry and ProjectSettings.
6. `cd cli && go test ./...` and `cd godot-plugin && bash scripts/test.sh`.
7. `godot-bridge spec --markdown` lists the new commands.
