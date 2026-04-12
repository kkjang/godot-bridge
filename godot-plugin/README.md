# Godot Bridge Plugin

A Godot 4.x editor plugin that exposes a WebSocket command interface on `localhost:6505`, enabling external tools (like the `godot-bridge` CLI) to control the editor programmatically.

## Requirements

- Godot 4.3 or later
- A Godot project to install the plugin into

## Installation

1. **Copy the plugin into your project.**

   Copy the `addons/godot_bridge/` folder into your project's `addons/` directory:

   ```
   your-project/
   └── addons/
       └── godot_bridge/
           ├── plugin.cfg
           ├── plugin.gd
           └── bridge_server.gd
   ```

2. **Enable the plugin.**

   In the Godot editor: **Project → Project Settings → Plugins**, find **Godot Bridge**, and set it to **Enable**.

3. **Verify it's running.**

   A **Bridge** tab appears in the bottom panel. The status label reads:

   - `Bridge: Listening :6505` — server is up, waiting for a connection
   - `Bridge: Connected` — a client (e.g. the CLI) is connected
   - `Bridge: Error (port 6505)` — port is already in use; see [Changing the port](#changing-the-port) below

## Changing the port

The default port is `6505`. To use a different port, go to **Project → Project Settings → General** and search for `godot_bridge/port`. Change the value and restart the editor.

## How it works

### Architecture

```
godot-bridge CLI  ──WebSocket──►  Godot Bridge Plugin  ──►  EditorInterface / Scene Tree
  (port 6505)
```

`plugin.gd` is an `EditorPlugin` that starts a `BridgeServer` node when the editor loads. `bridge_server.gd` runs a TCP/WebSocket listener in `_process()` — no threads involved.

The server accepts **one client at a time**. When a connection is active, it sends a heartbeat ping every 10 seconds. When the client disconnects, the server returns to listening.

### Protocol

All messages are JSON over WebSocket text frames.

**Request** (client → plugin):

```json
{"id": "abc123", "command": "node_tree", "args": {"path": "", "depth": 4}}
```

**Success response** (plugin → client):

```json
{"id": "abc123", "ok": true, "data": { ... }}
```

**Error response** (plugin → client):

```json
{"id": "abc123", "ok": false, "error": "No scene is open"}
```

The `id` field is echoed back so clients can match responses to requests.

### Supported commands

| Command | Required args | Description |
|---------|---------------|-------------|
| `editor_state` | — | Open scenes, selected nodes, active screen (2D/3D/Script) |
| `node_tree` | `path` (opt), `depth` (opt, default 4) | Scene tree as nested JSON |
| `node_get` | `path`, `detail` (`brief`\|`full`) | Node info; `full` includes all editor-visible properties, signals, groups |
| `node_add` | `type`, `parent` (opt), `name` (opt), `props` (opt) | Add a node; supports undo |
| `node_modify` | `path`, `props` | Set properties on a node; supports undo |
| `node_delete` | `path` | Remove a node; supports undo |
| `node_move` | `path`, `new_parent` | Reparent a node; supports undo |
| `scene_new` | `path`, `root_type` (opt, default `Node2D`), `root_name` (opt) | Create a new `.tscn` file and open it |
| `scene_open` | `path` | Open a `.tscn` file in the editor |
| `scene_save` | — | Save the currently open scene |
| `scene_run` | `path` (opt) | Play the main scene or a specific scene (F5/F6) |
| `scene_stop` | — | Stop the running scene |
| `script_open` | `path` | Open a script in the Script editor |
| `resource_list` | `path` (opt, default `res://`) | List files and subdirectories |
| `screenshot` | — | Capture the 2D viewport as a base64-encoded PNG |

### Property encoding

Godot types that have no direct JSON equivalent are encoded as arrays or objects:

| Godot type | JSON encoding |
|------------|---------------|
| `Vector2(x, y)` | `[x, y]` |
| `Vector3(x, y, z)` | `[x, y, z]` |
| `Color(r, g, b, a)` | `[r, g, b, a]` |
| `Rect2` | `{"pos": [x, y], "size": [w, h]}` |
| `NodePath` | `"path/string"` |

The plugin converts automatically in both directions — pass the same format back in `props` when writing.

## Troubleshooting

**Port already in use** — Another process is on 6505. Either stop it, or change the port via Project Settings (`godot_bridge/port`) and reconnect.

**Bridge tab doesn't appear** — The plugin is not enabled. Check **Project → Project Settings → Plugins**.

**Commands time out** — The CLI waits up to 30 seconds for a response. If a command hangs, check the Godot editor output panel for GDScript errors.

**`node_add` path is wrong after adding** — Node paths aren't stable until the scene is saved. Run `scene_save` after bulk node operations.
