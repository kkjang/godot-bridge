# Godot Bridge CLI Skill

Copy the text below into any agent harness that can execute shell commands and inspect stdout, stderr, and exit codes.

```md
Use the `godot-bridge` CLI to control the currently open Godot editor through the Godot Bridge plugin.

Invocation:
- Prefer `godot-bridge ...` when the binary is installed or otherwise available on PATH.
- If the binary is not installed, use the environment's local invocation for this repository, for example `go run ./cmd/godot-bridge ...` from the `cli/` directory.
- Do not assume the current working directory is already correct. Use an explicit working directory or full command path when needed.

Environment assumptions:
- Godot must be running with the Godot Bridge plugin enabled.
- The bridge defaults to `127.0.0.1:6505` unless overridden with CLI flags.
- This CLI only covers plugin-backed editor commands. It does not read or write arbitrary project files.

Rules:
- Treat `godot-bridge spec` as the source of truth for available commands, flags, defaults, and plugin mappings.
- Before using unfamiliar commands or when the environment may have changed, run `godot-bridge spec` and inspect its JSON output.
- Prefer `godot-bridge` for live editor operations: scene open/save/run/stop, node inspection and mutation, script opening, viewport screenshots, and resource listing.
- Use normal filesystem and search tools separately for direct file manipulation.
- Use `--json` when structured output is needed for follow-up reasoning or transformations.
- Errors are written to stderr. Treat non-zero exits as command failures.

Recommended workflow:
1. Run `godot-bridge status` to confirm the bridge is reachable.
2. Run `godot-bridge editor state --json` to inspect the current scene and selection.
3. If you need command discovery, run `godot-bridge spec`.
4. For scene structure, use `godot-bridge node tree [PATH] --json` or `godot-bridge node get PATH --detail full --json`.
5. For edits, prefer small explicit operations such as `node add`, `node modify`, `node move`, `node delete`, then `scene save`.
6. Use `godot-bridge screenshot --json` when you need to inspect the current 2D editor viewport visually.

Common commands:
- `godot-bridge status`
- `godot-bridge spec`
- `godot-bridge editor state --json`
- `godot-bridge node tree /root/Main --json`
- `godot-bridge node get /root/Main/Player --detail full --json`
- `godot-bridge node add Sprite2D --parent /root/Main --name Hero --props '{"position":[200,150]}'`
- `godot-bridge node modify /root/Main/Hero --props '{"position":[240,180]}'`
- `godot-bridge scene save`
- `godot-bridge screenshot --json`
- `godot-bridge resource list res:// --json`

Behavior notes:
- Scene and node paths should use Godot-style paths like `/root/Main/Hero`.
- `scene run` without a path runs the main scene. With a path, it opens and runs that scene.
- `resource list` uses Godot's resource filesystem view, so paths should be `res://...`.
- `screenshot` returns metadata in text mode and image payload data in JSON mode.
```
