# Godot Bridge Plugin

A Godot 4.x editor plugin that exposes a WebSocket command interface on `localhost:6505`, enabling external tools to control the editor programmatically.

For implementation guidance and protocol constraints while editing this plugin, see `AGENTS.md`.

## Requirements

- Godot 4.3+
- A Godot project to install the plugin into

## Installation

1. Copy `addons/godot_bridge/` into your project's `addons/` directory.
2. Enable **Godot Bridge** in **Project -> Project Settings -> Plugins**.
3. Wait until the bottom panel shows one of these states:
   - `Bridge: Listening :6505`
   - `Bridge: Connected`
   - `Bridge: Error (port 6505)`
4. If an agent is driving setup, pause here and wait for the user to confirm the plugin has been enabled.

Agents may optionally enable the plugin by editing `project.godot`, but that is less reliable than the UI flow and usually requires reopening the Godot editor before the plugin loads.

Example copy command from this repository into a game project:

```bash
mkdir -p /path/to/game-project/addons
cp -R godot-plugin/addons/godot_bridge /path/to/game-project/addons/
```

## Changing the port

The default port is `6505`. To change it, open **Project -> Project Settings -> General**, search for `godot_bridge/port`, update the value, and restart the editor.

## API overview

- Endpoint: `ws://localhost:6505`
- Transport: JSON over WebSocket text frames
- One client connection at a time
- `debug_subscribe` style streaming holds that single connection open today

Example request:

```json
{"id": "abc123", "command": "node_tree", "args": {"path": "", "depth": 4}}
```

Example success response:

```json
{"id": "abc123", "ok": true, "data": {}}
```

Example error response:

```json
{"id": "abc123", "ok": false, "error": "No scene is open"}
```

## Supported commands

- Editor state: `editor_state`
- Node inspection and edits: `node_tree`, `node_get`, `node_add`, `node_modify`, `node_delete`, `node_move`, `node_instance`
- Signal wiring: `signal_connect`, `signal_disconnect`, `signal_connections`
- Project settings: `project_get`, `project_set`
- Animation authoring: `animation_list`, `animation_get`, `animation_new`, `animation_modify`
- Scene actions: `scene_new`, `scene_open`, `scene_save`, `scene_run`, `scene_stop`
- Debug streaming: `debug_subscribe`, `debug_unsubscribe`
- Script and resource access: `script_open`, `resource_list`
- Capture: `screenshot`

## Build And Test

- Run plugin unit tests from `godot-plugin/` with `bash scripts/test.sh`.
- CI treats that headless test run as the plugin build step.
- Release packaging uses `bash scripts/package.sh vX.Y.Z`, which produces a zip containing `addons/godot_bridge/`.
- On macOS, if Godot is not on `PATH`, run `GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/test.sh`.

## Current Limitation

`debug_subscribe` streams events over the same WebSocket used for normal commands. Because the bridge only accepts one client today, a long-running debug stream blocks other CLI commands until it exits. The server code includes a TODO to move this to per-stream subscriptions when the transport supports multiple streams.

## Troubleshooting

- Port already in use: stop the conflicting process or change `godot_bridge/port`.
- Bridge tab missing: enable the plugin in **Project -> Project Settings -> Plugins**.
- Commands timing out: check the Godot editor output panel for GDScript errors.
- Incorrect path after `node_add`: save the scene before relying on newly added node paths.
