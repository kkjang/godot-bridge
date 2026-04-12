# godot-bridge — Claude Code Plugin

A Claude Code plugin that gives the LSP tool native GDScript intelligence by bridging Claude Code's stdio-based LSP client to Godot's TCP-based GDScript Language Server.

```
Claude Code LSP Tool  --stdio-->  gdscript-lsp-proxy  --TCP-->  Godot :6005
```

## What this unlocks

Once loaded, Claude Code's LSP tool gains full GDScript support from the running Godot editor:

| LSP operation | Status | What you get |
|--------------|--------|--------------|
| `documentSymbol` | ✓ | All functions, variables, signals, classes in a `.gd` file |
| `hover` | ✓ | Type info and docs for any symbol |
| `goToDefinition` | ✓ | Jump to where a function or class is defined |
| `findReferences` | ✓ | All usages of a symbol |
| `workspaceSymbol` | ✗ | Not implemented by Godot's LSP |

Diagnostics (errors/warnings) arrive automatically as `new-diagnostics` notifications after any `documentSymbol` or `hover` call — no explicit operation needed.

## Requirements

- Godot 4.x editor open (starts the GDScript LSP on port 6005 automatically)
- Go toolchain installed (`go build` must work)

## Setup

### 1. Build the proxy binary

```bash
cd claude-plugin
go build -o bin/gdscript-lsp-proxy ./src/
```

The pre-built binary in `bin/` targets macOS arm64. Rebuild if you're on a different platform.

### 2. Load the plugin

**Development (this session only):**
```bash
claude --plugin-dir ./claude-plugin
```

**Permanent install:**
```bash
claude plugin install ./claude-plugin
```

Run `/reload-plugins` to pick up changes without restarting.

## Port configuration

Default is `6005`. To override, edit `.lsp.json` and change `GODOT_LSP_PORT`, or match it to **Godot → Editor Settings → Network → Language Server → Remote Port**.

## Files

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest (name, version) |
| `.lsp.json` | Registers `gdscript-lsp-proxy` as the LSP server for `.gd` files |
| `bin/gdscript-lsp-proxy` | Pre-built proxy binary |
| `src/main.go` | Proxy source — pure stdio↔TCP passthrough, ~120 lines |
| `go.mod` | Go module for the proxy |
