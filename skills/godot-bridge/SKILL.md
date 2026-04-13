---
name: godot-bridge
description: Use the Godot Bridge tool suite for Godot editor control and GDScript-aware workflows
---

## What I do

- Guide work across the three Godot Bridge components: `gdscript-lsp-proxy`, the `godot-bridge` CLI, and the Godot editor plugin.
- Prefer the lightest reliable feedback loop for the task.
- Keep harness-specific wiring separate from this workflow guidance.

## When to use me

Use this skill when working in a Godot project that may use the Godot Bridge tool suite.

## Workflow

1. For `.gd` files, prefer the configured GDScript LSP first when it is installed and available.
2. Use normal LSP requests and follow-up inspection to surface diagnostics efficiently before trying heavier validation.
3. Use filesystem tools directly for ordinary project file edits.
4. Use the `godot-bridge` CLI for live editor operations such as scene open/save/run/stop, node inspection and mutation, signal wiring, scene instancing, project settings, animation authoring, script opening, screenshots, resource listing, debug streaming, and editor state inspection.
5. Treat `godot-bridge spec` as the source of truth for CLI commands, flags, defaults, and plugin mappings.
6. If LSP and direct inspection are not enough, escalate to heavier checks like running Godot in headless mode as smoke tests when appropriate.

## Components

- `gdscript-lsp-proxy`: bridges stdio-based LSP clients to Godot's TCP-based GDScript language server.
- `godot-bridge`: CLI for plugin-backed editor control.
- Godot Bridge plugin: runs in the editor and exposes the command surface used by the CLI.

## Environment assumptions

- Godot should be running with the target project open when using the live editor bridge or the GDScript LSP.
- The Godot Bridge plugin defaults to `127.0.0.1:6505` unless configured otherwise.
- The Godot GDScript LSP defaults to `localhost:6005` unless configured otherwise.
- The repository containing the bridge code may be different from the game project currently open in Godot.

## CLI usage

- Prefer `godot-bridge ...` when the binary is installed and available on `PATH`.
- If the binary is not installed, use the environment's local invocation for this repository, for example `go run ./cmd/godot-bridge ...` from the `cli/` directory.
- Do not assume the current working directory is already correct. Use an explicit working directory or full command path when needed.
- Use `--json` when structured output is needed for follow-up reasoning.
- Treat non-zero exits as command failures and read stderr for error details.

## Recommended CLI workflow

1. Run `godot-bridge status` to confirm the bridge is reachable.
2. Run `godot-bridge editor state --json` to inspect the current scene and selection.
3. If you need command discovery, run `godot-bridge spec`.
4. For scene structure, use `godot-bridge node tree [PATH] --json` or `godot-bridge node get PATH --detail full --json`.
5. For edits, prefer small explicit operations such as `node add`, `node modify`, `node move`, `node delete`, then `scene save`.
6. Use `godot-bridge screenshot --json` when you need to inspect the current 2D editor viewport visually.
7. For live runtime output, `godot-bridge debug watch --json` can stay connected while other CLI commands run in parallel.

## Editor Safety

- Keep one editor instance per target project unless you intentionally need more.
- Do not replace plugin files inside a live project while the editor is running. Close the editor, update files, then relaunch.
- Prefer `status`, `editor state`, `node tree`, and `node get` for bridge validation before reaching for `scene run`.
- Use `scene run` sparingly in manual validation because it spawns a game child process. Prefer a short self-terminating test scene if you need runtime output.
- If a run was interrupted or the editor crashed, check for leftover `Godot` child processes before relaunching more test sessions.
- For more detailed live-editor workflow guidance, see `docs/godot-agent-workflow.md` in this repository.

## Common commands

- `godot-bridge status`
- `godot-bridge spec`
- `godot-bridge editor state --json`
- `godot-bridge node tree /root/Main --json`
- `godot-bridge node get /root/Main/Player --detail full --json`
- `godot-bridge node add Sprite2D --parent /root/Main --name Hero --props '{"position":[200,150]}'`
- `godot-bridge node modify /root/Main/Hero --props '{"position":[240,180]}'`
- `godot-bridge signal connect --source /root/Main/Button --signal pressed --target /root/Main/Game --method on_button_pressed`
- `godot-bridge project get --prefix input/ --json`
- `godot-bridge animation list /root/Main/AnimationPlayer --json`
- `godot-bridge scene save`
- `godot-bridge debug watch --events output,error`
- `godot-bridge screenshot --json`
- `godot-bridge resource list res:// --json`

## Notes

- `resource list` uses Godot's resource filesystem view, so paths should be `res://...`.
- `scene run` without a path runs the main scene. With a path, it opens and runs that scene.
- `screenshot` returns metadata in text mode and image payload data in JSON mode.
- `debug watch` uses its own websocket connection and can run alongside other CLI commands.
