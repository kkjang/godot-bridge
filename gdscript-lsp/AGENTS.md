# gdscript-lsp

Shared GDScript LSP bridge plus tool-specific integrations.

Use `README.md` for setup and integration steps. Use this file for implementation constraints.

## Scope

- Work here when changing the stdio-to-TCP proxy or its tool adapters.
- The shared Go proxy lives under `cmd/gdscript-lsp-proxy/`.
- Claude-specific integration files live under `integrations/claude/`.

## Tooling

- Go files here should use `gopls`.
- The GDScript LSP target is the Godot editor listening on `localhost:6005`.

## Purpose

- This bridge converts stdio-based LSP clients into Godot's TCP-based GDScript LSP.
- It should remain a transport adapter, not a semantic layer.

## Build

```bash
go build -o bin/gdscript-lsp-proxy ./cmd/gdscript-lsp-proxy
```

## Supported LSP Surface

- Works for `documentSymbol`, `hover`, `goToDefinition`, and `findReferences`.
- `workspaceSymbol` is not implemented by Godot.
- Diagnostics are pushed passively by Godot after normal LSP requests.

## Integrations

- Claude Code wiring lives in `integrations/claude/`.
- OpenCode wiring lives at the repo root in `opencode.json`.
- Both clients share the same proxy binary.

## Working Notes

- This repo may not be the same workspace currently open in Godot.
- The proxy should stay tool-agnostic: it forwards LSP transport and should not assume Claude-specific behavior.
- Workspace-specific GDScript semantics come from the project currently open in Godot, not necessarily this repository.

## Port

- Default port is `6005` via `GODOT_LSP_PORT`.
- Match it to Godot's Language Server remote port if it changes.
