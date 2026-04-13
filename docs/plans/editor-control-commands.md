# Plan 1: Missing Editor Control Commands

## Context

The godot-bridge plugin/CLI currently has 15 commands covering scene CRUD, node tree manipulation, script opening, resource listing, and 2D screenshots. Several high-value editor control capabilities are missing that block common game creation workflows: signal wiring, animation authoring, scene composition, project configuration, and debug feedback.

This plan adds those missing commands to the plugin (`bridge_server.gd`) and CLI (`main.go`), following the existing command dispatch pattern.

---

## Implementation Order

1. **Signal connections** — needed for any interactive game
2. **Scene instancing** — needed for scene composition and importing 3D models
3. **Project settings** — needed for input maps, autoloads, display config
4. **AnimationPlayer control** — keyframe animation authoring
5. **Debug/error streaming** — feedback loop from running game

---

## 1. Signal Connections

### Plugin commands

**`signal_connect`** — Connect a signal from one node to a method on another
- Args: `{ "source": "/root/Main/Button", "signal": "pressed", "target": "/root/Main/Game", "method": "on_button_pressed" }`
- Response: `{ "source": "...", "signal": "pressed", "target": "...", "method": "..." }`
- Godot API: `source.connect(signal_name, Callable(target, method))` via EditorUndoRedoManager
- Validation: check both nodes exist, signal exists on source via `has_signal()`

**`signal_disconnect`** — Remove a signal connection
- Args: `{ "source": "...", "signal": "...", "target": "...", "method": "..." }`
- Godot API: `source.disconnect(signal_name, Callable(target, method))`

**`signal_connections`** — List outgoing connections from a node
- Args: `{ "path": "/root/Main/Button" }`
- Response: `{ "connections": [{"signal": "pressed", "target": "/root/Main/Game", "method": "on_button_pressed", "flags": 0}] }`
- Godot API: iterate `node.get_signal_list()`, then `node.get_signal_connection_list(signal_name)` for each

### CLI commands
`godot-bridge signal connect --source PATH --signal NAME --target PATH --method NAME`
`godot-bridge signal disconnect --source PATH --signal NAME --target PATH --method NAME`
`godot-bridge signal list PATH`

New `runSignal()` top-level handler in `main.go`.

---

## 2. Scene Instancing

### Plugin command

**`node_instance`** — Instantiate a PackedScene as a child node
- Args: `{ "scene": "res://enemies/goblin.tscn", "parent": "/root/Main/Enemies", "name": "Goblin1" }`
- Response: node brief of the instanced root
- Godot API: `load(path) as PackedScene` → `.instantiate()` → `parent.add_child(inst)` → set `inst.owner = edited_scene_root`
- Via UndoRedo, closely mirrors `_cmd_node_add`
- Must verify loaded resource `is PackedScene`

### CLI command
`godot-bridge node instance SCENE_PATH [--parent PATH] [--name NAME]`

Added to existing `runNode()` switch.

---

## 3. Project Settings

### Plugin commands

**`project_get`** — Read project settings
- Args: `{ "keys": ["display/window/size/viewport_width", "input/jump"] }` or `{ "prefix": "input/" }`
- Response: `{ "settings": { "display/window/size/viewport_width": 1920, ... } }`
- Godot API: `ProjectSettings.get_setting(key)`, `ProjectSettings.get_property_list()` for prefix enumeration
- Uses existing `_variant_to_json()` for serialization

**`project_set`** — Modify project settings
- Args: `{ "settings": { "display/window/size/viewport_width": 1280 } }`
- Response: `{ "updated": ["display/window/size/viewport_width"] }`
- Godot API: `ProjectSettings.set_setting(key, value)` + `ProjectSettings.save()`
- No undo/redo (project settings are outside the scene undo stack)

### CLI commands
`godot-bridge project get [--keys KEY,...] [--prefix PREFIX]`
`godot-bridge project set --settings JSON`

New `runProject()` top-level handler.

---

## 4. AnimationPlayer Control

### Plugin commands

**`animation_list`** — List animations on an AnimationPlayer
- Args: `{ "path": "/root/Main/AnimationPlayer" }`
- Response: `{ "animations": [{"name": "idle", "length": 1.0, "loop_mode": "linear", "track_count": 3}] }`
- Godot API: `player.get_animation_list()`, `player.get_animation(name)`

**`animation_get`** — Get animation track/keyframe data
- Args: `{ "path": "...", "animation": "idle" }`
- Response: `{ "name": "idle", "length": 1.0, "tracks": [{"path": "Sprite2D:frame", "type": "value", "keyframes": [{"time": 0.0, "value": 0}]}] }`
- Godot API: `animation.track_get_path()`, `animation.track_get_key_count()`, `animation.track_get_key_value()`

**`animation_new`** — Create a new animation with tracks
- Args: `{ "path": "...", "name": "walk", "length": 1.0, "loop_mode": "linear", "tracks": [{"path": ".:position", "type": "value", "keyframes": [...]}] }`
- Godot API: `Animation.new()` → `add_track()` → `track_insert_key()` → add to default AnimationLibrary
- Via UndoRedo (clone entire animation for undo)
- V1: support `value` tracks only (covers 90% of 2D use cases)

**`animation_modify`** — Update tracks/keyframes on existing animation
- Args: `{ "path": "...", "animation": "walk", "length": 2.0, "tracks": [...] }`
- Replaces tracks that match path, adds new ones

### CLI commands
`godot-bridge animation list PATH`
`godot-bridge animation get PATH --animation NAME`
`godot-bridge animation new PATH --data JSON`
`godot-bridge animation modify PATH --animation NAME --data JSON`

New `runAnimation()` top-level handler.

---

## 5. Debug/Error Streaming

### Protocol extension

Current protocol is request/response only. Debug streaming requires **push messages**:
```json
{"type": "event", "event": "output", "data": {"message": "Hello", "timestamp": 1234}}
{"type": "event", "event": "error", "data": {"message": "Null ref", "script": "res://player.gd", "line": 42}}
```

This is backward-compatible — the CLI already filters `"type": "ping"` messages. Events are a new `type` value.

### Plugin commands

**`debug_subscribe`** — Start streaming debug events
- Args: `{ "events": ["output", "error"] }` (or omit for all)
- Response: `{ "subscribed": ["output", "error"] }`
- After subscription, push events arrive on the same WebSocket

**`debug_unsubscribe`** — Stop streaming

### Plugin architecture
- New file: `godot-plugin/addons/godot_bridge/bridge_debugger.gd` extending `EditorDebuggerPlugin`
- Registered in `plugin.gd` via `add_debugger_plugin()`
- Forwards captured messages to `bridge_server.gd` which pushes them over WebSocket

### CLI command
`godot-bridge debug watch [--events output,error] [--json]`
- Long-running command that keeps WebSocket open
- Prints events as they arrive (JSONL in `--json` mode, formatted text otherwise)
- Exits on SIGINT
- Requires new `sendAndStream()` function alongside existing `sendCommand()`

### Historical single-client limitation
At the time of this plan, the bridge accepted one client at a time and `debug watch` blocked other CLI commands. That limitation has since been removed by the multi-connection transport work.

---

## Files to Modify

| File | Changes |
|------|---------|
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | ~12 new `_cmd_*` functions, dispatch entries |
| `cli/cmd/godot-bridge/main.go` | ~4 new `run*()` handlers, ~14 spec entries, streaming support |
| `godot-plugin/addons/godot_bridge/plugin.gd` | Register EditorDebuggerPlugin (debug streaming only) |
| `godot-plugin/addons/godot_bridge/bridge_debugger.gd` | **New file** — EditorDebuggerPlugin impl (debug streaming only) |

---

## Verification

After each group of commands:
1. Build CLI: `cd cli && go build ./cmd/godot-bridge`
2. Run `godot-bridge spec --markdown` — verify new commands appear
3. With Godot running + plugin active, test each command manually
4. Verify undo/redo works for mutating commands (signal connect, node instance, animation new)
5. For debug streaming: run a scene with `print()` calls, verify output in `debug watch`
