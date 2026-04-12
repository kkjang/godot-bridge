# CLI (godot-bridge)

**Location:** `cli/`  
**Language:** Go  
**Status:** Not yet implemented.

## What it will be

A single `godot-bridge` binary that wraps the Godot plugin's WebSocket API in familiar shell subcommands. Agents discover commands via `godot-bridge reference` (prints a compact markdown cheat sheet) — one bash tool instead of dozens of MCP tool definitions.

## Planned commands

```
# Requires Godot editor running with plugin enabled
godot-bridge status                                    Check connection, show project info
godot-bridge editor state                              Open scenes, selected nodes, active screen

godot-bridge node tree [PATH]                          Scene tree from PATH (default: root)
godot-bridge node get PATH                             Full node details
godot-bridge node add TYPE --parent PATH --name NAME [--props '{}']
godot-bridge node modify PATH --props '{"position":[100,200]}'
godot-bridge node delete PATH
godot-bridge node move PATH --new-parent PATH

godot-bridge scene new PATH [--root-type Node2D] [--root-name NAME]
godot-bridge scene open PATH
godot-bridge scene save
godot-bridge scene run [PATH]                          F5/F6 equivalent
godot-bridge scene stop

godot-bridge script open PATH
godot-bridge screenshot                                Saves PNG, prints path

# File ops — no editor required
godot-bridge file read PATH
godot-bridge file write PATH --content STR
godot-bridge file list [DIR]
godot-bridge file search QUERY

godot-bridge reference                                 Print command reference as markdown
```

## Design notes

- Output: compact human/agent-readable text by default; `--json` for structured output
- Errors to stderr, data to stdout
- Connection: WebSocket `localhost:6505`, 5 s connect timeout, 30 s command timeout
- Single static binary — no runtime deps, fast startup for agent loops

See `PRD.md` for full specification and design decisions.
