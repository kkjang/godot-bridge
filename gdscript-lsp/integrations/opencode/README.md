# OpenCode GDScript LSP Integration

Copy or merge `opencode.json` into the root OpenCode config for your game project.

This integration assumes:

- `gdscript-lsp-proxy` is installed and available on `PATH`
- Godot is running with the target game project open
- Godot's GDScript language server is listening on `localhost:6005`

If your Godot LSP port is different, change `GODOT_LSP_PORT` in the config.
