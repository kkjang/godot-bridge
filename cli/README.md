# godot-bridge CLI

> **Status: not yet implemented.** This directory will contain the Go CLI.

The `godot-bridge` CLI is the primary interface for controlling the Godot editor from an AI agent or terminal. It connects to the WebSocket bridge plugin running inside Godot and exposes all editor commands as shell subcommands.

## Planned commands

```
godot-bridge status                         Check if editor is connected
godot-bridge editor state                   Open scenes, selected nodes, active screen

godot-bridge node tree [PATH]               Print scene tree
godot-bridge node get PATH                  Get node details
godot-bridge node add TYPE --parent PATH    Add a node
godot-bridge node modify PATH --props '{}'  Set properties
godot-bridge node delete PATH               Remove a node
godot-bridge node move PATH --new-parent P  Reparent a node

godot-bridge scene new PATH                 Create and open a new scene
godot-bridge scene open PATH                Open a scene file
godot-bridge scene save                     Save the current scene
godot-bridge scene run [PATH]               Play the project or a specific scene
godot-bridge scene stop                     Stop the running scene

godot-bridge script open PATH               Open a script in the editor
godot-bridge screenshot                     Capture viewport as PNG

godot-bridge file read PATH                 Read a project file
godot-bridge file write PATH --content STR  Write a project file
godot-bridge file list [DIR]                List project files
godot-bridge file search QUERY              Search file contents

godot-bridge reference                      Print this command reference as markdown
```

## Architecture

```
godot-bridge CLI (Go)  --WebSocket-->  godot-plugin (GDScript)  --EditorInterface-->  Godot editor
```

See `../godot-plugin/README.md` for the plugin protocol and command details.

## Development

```bash
# Once implemented:
go build -o bin/godot-bridge ./cmd/godot-bridge/
```
