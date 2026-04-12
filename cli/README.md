# godot-bridge CLI

> **Status: not yet implemented.** This directory will contain the Go CLI.

The `godot-bridge` CLI is intended to be the human- and agent-friendly shell interface for controlling the Godot editor through the bridge plugin.

For implementation guidance while building the CLI, see `AGENTS.md`.

## Planned user-facing commands

```text
godot-bridge status
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

godot-bridge file read PATH
godot-bridge file write PATH --content STR
godot-bridge file list [DIR]
godot-bridge file search QUERY

godot-bridge reference
```

See `../godot-plugin/README.md` for the plugin API surface the CLI will talk to.
