# Plan 2: Asset Pipeline Integration

## Context

An AI agent building games needs to generate art (2D sprites, 3D models, animations) and get those assets into the Godot project. Godot is **not an art tool** — it imports art, it doesn't create it. The bridge's role is to handle the "get it into the scene" part after external tools generate the assets.

This plan covers:
1. The bridge commands needed to support the pipeline (reimport, resource coercion, instancing)
2. The orchestration architecture — what the agent does externally vs. through the bridge
3. 2D and 3D workflow specifics

---

## What the Bridge Needs

### 1. Resource Reimport Command

**Plugin command: `resource_reimport`**
- Args: `{ "path": "res://art/hero.png" }` (optional — omit for full scan)
- Response: `{ "scanned": "res://art/hero.png" }` or `{ "scanned": "full" }`
- Godot API:
  - Single file: `EditorInterface.get_resource_filesystem().update_file(path)` (synchronous)
  - Full scan: `EditorInterface.get_resource_filesystem().scan()` (async, fire-and-forget for v1)

**CLI command:** `godot-bridge resource reimport [PATH]`

**Why it's needed:** When the agent writes a PNG or .glb to disk, Godot doesn't pick it up until the editor regains focus or a manual reimport happens. This command closes that gap.

**Files:** Add `_cmd_resource_reimport` in `bridge_server.gd`, add subcommand in `runResource()` in `main.go`.

### 2. Resource Path Coercion in node_modify

**Current gap:** `node_modify` can set scalar properties (Vector2, Color, etc.) but can't assign resources. Setting `texture` on a Sprite2D with `"res://hero.png"` fails because the property expects a `Texture2D` object, not a string.

**Fix:** In `_json_to_variant` (or `_coerce_prop`), add a case for `TYPE_OBJECT`:
```gdscript
TYPE_OBJECT:
    if v is String and (v as String).begins_with("res://"):
        return load(v)
```

Check the property's `class_name` from PropertyInfo to confirm it's a Resource subclass before applying.

**This single change enables the entire 2D art pipeline through existing `node_modify`.**

**Files:** Modify `_json_to_variant` or `_coerce_prop` in `bridge_server.gd` (~10 lines).

### 3. Scene Instancing (shared with Plan 1)

**Plugin command: `node_instance`** — instantiate a PackedScene (.tscn/.glb) as a child node. Covered in Plan 1. Required here for the 3D art pipeline (instancing imported .glb scenes).

---

## 2D Art Pipeline

### Workflow
```
Agent                          Filesystem              Bridge
  |                               |                      |
  |-- call image gen API -------->|                      |
  |<-- receive PNG bytes ---------|                      |
  |-- write PNG to res://art/ --->|                      |
  |                               |                      |
  |-- resource reimport --------->|--------------------->|
  |<-- confirmed -----------------|<---------------------|
  |                               |                      |
  |-- node modify Sprite2D ----->|--------------------->|
  |   (set texture to res://...) |                      |
  |<-- modified ------------------|<---------------------|
```

### Concrete steps
1. Agent calls an image generation API (DALL-E, Stable Diffusion, Flux, etc.)
2. Agent writes the resulting PNG to the project's `res://` directory (plain file I/O)
3. `godot-bridge resource reimport res://art/hero.png` — Godot processes the file and creates the `.import` sidecar
4. `godot-bridge node modify /root/Main/Player/Sprite2D --props '{"texture": "res://art/hero.png"}'` — assigns the texture (requires resource path coercion)

### Spritesheets / 2D frame animation
1. Agent generates a spritesheet PNG externally
2. Agent writes it to `res://art/` and triggers reimport
3. Agent creates an `AnimatedSprite2D` node via `node_add`
4. Agent configures frames — two options:
   - **Option A:** Write a `.tres` (SpriteFrames resource) file directly to disk in Godot's text resource format, reimport, assign via `node_modify`
   - **Option B:** Use `animation_new` commands from Plan 1 to configure frames programmatically
   - Option A is simpler for v1 since `.tres` is a well-known text format

### Import settings
- Godot's `.import` sidecar files (plain INI format) control how assets are processed: texture filtering, compression, mipmaps, etc.
- The agent can write/edit `.import` files directly on disk before triggering reimport
- No bridge command needed — it's a filesystem operation
- Example: setting `filter=false` for pixel art sprites

---

## 3D Art Pipeline

### Workflow
```
Agent                          Filesystem              Bridge
  |                               |                      |
  |-- call 3D gen API ---------->|                      |
  |   (Meshy, Tripo, Rodin,     |                      |
  |    or Blender Python)        |                      |
  |<-- receive .glb -------------|                      |
  |-- write .glb to res://... -->|                      |
  |                               |                      |
  |-- resource reimport --------->|--------------------->|
  |<-- confirmed -----------------|<---------------------|
  |                               |                      |
  |-- node instance ------------->|--------------------->|
  |   (instance imported scene)  |                      |
  |<-- instanced ------------------|<--------------------|
```

### Concrete steps
1. Agent calls a 3D generation API or runs Blender Python scripts
2. Agent writes the `.glb`/`.gltf` to the project's `res://models/` directory
3. `godot-bridge resource reimport res://models/enemy.glb` — Godot imports the model and generates an internal scene
4. `godot-bridge node instance res://models/enemy.glb --parent /root/Main/World --name Enemy1` — instances the imported scene

### 3D import settings
- The agent can write `.import` files to configure: animation handling (import/don't import), mesh compression, material mode (keep/convert), bone naming convention
- This is filesystem-only — no bridge command needed
- For complex import pipelines, consider a future `resource_import_settings` command

### Blender as a secondary path
- Blender is fully scriptable via Python
- The agent can write a `.py` Blender script, execute it via `blender --background --python script.py`, and export `.glb`
- This enables procedural mesh generation, UV unwrapping, rigging, and skeletal animation
- The bridge is not involved in the Blender step — only in the import step after

---

## What Lives Where

| Responsibility | Where | Bridge involvement |
|---|---|---|
| Calling image/3D generation APIs | Agent (external) | None |
| Writing asset files to `res://` | Agent (filesystem) | None |
| Writing/editing `.import` files | Agent (filesystem) | None |
| Triggering Godot reimport | Bridge | `resource_reimport` |
| Assigning textures to nodes | Bridge | `node_modify` (with resource coercion) |
| Instancing imported 3D scenes | Bridge | `node_instance` |
| Writing `.tres` resource files | Agent (filesystem) | None |
| Writing `.gdshader` files | Agent (filesystem) | None |
| Material property tweaks | Bridge | `node_modify` on material properties |
| Spritesheet frame config | Bridge or Agent | `animation_*` commands or `.tres` on disk |

### Key principle
The bridge doesn't call external APIs or generate art. It handles **import triggering** and **scene integration**. The agent orchestrates everything else.

---

## Capability Matrix: What Can an Agent Do?

| Capability | Agent + Bridge alone? | Needs external tooling? |
|---|---|---|
| 2D sprites/textures | No | Image gen API + file write |
| 2D spritesheets | Partially (can configure frames) | Needs spritesheet image |
| 3D models | No | 3D gen API or Blender |
| 3D skeletal animation | No | Blender/Mixamo/AI motion |
| Keyframe property animation | Yes (with Plan 1 animation commands) | No |
| Animation state machines | Yes (with Plan 1) | No |
| Particle effects | Yes (node properties) | No |
| Shaders | Yes (write .gdshader to disk) | No |
| UI/theme | Partially (structural, not visual) | Custom art for visual polish |
| Tilemaps | Yes (node properties + tile data) | Tileset art from external |
| Materials | Yes (write .tres or use node_modify) | Texture art from external |

---

## Implementation Summary

Only 3 changes are needed in the bridge to support the full art pipeline:

1. **`resource_reimport` command** — ~15 lines in `bridge_server.gd`, ~30 lines in `main.go`
2. **Resource path coercion** — ~10 lines in `bridge_server.gd` (`_json_to_variant` or `_coerce_prop`)
3. **`node_instance` command** — ~30 lines in `bridge_server.gd`, ~40 lines in `main.go` (shared with Plan 1)

Everything else is agent-side orchestration between external APIs and the bridge.

---

## Files to Modify

| File | Changes |
|------|---------|
| `godot-plugin/addons/godot_bridge/bridge_server.gd` | `_cmd_resource_reimport`, resource path coercion in `_coerce_prop`, `_cmd_node_instance` |
| `cli/cmd/godot-bridge/main.go` | `resource reimport` subcommand + spec entry, `node instance` subcommand + spec entry |

---

## Verification

1. Build CLI: `cd cli && go build ./cmd/godot-bridge`
2. **Reimport test:** Drop a PNG into the project's `res://` directory via filesystem, run `godot-bridge resource reimport res://test.png`, verify the `.import` file appears
3. **Resource coercion test:** Create a Sprite2D node, run `godot-bridge node modify <path> --props '{"texture": "res://icon.svg"}'` (Godot's default icon), verify the texture appears
4. **3D instance test:** Place a `.glb` file in `res://`, reimport, run `godot-bridge node instance res://model.glb`, verify the 3D scene appears in the node tree
5. Run `godot-bridge spec --markdown` — verify new commands appear
