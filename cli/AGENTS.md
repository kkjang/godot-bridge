# cli

Planned Go CLI for driving the Godot editor through the bridge plugin.

Use `README.md` for the planned user-facing command surface. Use this file for implementation guidance.

## Scope

- This area is not yet implemented.
- Keep new work aligned with the command model documented here and in `README.md`.

## Tooling

- Go files here should use `gopls`.

## Working Notes

- The CLI should be a thin shell around the Godot bridge protocol.
- Prefer clear command mapping over heavy abstraction while the surface area is still evolving.

## Planned Commands

- `godot-bridge status`
- `godot-bridge editor state`
- `godot-bridge node tree [PATH]`
- `godot-bridge node get PATH`
- `godot-bridge node add TYPE --parent PATH --name NAME [--props '{}']`
- `godot-bridge node modify PATH --props '{...}'`
- `godot-bridge node delete PATH`
- `godot-bridge node move PATH --new-parent PATH`
- `godot-bridge scene new PATH [--root-type Node2D] [--root-name NAME]`
- `godot-bridge scene open PATH`
- `godot-bridge scene save`
- `godot-bridge scene run [PATH]`
- `godot-bridge scene stop`
- `godot-bridge script open PATH`
- `godot-bridge screenshot`
- `godot-bridge file read PATH`
- `godot-bridge file write PATH --content STR`
- `godot-bridge file list [DIR]`
- `godot-bridge file search QUERY`
- `godot-bridge reference`

## Design Constraints

- Default output should be compact text, with `--json` for structured output.
- Errors go to stderr and data goes to stdout.
- Editor commands should use WebSocket `localhost:6505` with short connect and command timeouts.
- Keep distribution simple: one fast static binary is preferred.

## References

- `README.md` - planned user-facing command surface
