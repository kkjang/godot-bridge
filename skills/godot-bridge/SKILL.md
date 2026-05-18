---
name: godot-bridge
description: Use the Godot Bridge tool suite for Godot editor control and GDScript-aware workflows
---

## What I do

- Guide work across three layers: OpenCode's built-in LSP for `.gd` code intelligence, the `godot-bridge` CLI for live editor control, and heavier Godot validation only when needed.
- Treat `gdscript-lsp-proxy` as transport that OpenCode may launch from the configured `opencode.json`, not as a process to launch manually from `bash` during normal work.
- Prefer the lightest reliable feedback loop for the task.
- Keep harness-specific wiring separate from this workflow guidance.

## When to use me

Use this skill when working in a Godot project that may use the Godot Bridge tool suite.

## Workflow

1. Use OpenCode's built-in LSP first for `.gd` diagnostics, symbol lookup, definitions, and references.
2. Let OpenCode launch the configured `gdscript-lsp-proxy` for `.gd` files, and use the regular built-in LSP interface instead of manually launching the proxy from `bash` or creating ad-hoc JSON-RPC/TCP LSP clients, unless the user is explicitly debugging LSP setup.
3. If usable LSP operations are unavailable in the current session, state that explicitly and fall back to file inspection plus Godot validation as needed.
4. Use filesystem tools directly for ordinary project file edits.
5. Use the `godot-bridge` CLI for live editor operations such as scene open/save/run/stop, node inspection and mutation, signal wiring, scene instancing, project settings, animation authoring including `SpriteFrames`, script opening, editor and running-game screenshots, resource listing, resource reimport, debug streaming, and editor state inspection.
6. Treat `godot-bridge spec` as the source of truth for CLI commands, flags, defaults, and plugin mappings.
7. If LSP, direct inspection, and live editor inspection are not enough, escalate to heavier checks like running Godot in headless mode as smoke tests when appropriate.

## Components

- OpenCode built-in LSP integration: primary surface for `.gd` code intelligence during normal agent work.
- `gdscript-lsp-proxy`: transport configured behind OpenCode's LSP integration to bridge stdio-based LSP clients to Godot's TCP-based GDScript language server.
- `godot-bridge`: CLI for plugin-backed editor control.
- Godot Bridge plugin: runs in the editor and exposes the command surface used by the CLI.

## Environment assumptions

- Godot should be running with the target project open when using the live editor bridge or the GDScript LSP.
- The Godot Bridge plugin defaults to `127.0.0.1:6505` unless configured otherwise.
- The Godot GDScript LSP defaults to `localhost:6005` unless configured otherwise.
- The repository containing the bridge code may be different from the game project currently open in Godot.

## OpenCode LSP

- In downstream repos, `opencode.json` may already configure the GDScript LSP via `gdscript-lsp-proxy`.
- In normal work, if `opencode.json` configures `gdscript-lsp-proxy`, let OpenCode launch it and then use OpenCode's built-in LSP operations for `.gd` files rather than launching `gdscript-lsp-proxy` from `bash` yourself.
- Only edit `opencode.json`, manually test proxy startup, or debug low-level LSP transport when the user explicitly asks for LSP setup or troubleshooting.
- If the project needs setup, update the project-root `opencode.json` so `lsp` is an object and includes a custom `gdscript` server entry for `gdscript-lsp-proxy`.
- Merge this into any existing `lsp` object instead of replacing unrelated servers.
- If `lsp` is currently `true`, convert it to an object so built-in servers stay enabled while adding the custom GDScript server.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
    "gdscript": {
      "command": [
        "gdscript-lsp-proxy"
      ],
      "extensions": [
        ".gd"
      ],
      "env": {
        "GODOT_LSP_PORT": "6005"
      }
    }
  }
}
```

- If the Godot language server uses a different port, change `GODOT_LSP_PORT` to match.

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
6. Use `godot-bridge screenshot --json` for the editor viewport and `godot-bridge game screenshot --json` for the running game window.
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
- `godot-bridge sprite-frames new res://art/player.tres --data '{"animations":[{"name":"idle","speed":6,"loop":true,"frames":[{"texture":"res://art/player_sheet.png","region":{"x":0,"y":0,"w":16,"h":16}}]}]}'`
- `godot-bridge sprite-frames from-manifest --sheet res://art/player_sheet.png --manifest res://art/player_sheet.json --out res://art/player_frames.tres --node /root/Main/Player`
- `godot-bridge node modify /root/Main/Player --props '{"sprite_frames":"res://art/player.tres","animation":"idle","autoplay":"idle"}'`
- `godot-bridge scene save`
- `godot-bridge debug watch --events output,error`
- `godot-bridge screenshot --json`
- `godot-bridge game screenshot --json`
- `godot-bridge resource list res:// --json`
- `godot-bridge resource reimport res://art/hero.png`

## Notes

- `resource list` uses Godot's resource filesystem view, so paths should be `res://...`.
- `resource reimport` is useful after writing assets directly to disk so the editor notices them immediately.
- `scene run` without a path runs the main scene. With a path, it opens and runs that scene.
- `screenshot` and `game screenshot` return metadata in text mode and image payload data in JSON mode.
- `debug watch` uses its own websocket connection and can run alongside other CLI commands.
