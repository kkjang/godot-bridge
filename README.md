# godot-bridge

AI-assisted Godot development with shared integrations for Claude Code, OpenCode, and similar tools.

This repository provides the bridge components and tool integrations. The live Godot project can be a different workspace currently open in the editor.

For coding-agent instructions and implementation guidance, see `AGENTS.md`.

## Components

| Directory | What it is |
|-----------|------------|
| [`godot-plugin/`](godot-plugin/README.md) | Godot 4.x editor plugin exposing a WebSocket command server on `localhost:6505` |
| [`gdscript-lsp/`](gdscript-lsp/README.md) | Shared GDScript LSP bridge plus tool-specific integrations |
| [`cli/`](cli/README.md) | `godot-bridge` CLI (Go) for editor control through the plugin |

## Quick start

### 1. Install the Godot plugin

Copy `godot-plugin/addons/godot_bridge/` into your target project's `addons/` folder, then enable it in **Project -> Project Settings -> Plugins**.

### 2. Build the shared GDScript LSP bridge

```bash
cd gdscript-lsp && go build -o bin/gdscript-lsp-proxy ./cmd/gdscript-lsp-proxy
```

### 3. Connect your coding tool

**Claude Code**

```bash
claude --plugin-dir ./gdscript-lsp/integrations/claude
```

Or install it permanently:

```bash
claude plugin install ./gdscript-lsp/integrations/claude
```

**OpenCode**

Run `opencode` from the repo root. `opencode.json` configures:

- `gopls` for `.go`
- `gdscript-lsp-proxy` for `.gd`

### 4. Send editor commands

Use the CLI with Godot open and the plugin enabled:

```bash
cd cli && go run ./cmd/godot-bridge status
cd cli && go run ./cmd/godot-bridge editor state
cd cli && go run ./cmd/godot-bridge node add Sprite2D --parent /root/Main --name Hero --props '{"position":[200,150]}'
```

The CLI is a thin wrapper over the plugin protocol. The currently supported plugin-backed commands are documented in `cli/README.md`.

You can also send JSON directly to `ws://localhost:6505`:

```json
{"id": "1", "command": "editor_state", "args": {}}
{"id": "2", "command": "node_add", "args": {"type": "Sprite2D", "name": "Hero", "props": {"position": [200, 150]}}}
{"id": "3", "command": "scene_save", "args": {}}
```

See `godot-plugin/README.md` for the plugin API surface.

## Requirements

- Godot 4.3+
- Go 1.22+
