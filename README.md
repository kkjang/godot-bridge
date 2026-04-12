# godot-bridge

AI-assisted Godot development — give Claude Code full control of the Godot 4.x editor.

```
Claude Code  -->  godot-bridge CLI  --WebSocket:6505-->  Godot editor plugin
                                                               |
Claude Code  <--  GDScript LSP  <--stdio-- gdscript-lsp-proxy --TCP:6005-- Godot LSP
```

## Components

| Directory | What it is |
|-----------|------------|
| [`godot-plugin/`](godot-plugin/README.md) | Godot 4.x editor plugin — WebSocket server that accepts JSON commands and drives `EditorInterface` |
| [`claude-plugin/`](claude-plugin/README.md) | Claude Code plugin — stdio↔TCP proxy that gives the LSP tool native GDScript intelligence |
| [`cli/`](cli/README.md) | `godot-bridge` CLI (Go) — *(not yet implemented)* shell interface to the Godot plugin |

## Quick start

### 1. Install the Godot plugin

Copy `godot-plugin/addons/godot_bridge/` into your project's `addons/` folder, then enable it in **Project → Project Settings → Plugins**.

### 2. Load the Claude Code plugin

```bash
# Build the proxy binary first (required on non-macOS-arm64 platforms)
cd claude-plugin && go build -o bin/gdscript-lsp-proxy ./src/

# Load for this session
claude --plugin-dir ./claude-plugin

# Or install permanently
claude plugin install ./claude-plugin
```

### 3. Control the editor

With Godot open and the plugin enabled, send JSON commands to `ws://localhost:6505`:

```json
{"id": "1", "command": "editor_state", "args": {}}
{"id": "2", "command": "node_add", "args": {"type": "Sprite2D", "name": "Hero", "props": {"position": [200, 150]}}}
{"id": "3", "command": "scene_save", "args": {}}
```

See [`godot-plugin/README.md`](godot-plugin/README.md) for the full command reference.

## Requirements

- Godot 4.3+
- Go 1.22+ (to build the proxy binary)
