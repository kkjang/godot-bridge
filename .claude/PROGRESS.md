# godot-bridge — Implementation Progress

## Overview
CLI + Editor Plugin for AI-Assisted Godot Development.
See `PRD.md` for full specification.

**CLI language: Go** (not Python as originally drafted)

---

## Phase 1 — Minimum Viable Bridge ✅

### Godot Plugin (`godot-plugin/addons/godot_bridge/`)
- [x] `plugin.cfg` — plugin manifest
- [x] `plugin.gd` — EditorPlugin entry point, starts/stops WebSocket server, status bar indicator
- [x] `bridge_server.gd` — WebSocket server, command routing, JSON parsing
- [x] Commands: `editor_state`, `node_tree`, `node_get`, `scene_new`, `scene_open`, `scene_save`

### Supporting Files
- [x] `.claude/PRD.md`
- [x] `.claude/PROGRESS.md` (this file)
- [x] `.claude/GODOT_PLUGIN.md`
- [x] `.claude/CLAUDE_PLUGIN.md`
- [x] `.claude/CLI.md`
- [x] `godot-plugin/README.md`
- [x] `claude-plugin/README.md`
- [x] `cli/README.md`
- [x] `README.md` (root)

---

## Phase 2 — Full Node Manipulation ✅

### Godot Plugin
- [x] `node_add` — add any node type by ClassDB name, with initial props
- [x] `node_modify` — set properties via JSON, with undo support
- [x] `node_delete` — remove a node with undo support
- [x] `node_move` — reparent a node with undo support
- [x] `script_open` — open a script in the editor
- [x] `resource_list` — list files in a project directory
- [x] `screenshot` — capture editor viewport as base64 PNG
- [x] Property coercion: `Vector2`, `Vector3`, `Color`, `PackedVector2Array`, `PackedColorArray`
- [x] Node paths use clean user-facing format (`/root/Main/Hero`, not editor-internal paths)

### GDScript LSP proxy (`claude-plugin/`)
- [x] stdio-to-TCP proxy source (`claude-plugin/src/main.go`)
- [x] Pre-built binary (`claude-plugin/bin/gdscript-lsp-proxy`)
- [x] Claude Code plugin wiring (`.lsp.json`, `.claude-plugin/plugin.json`)

### Go CLI (`cli/`)
- [ ] Project scaffold — not started

---

## Phase 3 — Run / Debug
- [x] `scene_run` — run project or specific scene (F5/F6 equivalent)
- [x] `scene_stop` — stop running scene
- [ ] Error event push (compile errors, runtime errors from running game)

---

## Not Planned / Out of Scope


---

## Notes

- Plugin port: `localhost:6505` (configurable via project setting `godot_bridge/port`)
- Protocol: JSON over WebSocket
- Request: `{"id": "abc123", "command": "node_tree", "args": {...}}`
- Response: `{"id": "abc123", "ok": true, "data": {...}}`
- Error: `{"id": "abc123", "ok": false, "error": "..."}`
- Detail levels: `brief` (default) / `full` controlled by `detail` arg
