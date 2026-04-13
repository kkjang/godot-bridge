# godot-bridge

CLI + Godot editor plugin for AI-assisted Godot development.

Use `README.md` for human-facing setup and usage. External bootstrap instructions for real game projects live there as well. Use this file for implementation guidance and workflow constraints.

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
- `cli/`: implemented and buildable as the `godot-bridge` Go CLI.
- Remaining notable gap: pushed error/debug events from the running game/editor back to the agent.

## Repository layout

| Directory | Component |
|-----------|-----------|
| `godot-plugin/` | Godot 4.x editor plugin - WebSocket command server on `localhost:6505` |
| `gdscript-lsp/` | Shared GDScript LSP bridge plus tool-specific integrations |
| `cli/` | `godot-bridge` CLI (Go) for plugin-backed editor control |

## Validation

- `cli/`: run `go test ./...` from `cli/`.
- `gdscript-lsp/`: run `go test ./...` from `gdscript-lsp/`.
- `godot-plugin/`: run `bash scripts/test.sh` from `godot-plugin/`.
- On macOS, if Godot is not on `PATH`, use `GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/test.sh` from `godot-plugin/`.
- When a change spans multiple components, run the relevant validation command for each touched component before finishing.

## Releases

- `cli/`, `gdscript-lsp/`, and `godot-plugin/` are versioned independently through `releases.yaml`.
- Use a small release PR to bump versions intentionally. Do not infer or bump release versions casually.
- Release versions must be semver strings like `v0.1.0`.
- The requested versions map to module tags:
  - `cli: vX.Y.Z` -> `cli/vX.Y.Z`
  - `gdscript-lsp: vX.Y.Z` -> `gdscript-lsp/vX.Y.Z`
  - `godot-plugin: vX.Y.Z` -> `godot-plugin/vX.Y.Z`
- Releases are created only from the default branch after the `CI` workflow succeeds.
- The release workflow creates GitHub Releases with GitHub-generated changelog notes. The Godot plugin release also uploads a zip artifact containing `addons/godot_bridge/`.
- Generated notes are currently repo-wide, so they may include unrelated changes outside the released module.
- For release PR drafting, use `skills/release-pr/SKILL.md` and keep changelog sections strict path-only in v1:
  - `cli/**`
  - `gdscript-lsp/**`
  - `godot-plugin/**`
- Do not include shared-file changes in those drafted changelog sections unless the user explicitly asks for them.

Keep project-wide guidance here and implementation-specific guidance in the nearest subdirectory `AGENTS.md`.
