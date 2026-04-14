# godot-plugin

Godot 4.x editor plugin that exposes the WebSocket command server on `localhost:6505`.

Use `README.md` for installation and operator-facing usage. Use this file when changing the implementation.

## Scope

- Work here when changing the editor-side bridge implementation.
- Main code lives under `addons/godot_bridge/`.

## Tooling

- Files here are GDScript.
- Use the configured GDScript LSP bridge when Godot is running.
- Read `.gd` files directly when you need full source context.

## Key Files

- `addons/godot_bridge/plugin.gd` - `EditorPlugin` entry point
- `addons/godot_bridge/bridge_server.gd` - WebSocket server and command routing
- `README.md` - install and protocol overview

## Connection

- WebSocket on `localhost:6505`
- Port is configurable via Godot project setting `godot_bridge/port`
- Single client at a time with a heartbeat ping every 10 seconds

## Validation

- Run `bash scripts/test.sh` from `godot-plugin/` for headless plugin unit tests.
- On macOS, if Godot is not on `PATH`, run `GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/test.sh`.

## Protocol

- Messages are JSON over WebSocket text frames.
- Requests look like `{"id":"abc123","command":"node_add","args":{...}}`.
- Success responses look like `{"id":"abc123","ok":true,"data":{...}}`.
- Error responses look like `{"id":"abc123","ok":false,"error":"..."}`.
- `id` is caller-chosen and echoed back for request matching.

## Supported Commands

- `editor_state`
- `node_tree`
- `node_get`
- `node_add`
- `node_modify`
- `node_delete`
- `node_move`
- `scene_new`
- `scene_open`
- `scene_save`
- `scene_run`
- `scene_stop`
- `script_open`
- `resource_reimport`
- `resource_list`
- `screenshot`

## Data Conventions

- Use clean user-facing node paths like `/root/Main/Hero`.
- `_resolve_node()` accepts both full node paths and scene-relative names.
- Property JSON encodings include:
  - `Vector2` -> `[x, y]`
  - `Vector3` -> `[x, y, z]`
  - `Color` -> `[r, g, b, a]`
  - `PackedVector2Array` -> `[[x, y], ...]`
  - `PackedColorArray` -> `[[r, g, b, a], ...]`
  - `Rect2` -> `{"pos": [x, y], "size": [w, h]}`
  - `NodePath` -> `"path/string"`

## Working Notes

- Preserve the existing JSON-over-WebSocket protocol unless a change is intentional and documented.
- Keep editor interactions thin and pragmatic around `EditorInterface`.
- Prefer additive protocol changes over broad rewrites.
