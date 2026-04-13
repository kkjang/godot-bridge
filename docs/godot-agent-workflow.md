# Godot Agent Workflow

Guidance for agents and maintainers interacting with a live Godot editor through `godot-bridge`.

## Goals

- Keep the editor stable while using the bridge.
- Prefer lightweight validation before runtime-heavy checks.
- Avoid leaving behind orphaned Godot child processes during manual testing.

## Core Rules

1. Use one editor instance per target project unless multiple editors are explicitly required.
2. Do not replace plugin files inside a running Godot project. Close the editor, update `addons/godot_bridge/`, then relaunch.
3. Treat `scene run` as heavier than normal editor commands because it starts a game process.
4. Prefer `status`, `editor state`, `node tree`, `node get`, and `screenshot` before using `scene run`.
5. Use `debug watch` in parallel with normal CLI commands when runtime output is needed. Multi-client support allows this now.

## Recommended Live Workflow

1. Confirm the correct project is open in Godot.
2. Run `godot-bridge status`.
3. Run `godot-bridge editor state --json`.
4. Inspect the target scene with `godot-bridge node tree --json` or `godot-bridge node get PATH --detail full --json`.
5. Make focused edits with bridge commands or filesystem edits.
6. Save the scene.
7. Only then, if runtime behavior matters, run `godot-bridge debug watch --json` and a small number of runtime commands.

## Safer Runtime Validation

- Prefer a dedicated test scene that prints a few lines and exits on its own.
- Keep manual runtime repros short.
- Avoid repeatedly relaunching `scene run` without confirming the previous run stopped.
- If you only need bridge transport validation, skip `scene run` entirely.

## Process Hygiene

- After crashes or interrupted runs, check for leftover Godot processes.
- On macOS, `ps -ax | grep Godot` is usually enough to spot orphaned child processes.
- If the bridge does not respond, check whether anything is still listening on `127.0.0.1:6505`.
- If the editor crashed while child game processes are still alive, stop those children before relaunching the editor.

## Plugin Update Workflow

1. Close the editor for the target project.
2. Copy the updated `addons/godot_bridge/` files into the game project.
3. Relaunch the editor.
4. Wait for the bridge status panel to show `Bridge: Listening :6505` or `Bridge: Connected (N)`.
5. Resume CLI-driven validation.

## Manual Multi-Client Check

1. Start `godot-bridge debug watch --events output,error --json`.
2. In another shell, run `godot-bridge status`.
3. In that same second shell, run `godot-bridge node get PATH`.
4. If runtime output matters, run one short `godot-bridge scene run ...` repro.
5. Stop the scene cleanly.
6. Verify the watch client stayed connected throughout.

## When Things Look Wrong

- `status` times out:
  - Check that the editor is still open on the intended project.
  - Check the Godot output panel for plugin script errors.
  - Check whether another process owns the configured bridge port.
- You see several `Godot` processes:
  - Distinguish editor instances from spawned game children.
  - Look for child processes started by `scene run` with `--scene ... --embedded` in their command line.
- The editor says Godot quit unexpectedly:
  - Save any crash log.
  - Clean up orphaned child processes.
  - Avoid hot-swapping plugin files into a live session on the next attempt.

## Related Docs

- `README.md`
- `cli/README.md`
- `godot-plugin/README.md`
- `skills/godot-bridge/SKILL.md`
