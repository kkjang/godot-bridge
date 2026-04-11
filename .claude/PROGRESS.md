# godot-bridge — Implementation Progress

## Overview
CLI + Editor Plugin for AI-Assisted Godot Development.
See `PRD.md` for full specification.

**CLI language: Go** (not Python as originally drafted)

---

## Phase 1 — Minimum Viable Bridge

### Godot Plugin (`godot-plugin/addons/godot_bridge/`)
Branch: `claude/godot-bridge-setup-uq2zf`

- [x] `plugin.cfg` — plugin manifest
- [x] `plugin.gd` — EditorPlugin entry point, starts/stops WebSocket server, status bar indicator
- [x] `bridge_server.gd` — WebSocket server, command routing, JSON parsing
- [x] Commands: `editor_state`, `node_tree`, `node_get`, `scene_open`, `scene_save`
- [ ] Commands: `node_add`, `node_modify`, `node_delete`, `node_move` (Phase 2)
- [ ] Commands: `scene_run`, `scene_stop` (Phase 3)
- [ ] Commands: `script_open`, `resource_list`, `screenshot` (Phase 2)

### Go CLI (`cli/`)
Branch: TBD (separate session)

- [ ] Project scaffold (`go.mod`, `cmd/`, `internal/`)
- [ ] WebSocket client (`internal/connection/`)
- [ ] `status` command
- [ ] `editor state` command
- [ ] `node tree`, `node get` commands
- [ ] `scene open`, `scene save` commands
- [ ] `file read`, `file write`, `file list`, `file search` commands
- [ ] `reference` command (prints markdown cheat sheet)

### Supporting Files
- [x] `PRD.md`
- [x] `.claude/PROGRESS.md` (this file)
- [ ] `CLAUDE.md.example`
- [ ] `README.md`

---

## Phase 2 — Full Node Manipulation
Branch: TBD

- [ ] Plugin: `node_add`, `node_modify`, `node_delete`, `node_move` with undo support
- [ ] Plugin: `script_open`, `resource_list`, `screenshot`
- [ ] CLI: corresponding subcommands

---

## Phase 3 — Run / Debug
Branch: TBD

- [ ] Plugin: `scene_run`, `scene_stop`
- [ ] Plugin: error event push (compile errors, runtime errors)
- [ ] CLI: `scene run`, `scene stop`

---

## Notes

- Plugin port: `localhost:6505` (configurable via project setting `godot_bridge/port`)
- Protocol: JSON over WebSocket
- Request: `{"id": "abc123", "command": "node_tree", "args": {...}}`
- Response: `{"id": "abc123", "ok": true, "data": {...}}`
- Error: `{"id": "abc123", "ok": false, "error": "..."}`
- Detail levels: `brief` (default) / `full` controlled by `detail` arg
