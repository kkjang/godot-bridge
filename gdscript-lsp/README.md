# gdscript-lsp

Shared GDScript LSP bridge for Godot 4.x plus tool-specific integrations.

For implementation guidance while editing the bridge or integrations, see `AGENTS.md`.

The Godot editor does not need to have this repository open. This repo owns the bridge and integrations; Godot can be running a separate target project. In that setup, transport still works normally, but GDScript workspace semantics come from the project currently open in Godot.

## Requirements

- Godot 4.x editor open on the target project
- Go 1.22+

## Build

```bash
go build -o bin/gdscript-lsp-proxy ./cmd/gdscript-lsp-proxy
```

## Use with Claude Code

```bash
cd gdscript-lsp && go build -o bin/gdscript-lsp-proxy ./cmd/gdscript-lsp-proxy
claude --plugin-dir ./integrations/claude
```

Or install it permanently:

```bash
claude plugin install ./gdscript-lsp/integrations/claude
```

## Use with OpenCode

Run `opencode` from the repo root after building the proxy. `opencode.json` configures:

- `gopls` for `.go`
- `gdscript-lsp-proxy` for `.gd`

OpenCode's `.gd` requests are forwarded to whichever project Godot currently has open.
