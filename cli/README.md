# godot-bridge CLI

The `godot-bridge` CLI is the human- and agent-friendly shell interface for controlling the Godot editor through the bridge plugin.

For implementation guidance while building the CLI, see `AGENTS.md`.

## Install

Install the CLI onto `PATH` from any repository:

```bash
go install github.com/kkjang/godot-bridge/cli/cmd/godot-bridge@latest
godot-bridge version
```

For a pinned release, replace `@latest` with `@vX.Y.Z` after CLI release tags exist.

## User-facing commands

```text
godot-bridge version
godot-bridge status
godot-bridge spec [--markdown]
godot-bridge editor state

godot-bridge node tree [PATH]
godot-bridge node get PATH
godot-bridge node add TYPE --parent PATH
godot-bridge node modify PATH --props '{}'
godot-bridge node delete PATH
godot-bridge node move PATH --new-parent PATH

godot-bridge scene new PATH
godot-bridge scene open PATH
godot-bridge scene save
godot-bridge scene run [PATH]
godot-bridge scene stop

godot-bridge script open PATH
godot-bridge screenshot

godot-bridge resource list [DIR]
```

See `../godot-plugin/README.md` for the plugin API surface the CLI will talk to.

## Agent Skill

A copyable agent skill lives at `skills/godot-bridge.md`.

- It is written to be generic across agent harnesses that can execute shell commands.
- It tells agents to use `godot-bridge spec` for capability discovery.
- It scopes the CLI to plugin-backed editor control only.
- It includes a recommended workflow and example commands.

## Command Spec Source

The built-in `godot-bridge spec` command is the machine-readable source of truth for this CLI surface.

- Use `godot-bridge spec` for JSON capability discovery.
- Use `godot-bridge spec --markdown` to regenerate the command table below.
- When the CLI command surface changes, update the built-in spec first and then refresh this README table from it.
- Keep `skills/godot-bridge.md` aligned with the built-in spec and current command behavior.
- Keep `skills/godot-bridge.md` harness-neutral. Put tool-specific wiring in separate adapter docs rather than the generic skill.

## Transport flags

| Flag | Default | Description |
|---|---|---|
| `--host` | `127.0.0.1` | Godot bridge host. |
| `--port` | `6505` | Godot bridge port. |
| `--timeout` | `5s` | Maximum time to connect and wait for a response. |
| `--json` | `false` | Print structured JSON instead of compact text. |

## Command spec

| CLI command | Plugin command | Required args | Optional args | Defaults | Description |
|---|---|---|---|---|---|
| `godot-bridge version` | - | none | none | `text output` | Prints the CLI version. Release builds replace the default dev value. |
| `godot-bridge status` | `editor_state` | none | `--json` | `text output` | Checks that the bridge plugin is reachable and responsive. |
| `godot-bridge spec [--markdown]` | - | none | `--markdown` | `json output` | Prints the machine-readable CLI spec. Use --markdown to render the README command table from the same source. |
| `godot-bridge editor state` | `editor_state` | none | `--json` | `text output` | Shows current scene, open scenes, selected nodes, and active editor screen. |
| `godot-bridge node tree [PATH] [--depth N]` | `node_tree` | none | `PATH`, `--depth INT`, `--json` | `PATH=""`, `depth=4` | Prints the node tree rooted at the given path, or the current scene root when omitted. |
| `godot-bridge node get PATH [--detail brief\|full]` | `node_get` | `PATH` | `--detail brief\|full`, `--json` | `detail=brief` | Shows node information. Full detail includes editor-visible properties, signals, groups, and children. |
| `godot-bridge node add TYPE [--parent PATH] [--name NAME] [--props JSON]` | `node_add` | `TYPE` | `--parent PATH`, `--name NAME`, `--props JSON`, `--json` | `parent=""`, `name=TYPE`, `props={}` | Adds a node under the target parent or the scene root when no parent is provided. |
| `godot-bridge node modify PATH --props JSON` | `node_modify` | `PATH`, `--props JSON` | `--json` | none | Updates properties on an existing node using JSON-encoded values. |
| `godot-bridge node delete PATH` | `node_delete` | `PATH` | `--json` | none | Deletes the specified node. |
| `godot-bridge node move PATH --new-parent PATH` | `node_move` | `PATH`, `--new-parent PATH` | `--json` | none | Reparents a node under a new parent. |
| `godot-bridge scene new PATH [--root-type TYPE] [--root-name NAME]` | `scene_new` | `PATH` | `--root-type TYPE`, `--root-name NAME`, `--json` | `root-type=Node2D` | Creates a new scene file and opens it in the editor. |
| `godot-bridge scene open PATH` | `scene_open` | `PATH` | `--json` | none | Opens an existing scene in the editor. |
| `godot-bridge scene save` | `scene_save` | none | `--json` | none | Saves the currently open scene. |
| `godot-bridge scene run [PATH]` | `scene_run` | none | `PATH`, `--json` | `PATH=""` | Runs the main scene, or opens and runs the specified scene. |
| `godot-bridge scene stop` | `scene_stop` | none | `--json` | none | Stops the running scene. |
| `godot-bridge script open PATH` | `script_open` | `PATH` | `--json` | none | Opens a script in the Godot script editor. |
| `godot-bridge screenshot` | `screenshot` | none | `--json` | `text output` | Captures the current 2D editor viewport. |
| `godot-bridge resource list [DIR]` | `resource_list` | none | `DIR`, `--json` | `DIR=res://` | Lists files and subdirectories from Godot's resource filesystem view. |
