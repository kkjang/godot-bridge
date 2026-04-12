# cli

Go CLI for driving the Godot editor through the bridge plugin.

Use `README.md` for the user-facing command surface. Use this file for implementation guidance.

## Scope

- Keep new work aligned with the command model documented here and in `README.md`.
- This CLI only covers plugin-backed editor commands.

## Tooling

- Go files here should use `gopls`.

## Working Notes

- The CLI should be a thin shell around the Godot bridge protocol.
- Prefer clear command mapping over heavy abstraction while the surface area is still evolving.

## Supported Commands

- `godot-bridge status`
- `godot-bridge spec [--markdown]`
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
- `godot-bridge resource list [DIR]`

## Design Constraints

- Default output should be compact text, with `--json` for structured output.
- Errors go to stderr and data goes to stdout.
- Editor commands should use WebSocket `localhost:6505` with short connect and command timeouts.
- Keep distribution simple: one fast static binary is preferred.

## Spec Source Of Truth

- The CLI's built-in `spec` output is the machine-readable source of truth for the public command surface.
- When changing commands, flags, defaults, descriptions, or plugin mappings, update the code behind `godot-bridge spec` first.
- After changing the spec, regenerate the README command table from `godot-bridge spec --markdown` so docs stay aligned with the shipped CLI.
- Keep `README.md` and the built-in spec aligned. Do not manually edit the README command table without updating the CLI spec.
- Keep `skills/godot-bridge.md` aligned with the built-in spec and current command behavior so users can copy it into their own agent setups.
- Keep `skills/godot-bridge.md` generic across agent harnesses. Do not bake Claude-, OpenCode-, or tool-specific wiring into the generic skill.

## References

- `README.md` - user-facing command surface and command table derived from `godot-bridge spec --markdown`
- `skills/godot-bridge.md` - copyable agent skill for external setups
