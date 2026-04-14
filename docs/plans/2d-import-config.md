# Plan: Import Config Helper (`import_config_*`)

Part of the 2D game enablement series — see `docs/plans/2d-game-overview.md`.

## Context

For a game with simple generated artwork, the single most common friction is pixel-art
filtering. Godot defaults to linear filtering, which makes pixel art look blurry. The fix
is `filter=false` in the PNG's `.import` sidecar file, but editing INI files by hand is
fiddly — the section shape is specific, and forgetting to trigger a reimport afterwards
produces silent non-effects.

`docs/plans/asset-pipeline-integration.md` calls out this gap and points at "agent writes
the `.import` file directly" as the workaround. That works, but it's the sort of small,
error-prone step that deserves a tiny helper now that art pipelines are being exercised
for real.

## Design

Two commands, one CLI subcommand group, plus an optional preset shortcut.

- `import_config_get` — args: `{path}` where `path` is the source asset (e.g.
  `res://art/hero.png`). Returns the parsed `.import` file as a JSON dict of sections:
  ```json
  {
    "remap":   {"importer": "texture", "type": "CompressedTexture2D"},
    "deps":    {...},
    "params":  {"compress/mode": 0, "process/fix_alpha_border": true, "process/normal_map": 0, "flags/filter": true, ...}
  }
  ```
- `import_config_set` — args: `{path, config, preset?}`.
  - Applies via `ConfigFile.load` → `set_value(section, key, value)` → `save`. Only
    specified keys are written; omitted keys are left untouched.
  - If `preset` is supplied (e.g. `"pixel_art"`), the command merges the preset defaults
    first, then applies the explicit `config` overrides on top.
  - Triggers `EditorInterface.get_resource_filesystem().update_file(path)` at the end so
    the change takes effect immediately — same pattern as `_cmd_resource_reimport` in
    `bridge_server.gd:1189`.

### Presets

Single built-in preset for now:

- `pixel_art` →
  - `params/flags/filter = false`
  - `params/flags/mipmaps = false`
  - `params/process/fix_alpha_border = true`

Additional presets can be added later (e.g. `normal_map`, `ui_texture`) by listing keys in
the same helper.

## Critical files

| File | Change |
|------|--------|
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | Two handlers (~40 lines total) + preset map + dispatch entries. |
| `cli/cmd/godot-bridge/commands_extra.go` | New `runImportConfig` subcommand group and spec entries. |
| `cli/cmd/godot-bridge/main.go` | Register the subcommand group. |
| `skills/godot-bridge/SKILL.md` | Example: `import config set res://art/hero.png --preset pixel_art`. |

## Patterns to reuse

- `ConfigFile` is the standard Godot API for INI files; no dependency additions.
- `EditorInterface.get_resource_filesystem().update_file(path)` for synchronous reimport,
  mirroring `_cmd_resource_reimport` (`bridge_server.gd:1189`).
- `_send_ok` / `_send_error` dispatch shape.
- `reorderFlags` + `flag.NewFlagSet` pattern from `commands_extra.go:44`.

## Verification

1. Drop an 8×8 pixel-art PNG at `res://art/hero.png`; `godot-bridge resource reimport
   res://art/hero.png`.
2. `godot-bridge import config get res://art/hero.png` — shows `params.flags/filter = true`
   (default).
3. `godot-bridge import config set res://art/hero.png --preset pixel_art`.
4. `godot-bridge import config get res://art/hero.png` — now shows `filter = false`,
   `mipmaps = false`, `fix_alpha_border = true`.
5. Attach the texture to a `Sprite2D`, `scene run`, `godot-bridge game screenshot` (from
   `docs/plans/2d-game-screenshot.md`) — crisp pixel edges on screen, not blurred.
6. `godot-bridge import config set res://art/hero.png --data '{"params":{"flags/filter":true}}'`
   — explicit override, confirmed via `get`.
7. `cd cli && go test ./...` and `cd godot-plugin && bash scripts/test.sh`.
8. `godot-bridge spec --markdown` lists the new commands.
