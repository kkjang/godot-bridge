# Claude Code Plugin (GDScript LSP)

**Location:** `claude-plugin/`  
**Purpose:** Gives Claude Code's LSP tool native GDScript intelligence by bridging its stdio-based LSP client to Godot's TCP-based GDScript Language Server.

```
Claude Code LSP Tool  --stdio-->  gdscript-lsp-proxy  --TCP-->  Godot :6005
```

## Why it exists

Claude Code launches language servers as stdio subprocesses. Godot's GDScript LSP listens on a TCP socket (`localhost:6005`), started automatically when the Godot editor opens. The proxy is a pure passthrough — reads `Content-Length`-framed LSP messages from stdin, forwards to TCP, pipes responses back. No message interpretation.

## Supported LSP operations

| Operation | Status | What you get |
|-----------|--------|--------------|
| `documentSymbol` | ✓ | All functions, variables, signals, classes in a `.gd` file |
| `hover` | ✓ | Type info and docs for any symbol |
| `goToDefinition` | ✓ | Jump to where a function/class is defined |
| `findReferences` | ✓ | All usages of a symbol |
| `workspaceSymbol` | ✗ | Not implemented — Godot returns "Method not found: workspace/symbol" |

**Diagnostics** are not an explicit operation. Godot's LSP pushes `textDocument/publishDiagnostics` passively after any `documentSymbol` or `hover` call. These surface as `new-diagnostics` system reminders. If no reminder appears, the file is clean.

## Files

```
claude-plugin/
├── .claude-plugin/plugin.json   — plugin manifest (name, version)
├── .lsp.json                    — maps .gd → gdscript-lsp-proxy
├── bin/gdscript-lsp-proxy       — pre-built binary (macOS arm64)
├── src/main.go                  — proxy source (~120 lines)
└── go.mod                       — Go module (github.com/kkjang/godot-bridge/claude-plugin)
```

`.lsp.json` command: `${CLAUDE_PLUGIN_ROOT}/bin/gdscript-lsp-proxy`

## Build

```bash
cd claude-plugin && go build -o bin/gdscript-lsp-proxy ./src/
```

Required on non-macOS-arm64 platforms. The pre-built binary covers macOS arm64.

## Load / install

```bash
# This session only
claude --plugin-dir ./claude-plugin

# Permanent (user scope)
claude plugin install ./claude-plugin
```

Run `/reload-plugins` to pick up changes without restarting.

## Port

Default `6005` via `GODOT_LSP_PORT` env in `.lsp.json`. To override: edit `.lsp.json` or match **Godot → Editor Settings → Network → Language Server → Remote Port**.
