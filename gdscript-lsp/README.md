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

## Test

```bash
go test ./...
```

## Install

Install the proxy onto `PATH` from any repository:

```bash
go install github.com/kkjang/godot-bridge/gdscript-lsp/cmd/gdscript-lsp-proxy@latest
gdscript-lsp-proxy --version
```

The proxy is meant to be launched by an LSP client over stdio. It is not intended to run as a background service.

## Use with Claude Code

```bash
claude --plugin-dir ./gdscript-lsp/integrations/claude
```

Or install it permanently:

```bash
claude plugin install ./gdscript-lsp/integrations/claude
```

The Claude integration expects `gdscript-lsp-proxy` to be available on `PATH`.

## Use with OpenCode

Copy or merge `integrations/opencode/opencode.json` into the game project's OpenCode config.

The repo-root `opencode.json` is a convenience config for working in this repository itself. Both configs use `gdscript-lsp-proxy` from `PATH`.

The OpenCode config enables:

- `gopls` for `.go`
- `gdscript-lsp-proxy` for `.gd`

OpenCode's `.gd` requests are forwarded to whichever project Godot currently has open.
