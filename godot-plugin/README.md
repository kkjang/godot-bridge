# Godot Bridge Plugin

A Godot 4.x editor plugin that exposes a WebSocket command interface on `localhost:6505`, enabling external tools to control the editor programmatically.

For implementation guidance and protocol constraints while editing this plugin, see `AGENTS.md`.

## Requirements

- Godot 4.3+
- A Godot project to install the plugin into

## Installation

1. Copy `addons/godot_bridge/` into your project's `addons/` directory.
2. Enable **Godot Bridge** in **Project -> Project Settings -> Plugins**.
3. Verify the bottom panel shows one of these states:
   - `Bridge: Listening :6505`
   - `Bridge: Connected`
   - `Bridge: Error (port 6505)`

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
- Node inspection and edits: `node_tree`, `node_get`, `node_add`, `node_modify`, `node_delete`, `node_move`
- Scene actions: `scene_new`, `scene_open`, `scene_save`, `scene_run`, `scene_stop`
- Script and resource access: `script_open`, `resource_list`
- Capture: `screenshot`

## Troubleshooting

- Port already in use: stop the conflicting process or change `godot_bridge/port`.
- Bridge tab missing: enable the plugin in **Project -> Project Settings -> Plugins**.
- Commands timing out: check the Godot editor output panel for GDScript errors.
- Incorrect path after `node_add`: save the scene before relying on newly added node paths.
