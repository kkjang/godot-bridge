# Plan: Running-Game Screenshot (`game_screenshot`)

Part of the 2D game enablement series — see `docs/plans/2d-game-overview.md`.

## Context

Today an agent can run a scene and watch printed output, but can't see the actual game
pixels. Every visual tweak (spacing, scale, colors, animation timing) is a guess until a
human looks. The existing `screenshot` command uses
`EditorInterface.get_editor_viewport_2d()` (`bridge_server.gd:1228`), which is only the
editor's 2D canvas — not the running game child process.

With a running-game screenshot, the iteration loop becomes:

1. Agent edits a scene / resource / script.
2. `godot-bridge scene run` (already implemented).
3. `godot-bridge game screenshot` — inspect the actual rendered frame.
4. `godot-bridge scene stop`.

This is the feedback primitive every later 2D plan verifies against, so it should land
first.

## Design

- New plugin command `game_screenshot` (args: `{}` → `{png_base64, width, height}`).
- New CLI: `godot-bridge game screenshot [--out FILE]` (mirrors existing `screenshot`).
- Error path: if no game is running, return `{"error": "no running game"}` so the agent
  can decide to `scene run` first.

### Capture path

The game runs in a child process, so the editor cannot grab its framebuffer directly. Two
candidate implementations in order of preference:

**Option A — EditorDebuggerPlugin capture (preferred).**
- Plugin-side: new `EditorDebuggerPlugin` subclass registered in `plugin.gd` via
  `add_debugger_plugin()`. Exposes `send_message("godot_bridge:screenshot", [])`.
- Runtime-side: a tiny autoload `addons/godot_bridge/runtime/bridge_runtime.gd` registered
  by the plugin via `add_autoload_singleton("GodotBridgeRuntime", ...)`. It calls
  `EngineDebugger.register_message_capture("godot_bridge", _on_capture)` and responds to
  `screenshot` by grabbing `get_tree().root.get_texture().get_image()`, PNG-encoding, and
  sending back on the same debugger channel.
- Plugin receives the reply through the `EditorDebuggerPlugin._capture` virtual, resolves
  the pending command id, and returns `{png_base64, width, height}` to the agent.
- The request/response is correlated by a monotonic sequence id embedded in the capture
  message.

**Option B — file drop fallback.** If `EditorDebuggerPlugin` capture proves flaky in
practice (timing, threading, etc.), the runtime helper writes the PNG to `user://` with a
known filename and posts an `output` debug event `godot_bridge:screenshot_ready`. The
plugin waits for the event (short timeout), reads the file, base64-encodes, returns.

Ship Option A first; keep Option B as a contingency in the same PR if the first iteration
is unreliable.

### Runtime helper lifecycle

- The autoload is inert in exported builds (no-op guard on `OS.is_debug_build()` + presence
  of the debugger connection).
- Registering it as an autoload is a project-level change. The plugin's `_enter_tree`
  should add it via `add_autoload_singleton` and `_exit_tree` should
  `remove_autoload_singleton` — both are idempotent.
- The helper must live at a stable path so the autoload entry keeps resolving after the
  plugin is disabled/re-enabled.

## Critical files

| File | Change |
|------|--------|
| `godot-plugin/addons/godot_bridge/plugin.gd` | Register autoload and `EditorDebuggerPlugin` subclass. |
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | `_cmd_game_screenshot` handler + dispatch entry near `bridge_server.gd:200-240`. Pending-request correlation table. |
| `godot-plugin/addons/godot_bridge/bridge_debugger_plugin.gd` | **new** — `EditorDebuggerPlugin` subclass; `_capture` dispatches to `bridge_server`. |
| `godot-plugin/addons/godot_bridge/runtime/bridge_runtime.gd` | **new** — autoload; registers `EngineDebugger.register_message_capture`. |
| `cli/cmd/godot-bridge/main.go` | Register `game` subcommand group; add `game screenshot` + spec entry. |
| `skills/godot-bridge/SKILL.md` | Mention the new command in the examples section. |
| `AGENTS.md` | Remove "pushed error/debug events from the running game/editor back to the agent" gap note once this lands (game screenshots close the visual half). |

## Patterns to reuse

- Existing output framing: `_send_ok(id, {png_base64, width, height})` mirrors
  `_cmd_screenshot` at `bridge_server.gd:1228`.
- CLI `--out FILE` handling pattern from the existing `screenshot` command in
  `main.go:607`.

## Verification

1. Open a scratch project with the plugin enabled.
2. `godot-bridge scene run res://smoke.tscn`.
3. `godot-bridge game screenshot --out /tmp/game.png` — PNG is non-empty and visually
   differs from `godot-bridge screenshot --out /tmp/editor.png`.
4. `godot-bridge scene stop`.
5. Negative test: call `game screenshot` with no game running → clear error.
6. Stress: run + screenshot + stop in a loop 20 times — no orphaned processes, no wedged
   debugger capture state.
7. `cd cli && go test ./...` and `cd godot-plugin && bash scripts/test.sh`.
8. `godot-bridge spec --markdown` lists the new command.
