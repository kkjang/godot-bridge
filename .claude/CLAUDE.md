# godot-bridge

CLI + Godot editor plugin for AI-assisted Godot development.

## Tooling

- **Go files (`cli/`, `claude-plugin/src/`):** use the `gopls` LSP plugin — do not grep for symbols, definitions, or references.
- **GDScript files (`.gd`):** use the LSP tool for hover/definitions/diagnostics (requires Godot editor running). See `CLAUDE_PLUGIN.md`. Read files directly for content.

## Repository layout

| Directory | Component |
|-----------|-----------|
| `godot-plugin/` | Godot 4.x editor plugin — WebSocket command server on `localhost:6505` |
| `claude-plugin/` | Claude Code LSP plugin — stdio↔TCP proxy for GDScript LSP on `localhost:6005` |
| `cli/` | `godot-bridge` CLI (Go) — not yet implemented |

## Context files

| File | Contents |
|------|----------|
| [`GODOT_PLUGIN.md`](.claude/GODOT_PLUGIN.md) | Protocol, full command table, property encoding |
| [`CLAUDE_PLUGIN.md`](.claude/CLAUDE_PLUGIN.md) | LSP proxy — what it is, supported operations, build & install |
| [`CLI.md`](.claude/CLI.md) | Planned CLI commands and design notes |
| [`PRD.md`](.claude/PRD.md) | Full product spec: architecture and design decisions |
| [`PROGRESS.md`](.claude/PROGRESS.md) | Implementation checklist by phase |
