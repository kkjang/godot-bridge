# Operating Modes

Use this document when working in a real Godot project through Godot Bridge.

## Default

- Default to **Automated mode** unless the user explicitly prefers to keep a live editor session in sync.
- If the user's preference is unclear, ask which mode they want before starting work that could affect editor state.

## Automated Mode

Automated mode is the default and first-class workflow.

- Goal: reliability, repeatability, and CI-friendly automation.
- Prefer direct filesystem edits plus headless Godot execution when possible.
- Use a headless editor process with the plugin only when editor-only APIs are required.
- Do not assume a human is watching changes live.

Pros:

- More deterministic than sharing a live editor session.
- Easier to retry from a clean state.
- Better for batch scene or resource transforms, imports, validation, and smoke tests.
- Better fit for CI and unattended agent workflows.

Cons:

- Weaker immediate visual feedback.
- Some editor-only affordances still need the plugin or a visible editor later.

## Interactive Mode

Interactive mode means the user wants the Godot editor open and reasonably usable while the agent works.

- Use the plugin-backed CLI for inspection, lightweight edits, and editor-aware operations.
- Plain headless scripts are still allowed, but they can desync the editor from disk.
- Prefer live-safe operations when an equivalent exists.

Pros:

- The user can watch progress in the editor.
- Useful for inspection, screenshots, current scene state, selection state, and lightweight scene poking.

Cons:

- Less reliable than automated mode.
- Editor state can drift from on-disk state.
- Plugin reloads, scene tabs, unsaved buffers, and restart requirements create friction.

## Important Distinction

The current CLI only knows how to talk to the plugin WebSocket. It does not know whether Godot is:

- a visible editor session, or
- a headless editor process running the plugin.

That difference matters for reliability and user experience, but not for the CLI transport itself.

## Usage Matrix

| Action | Automated Mode | Interactive Mode | Notes |
|---|---|---|---|
| Write new asset files to `res://` | Preferred | Allowed | Usually safe in both modes. If the editor already has related resources loaded, the visible state may lag behind disk. |
| Trigger resource import or reimport | Preferred | Allowed | Today this is implemented through the plugin-backed CLI. A plain headless script may also be possible, but treat that as an agent option rather than a guaranteed product surface. |
| Batch scene or resource transforms | Preferred | Warning-worthy | Best when the agent can treat disk as the source of truth. In Interactive mode, the editor may need reload or reopen to reflect changes. |
| Validate, smoke test, or run CI-style checks | Preferred | Allowed | Headless runs are usually more reliable and easier to repeat. |
| Inspect current editor state, open scenes, or selection | Not applicable | Preferred | Requires a live plugin session. |
| Capture editor viewport screenshots | Not applicable | Preferred | Useful only when the user wants live inspection. |
| Small scene edits the user wants to watch | Allowed | Preferred | Use Interactive mode when visibility matters more than strict determinism. |
| Modify `project.godot` | Allowed | Warning-worthy | The editor may prompt for reload or continue showing stale settings until reopened. |
| Modify imported resources already open in the editor | Allowed | Warning-worthy | Disk changes remain authoritative, but the editor may not immediately reflect them. |
| Modify plugin files under `addons/godot_bridge/` | Allowed | Restart-needed | Do not rely on the live plugin again until the editor restarts. |

## When Interactive Mode Deteriorates

Interactive mode does **not** disable headless work. The main risk is stale in-memory editor state after on-disk changes.

Usually safe with the editor open:

- generating new files or assets
- validation and smoke tests
- modifying files the editor has not loaded yet
- read-only inspection of project files

Warning-worthy with the editor open:

- changing the currently open scene
- changing scenes or resources already open in editor tabs
- changing `project.godot`
- changing imported resources the editor is actively using

Restart-needed or avoid while live:

- changing plugin files under `addons/godot_bridge/`
- relying on the live editor to immediately reflect large headless batch transforms without reopen/reload

## Agent Rules

1. If the user did not specify a mode, ask whether they want **Automated** or **Interactive** mode.
2. If the user is optimizing for reliability or CI, recommend **Automated** mode.
3. In Interactive mode, warn before doing work likely to desync the editor or require reopen/restart.
4. Do not assume the editor view is authoritative after headless mutations; disk is the source of truth.
5. If plugin files were changed, tell the user a restart is required before relying on the live plugin again.

## Practical Guidance For Agents

- Prefer Automated mode for import pipelines, batch transforms, validation, smoke tests, and large refactors.
- Prefer Interactive mode for editor inspection, screenshots, current selection/state, and small scene adjustments the user wants to watch.
- When the user wants both, keep the editor open but warn clearly when a step may degrade the live session.
