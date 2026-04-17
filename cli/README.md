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

## Test

```bash
go test ./...
```

Build the CLI after tests when you need a local binary:

```bash
go build -o /tmp/godot-bridge ./cmd/godot-bridge
```

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
godot-bridge node instance SCENE_PATH [--parent PATH] [--name NAME]

godot-bridge scene new PATH
godot-bridge scene open PATH
godot-bridge scene save
godot-bridge scene run [PATH]
godot-bridge scene stop
godot-bridge game screenshot [--out FILE]

godot-bridge script open PATH
godot-bridge signal connect --source PATH --signal NAME --target PATH --method NAME
godot-bridge signal disconnect --source PATH --signal NAME --target PATH --method NAME
godot-bridge signal list PATH

godot-bridge project get [--keys KEY,...] [--prefix PREFIX]
godot-bridge project set --settings JSON

godot-bridge animation list PATH
godot-bridge animation get PATH --animation NAME
godot-bridge animation new PATH --data JSON
godot-bridge animation modify PATH --animation NAME --data JSON
godot-bridge sprite-frames new PATH --data JSON
godot-bridge sprite-frames get PATH
godot-bridge sprite-frames modify PATH --data JSON [--mode merge|replace]
godot-bridge sprite-frames from-manifest --sheet res://sheet.png --manifest PATH --out res://frames.tres [--node PATH] [--default-fps N]

godot-bridge debug watch [--events output,error] [--json]
godot-bridge screenshot [--out FILE]

godot-bridge resource list [DIR]
godot-bridge resource reimport [PATH]
```

See `../godot-plugin/README.md` for the plugin API surface the CLI will talk to.

## Agent Skill

A copyable agent skill lives at `../skills/godot-bridge/SKILL.md`.

- It is written to be generic across agent harnesses that can execute shell commands.
- It tells agents to use `godot-bridge spec` for capability discovery.
- It includes the broader Godot Bridge workflow and scopes the CLI to plugin-backed editor control only.
- It includes a recommended workflow and example commands.

## Command Spec Source

The built-in `godot-bridge spec` command is the machine-readable source of truth for this CLI surface.

- Use `godot-bridge spec` for JSON capability discovery.
- Use `godot-bridge spec --markdown` to regenerate the command table below.
- When the CLI command surface changes, update the built-in spec first and then refresh this README table from it.
- Keep `../skills/godot-bridge/SKILL.md` aligned with the built-in spec and current command behavior.

## Transport flags

| Flag | Default | Description |
|---|---|---|
| `--host` | `127.0.0.1` | Godot bridge host. |
| `--port` | `6505` | Godot bridge port. |
| `--timeout` | `5s` | Maximum time to connect and wait for a response. |
| `--json` | `false` | Print structured JSON instead of compact text. |

The bridge supports multiple websocket clients, so `debug watch` can stay connected while other CLI commands run concurrently.

## Command spec

| CLI command | Plugin command | Required args | Optional args | Defaults | Description |
|---|---|---|---|---|---|
| `godot-bridge version` | - | none | none | none | Prints the CLI version. Release builds replace the default dev value. |
| `godot-bridge status` | `editor_state` | none | `--json` | `text output` | Checks that the bridge plugin is reachable and responsive. |
| `godot-bridge spec [--markdown]` | - | none | `--markdown` | `json output` | Prints the machine-readable CLI spec. Use --markdown to render the README command table from the same source. |
| `godot-bridge editor state` | `editor_state` | none | `--json` | `text output` | Shows current scene, open scenes, selected nodes, and active editor screen. |
| `godot-bridge node tree [PATH] [--depth N]` | `node_tree` | none | `PATH`, `--depth INT`, `--json` | `PATH=""`, `depth=4` | Prints the node tree rooted at the given path, or the current scene root when omitted. |
| `godot-bridge node get PATH [--detail brief\|full]` | `node_get` | `PATH` | `--detail brief\|full`, `--json` | `detail=brief` | Shows node information. Full detail includes editor-visible properties, signals, groups, and children. |
| `godot-bridge node add TYPE [--parent PATH] [--name NAME] [--props JSON]` | `node_add` | `TYPE` | `--parent PATH`, `--name NAME`, `--props JSON`, `--json` | `parent=""`, `name=TYPE`, `props={}` | Adds a node under the target parent or the scene root when no parent is provided. |
| `godot-bridge node modify PATH --props JSON` | `node_modify` | `PATH`, `--props JSON` | `--json` | none | Updates properties on an existing node using JSON-encoded values. |
| `godot-bridge node delete PATH` | `node_delete` | `PATH` | `--json` | none | Deletes the specified node. |
| `godot-bridge node move PATH --new-parent PATH` | `node_move` | `PATH`, `--new-parent PATH` | `--json` | none | Reparents a node under a new parent. |
| `godot-bridge node instance SCENE_PATH [--parent PATH] [--name NAME]` | `node_instance` | `SCENE_PATH` | `--parent PATH`, `--name NAME`, `--json` | `parent=""`, `name=scene root name` | Instances a PackedScene under the target parent or the current scene root. |
| `godot-bridge scene new PATH [--root-type TYPE] [--root-name NAME]` | `scene_new` | `PATH` | `--root-type TYPE`, `--root-name NAME`, `--json` | `root-type=Node2D` | Creates a new scene file and opens it in the editor. |
| `godot-bridge scene open PATH` | `scene_open` | `PATH` | `--json` | none | Opens an existing scene in the editor. |
| `godot-bridge scene save` | `scene_save` | none | `--json` | none | Saves the currently open scene. |
| `godot-bridge scene run [PATH]` | `scene_run` | none | `PATH`, `--json` | `PATH=""` | Runs the main scene, or opens and runs the specified scene. |
| `godot-bridge scene stop` | `scene_stop` | none | `--json` | none | Stops the running scene. |
| `godot-bridge game screenshot [--out FILE]` | `game_screenshot` | none | `--out FILE`, `--json` | `text output` | Captures the currently running game window through the debugger bridge. |
| `godot-bridge script open PATH` | `script_open` | `PATH` | `--json` | none | Opens a script in the Godot script editor. |
| `godot-bridge signal connect --source PATH --signal NAME --target PATH --method NAME` | `signal_connect` | `--source PATH`, `--signal NAME`, `--target PATH`, `--method NAME` | `--json` | none | Connects a signal from one node to a method on another node. |
| `godot-bridge signal disconnect --source PATH --signal NAME --target PATH --method NAME` | `signal_disconnect` | `--source PATH`, `--signal NAME`, `--target PATH`, `--method NAME` | `--json` | none | Removes an existing signal connection. |
| `godot-bridge signal list PATH` | `signal_connections` | `PATH` | `--json` | none | Lists outgoing signal connections from a node. |
| `godot-bridge project get [--keys KEY,...] [--prefix PREFIX]` | `project_get` | none | `--keys KEY,...`, `--prefix PREFIX`, `--json` | none | Reads project settings by explicit keys, prefix, or both. |
| `godot-bridge project set --settings JSON` | `project_set` | `--settings JSON` | `--json` | none | Updates project settings and saves the project configuration. |
| `godot-bridge animation list PATH` | `animation_list` | `PATH` | `--json` | none | Lists animations on an AnimationPlayer. |
| `godot-bridge animation get PATH --animation NAME` | `animation_get` | `PATH`, `--animation NAME` | `--json` | none | Shows track and keyframe data for one animation. |
| `godot-bridge animation new PATH --data JSON` | `animation_new` | `PATH`, `--data JSON` | `--json` | none | Creates a new animation from JSON data on an AnimationPlayer. |
| `godot-bridge animation modify PATH --animation NAME --data JSON` | `animation_modify` | `PATH`, `--animation NAME`, `--data JSON` | `--json` | none | Updates an existing animation using JSON track data. |
| `godot-bridge sprite-frames new PATH --data JSON` | `sprite_frames_new` | `PATH`, `--data JSON` | `--json` | none | Creates a SpriteFrames resource from JSON animation data. |
| `godot-bridge sprite-frames get PATH` | `sprite_frames_get` | `PATH` | `--json` | none | Reads a SpriteFrames resource back as JSON animation data. |
| `godot-bridge sprite-frames modify PATH --data JSON [--mode merge\|replace]` | `sprite_frames_modify` | `PATH`, `--data JSON` | `--mode merge\|replace`, `--json` | `mode=merge` | Updates a SpriteFrames resource by replacing named animations or fully replacing the resource. |
| `godot-bridge sprite-frames from-manifest --sheet res://sheet.png --manifest PATH --out res://frames.tres [--node PATH] [--default-fps N]` | `sprite_frames_from_manifest` | `--sheet res://sheet.png`, `--manifest PATH`, `--out res://frames.tres` | `--node PATH`, `--default-fps FLOAT`, `--json` | `default-fps=10` | Builds a SpriteFrames resource from a sprite-gen sheet manifest and optionally assigns it to a node. |
| `godot-bridge debug watch [--events output,error] [--json]` | `debug_subscribe` | none | `--events output,error`, `--json` | `events=all` | Subscribes to streamed debug events and prints them until interrupted. |
| `godot-bridge screenshot [--out FILE]` | `screenshot` | none | `--out FILE`, `--json` | `text output` | Captures the current 2D editor viewport. |
| `godot-bridge resource list [DIR]` | `resource_list` | none | `DIR`, `--json` | `DIR=res://` | Lists files and subdirectories from Godot's resource filesystem view. |
| `godot-bridge resource reimport [PATH]` | `resource_reimport` | none | `PATH`, `--json` | `PATH=full scan` | Triggers Godot to rescan one resource path or the full resource filesystem when omitted. |
