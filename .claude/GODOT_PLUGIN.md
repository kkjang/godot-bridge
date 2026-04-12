# Godot Plugin

**Location:** `godot-plugin/addons/godot_bridge/`  
**Language:** GDScript (`@tool`, `EditorPlugin`)  
**Entry point:** `plugin.gd` starts `BridgeServer` (bridge_server.gd) on editor load.

## Connection

- WebSocket on `localhost:6505` (configurable: **Project → Project Settings → `godot_bridge/port`**)
- Single client at a time; heartbeat ping every 10 s
- Status bar label: `Bridge: Listening :6505` / `Bridge: Connected`

## Protocol

All messages are JSON over WebSocket text frames.

```json
// Request
{"id": "abc123", "command": "node_add", "args": {"type": "Sprite2D", "parent": "/root/Main"}}

// Success
{"id": "abc123", "ok": true, "data": { ... }}

// Error
{"id": "abc123", "ok": false, "error": "Node not found: /root/Main/Missing"}
```

`id` is caller-chosen and echoed back for request matching.

## Commands

| Command | Required args | Optional args | Description |
|---------|--------------|---------------|-------------|
| `editor_state` | — | — | Open scenes, selected nodes, active screen (2D/3D/Script) |
| `node_tree` | — | `path`, `depth` (default 4) | Scene tree as nested JSON |
| `node_get` | `path` | `detail` (`brief`\|`full`) | Node info; `full` adds all properties, signals, groups |
| `node_add` | `type` | `parent`, `name`, `props` | Add any ClassDB node; supports undo |
| `node_modify` | `path`, `props` | — | Set properties on a node; supports undo |
| `node_delete` | `path` | — | Remove a node; supports undo |
| `node_move` | `path`, `new_parent` | — | Reparent a node; supports undo |
| `scene_new` | `path` | `root_type` (default `Node2D`), `root_name` | Create a `.tscn` and open it |
| `scene_open` | `path` | — | Open a `.tscn` in the editor |
| `scene_save` | — | — | Save the current scene |
| `scene_run` | — | `path` | Run the main project or a specific scene (F5/F6) |
| `scene_stop` | — | — | Stop the running scene |
| `script_open` | `path` | — | Open a script in the Script editor |
| `resource_list` | — | `path` (default `res://`) | List files and subdirs |
| `screenshot` | — | — | Capture 2D viewport as base64 PNG |

## Property encoding

Godot types have no direct JSON equivalent — the plugin converts automatically in both directions:

| Godot type | JSON encoding |
|------------|---------------|
| `Vector2(x, y)` | `[x, y]` |
| `Vector3(x, y, z)` | `[x, y, z]` |
| `Color(r, g, b, a)` | `[r, g, b, a]` |
| `PackedVector2Array` | `[[x,y], [x,y], …]` |
| `PackedColorArray` | `[[r,g,b,a], …]` |
| `Rect2` | `{"pos": [x,y], "size": [w,h]}` |
| `NodePath` | `"path/string"` |

Pass the same format back in `props` when writing properties.

## Node paths

All paths use the clean user-facing format: `/root/SceneName/NodeName`.  
`_node_path()` in `bridge_server.gd` derives this via `scene.get_path_to(node)`.  
`_resolve_node()` accepts both full paths (`/root/Main/Hero`) and scene-relative names (`Hero`).
