# godot-bridge

CLI + Godot editor plugin for AI-assisted Godot development.

Use `README.md` for human-facing setup and usage. Use this file for implementation guidance and workflow constraints.

## Goal

- Build a token-efficient alternative to large MCP tool surfaces for Godot workflows.
- The intended shape is a small set of local components: a Go CLI, a Godot editor plugin, and a shared GDScript LSP bridge.
- Prefer simple command and transport layers over many tool-specific schemas.

## Working Model

- This repository is infrastructure for agentic Godot development, not necessarily the live Godot project itself.
- The Godot editor may be running a different target project while this repo provides the bridge, proxy, and tool integrations.
- Go and bridge code live in this repo. Godot-side editor semantics for `.gd` files come from whichever project is currently open in Godot.

## Architecture

```text
Coding tool  ->  godot-bridge CLI  ->  WebSocket :6505  ->  Godot editor plugin
Coding tool  ->  gdscript-lsp-proxy  ->  TCP :6005  ->  Godot GDScript LSP
```

- The CLI is for editor control and file-oriented workflows.
- The GDScript LSP bridge is for code intelligence.
- File operations can often happen directly on the filesystem without talking to the Godot editor.

## Tooling

- Go files (`cli/`, `gdscript-lsp/`): use `gopls`.
- GDScript files (`.gd`): use the configured GDScript LSP bridge with Godot running.

## Working In Subdirectories

- Check for a nearer `AGENTS.md` before editing files in a major subdirectory.
- Subdirectory `AGENTS.md` files provide local instructions for `godot-plugin/`, `gdscript-lsp/`, and `cli/`.
- The nearest `AGENTS.md` to the files you are editing should take precedence over this root file.

## Status

- `godot-plugin/`: implemented and supports scene, node, script, resource, screenshot, and run/stop editor commands.
- `gdscript-lsp/`: implemented and wired for Claude Code and OpenCode.
- `cli/`: planned, but not yet implemented.
- Remaining notable gap: pushed error/debug events from the running game/editor back to the agent.

## Repository layout

| Directory | Component |
|-----------|-----------|
| `godot-plugin/` | Godot 4.x editor plugin - WebSocket command server on `localhost:6505` |
| `gdscript-lsp/` | Shared GDScript LSP bridge plus tool-specific integrations |
| `cli/` | `godot-bridge` CLI (Go) - not yet implemented |

Keep project-wide guidance here and implementation-specific guidance in the nearest subdirectory `AGENTS.md`.
