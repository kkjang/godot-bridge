## bridge_server.gd
## WebSocket server that listens on localhost:<port> and dispatches
## JSON commands from the CLI to EditorInterface / scene tree.
##
## Protocol
##   Request:  {"id": "<str>", "command": "<str>", "args": {}}
##   Response: {"id": "<str>", "ok": true,  "data": {}}
##   Error:    {"id": "<str>", "ok": false, "error": "<message>"}

@tool
extends Node

signal status_changed(status: String)

const HEARTBEAT_INTERVAL := 10.0
const RESPONSE_TIMEOUT   := 30.0

var _tcp_server  : TCPServer
var _peer        : WebSocketPeer
var _port        : int
var _heartbeat_t : float = 0.0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func start(port: int) -> void:
	_port = port
	_tcp_server = TCPServer.new()
	var err := _tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("GodotBridge: failed to listen on port %d (error %d)" % [port, err])
		emit_signal("status_changed", "Error (port %d)" % port)
		return
	emit_signal("status_changed", "Listening :%d" % port)


func stop() -> void:
	_disconnect_peer()
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null


# ---------------------------------------------------------------------------
# Per-frame polling
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _tcp_server:
		return

	# Accept new connection only when no peer is active.
	if _peer == null and _tcp_server.is_connection_available():
		var stream := _tcp_server.take_connection()
		_peer = WebSocketPeer.new()
		var err := _peer.accept_stream(stream)
		if err != OK:
			push_warning("GodotBridge: accept_stream error %d" % err)
			_peer = null
			return
		emit_signal("status_changed", "Connected")

	if _peer == null:
		return

	_peer.poll()
	var state := _peer.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		_heartbeat_t += delta
		if _heartbeat_t >= HEARTBEAT_INTERVAL:
			_heartbeat_t = 0.0
			_peer.send_text('{"type":"ping"}')

		while _peer.get_available_packet_count() > 0:
			var raw := _peer.get_packet()
			var text := raw.get_string_from_utf8()
			_handle_message(text)

	elif state == WebSocketPeer.STATE_CLOSING:
		pass  # wait for CLOSED

	elif state in [WebSocketPeer.STATE_CLOSED, -1]:
		_disconnect_peer()
		emit_signal("status_changed", "Listening :%d" % _port)


func _disconnect_peer() -> void:
	if _peer:
		_peer.close()
		_peer = null


# ---------------------------------------------------------------------------
# Message handling
# ---------------------------------------------------------------------------

func _handle_message(text: String) -> void:
	var json := JSON.new()
	var err  := json.parse(text)
	if err != OK:
		push_warning("GodotBridge: bad JSON: " + text)
		return

	var msg  : Dictionary = json.get_data()
	var id   : String     = str(msg.get("id",      ""))
	var cmd  : String     = str(msg.get("command", ""))
	var args : Dictionary = msg.get("args", {}) as Dictionary

	if cmd.is_empty():
		_send_error(id, "missing 'command' field")
		return

	_dispatch(id, cmd, args)


func _dispatch(id: String, cmd: String, args: Dictionary) -> void:
	match cmd:
		"editor_state":
			_cmd_editor_state(id, args)
		"node_tree":
			_cmd_node_tree(id, args)
		"node_get":
			_cmd_node_get(id, args)
		"scene_open":
			_cmd_scene_open(id, args)
		"scene_save":
			_cmd_scene_save(id, args)
		"node_add":
			_cmd_node_add(id, args)
		"node_modify":
			_cmd_node_modify(id, args)
		"node_delete":
			_cmd_node_delete(id, args)
		"node_move":
			_cmd_node_move(id, args)
		"scene_run":
			_cmd_scene_run(id, args)
		"scene_stop":
			_cmd_scene_stop(id, args)
		"script_open":
			_cmd_script_open(id, args)
		"resource_list":
			_cmd_resource_list(id, args)
		"screenshot":
			_cmd_screenshot(id, args)
		_:
			_send_error(id, "unknown command: " + cmd)


# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------

func _send_ok(id: String, data: Dictionary) -> void:
	var payload := {"id": id, "ok": true, "data": data}
	_send_json(payload)


func _send_error(id: String, message: String) -> void:
	var payload := {"id": id, "ok": false, "error": message}
	_send_json(payload)


func _send_json(payload: Dictionary) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.send_text(JSON.stringify(payload))


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

## Return the EditorInterface singleton (works in Godot 4.x).
func _ei() -> EditorInterface:
	return EditorInterface


## Resolve a node path string to an actual Node.
## Accepts /root/… absolute paths or scene-relative paths like Main/Player.
func _resolve_node(path: String) -> Node:
	var scene := _ei().get_edited_scene_root()
	if scene == null:
		return null
	if path.is_empty() or path == "/" or path == scene.get_path():
		return scene
	# Try absolute NodePath first, then relative to scene root.
	var node := scene.get_tree().root.get_node_or_null(path)
	if node == null:
		node = scene.get_node_or_null(path)
	return node


## Serialize a node for "brief" listing (name, type, child count).
func _node_brief(node: Node) -> Dictionary:
	return {
		"name":        node.name,
		"type":        node.get_class(),
		"path":        str(node.get_path()),
		"child_count": node.get_child_count(),
	}


## Recursively build a tree dict up to `depth` levels deep.
func _node_tree_dict(node: Node, depth: int) -> Dictionary:
	var d := _node_brief(node)
	if depth > 0:
		var children := []
		for child in node.get_children():
			children.append(_node_tree_dict(child, depth - 1))
		d["children"] = children
	return d


## Serialize a Variant to something JSON-safe.
func _variant_to_json(v) -> Variant:
	match typeof(v):
		TYPE_VECTOR2:
			return [v.x, v.y]
		TYPE_VECTOR3:
			return [v.x, v.y, v.z]
		TYPE_VECTOR4:
			return [v.x, v.y, v.z, v.w]
		TYPE_COLOR:
			return [v.r, v.g, v.b, v.a]
		TYPE_RECT2:
			return {"pos": [v.position.x, v.position.y], "size": [v.size.x, v.size.y]}
		TYPE_TRANSFORM2D:
			return {"x": [v.x.x, v.x.y], "y": [v.y.x, v.y.y], "origin": [v.origin.x, v.origin.y]}
		TYPE_ARRAY:
			var out := []
			for item in v:
				out.append(_variant_to_json(item))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for key in v:
				out[str(key)] = _variant_to_json(v[key])
			return out
		TYPE_NODE_PATH:
			return str(v)
		TYPE_STRING_NAME:
			return str(v)
		_:
			# bool, int, float, String all pass through cleanly
			return v


## Convert a JSON-safe value back to a Godot Variant, guided by `hint`.
## hint is a Variant.Type int from PropertyInfo.
func _json_to_variant(v, type_hint: int) -> Variant:
	match type_hint:
		TYPE_VECTOR2:
			if v is Array and v.size() >= 2:
				return Vector2(v[0], v[1])
		TYPE_VECTOR3:
			if v is Array and v.size() >= 3:
				return Vector3(v[0], v[1], v[2])
		TYPE_COLOR:
			if v is Array and v.size() >= 3:
				return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
		TYPE_NODE_PATH:
			return NodePath(str(v))
		TYPE_BOOL:
			return bool(v)
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
	return v


# ---------------------------------------------------------------------------
# Commands — editor_state
# ---------------------------------------------------------------------------

func _cmd_editor_state(id: String, _args: Dictionary) -> void:
	var ei       := _ei()
	var scene    := ei.get_edited_scene_root()
	var selection: EditorSelection = ei.get_selection()

	var open_scenes := []
	# get_open_scenes() returns PackedStringArray of paths
	for path in ei.get_open_scenes():
		open_scenes.append(str(path))

	var selected_paths := []
	for node in selection.get_selected_nodes():
		selected_paths.append(str(node.get_path()))

	var data := {
		"current_scene": str(scene.get_scene_file_path()) if scene else "",
		"open_scenes":   open_scenes,
		"selected_nodes": selected_paths,
		"editor_screen":  _current_screen_name(),
	}
	_send_ok(id, data)


func _current_screen_name() -> String:
	# EditorInterface.get_editor_viewport() / set_main_screen_editor() variants
	# The current screen is readable via the main screen buttons.
	# As a lightweight approach we check which viewport is visible.
	var ei := _ei()
	if ei.get_editor_viewport_2d().visible:
		return "2D"
	if ei.get_editor_viewport_3d(0).visible:
		return "3D"
	return "Script"


# ---------------------------------------------------------------------------
# Commands — node_tree
# ---------------------------------------------------------------------------

func _cmd_node_tree(id: String, args: Dictionary) -> void:
	var path  : String = str(args.get("path", ""))
	var depth : int    = int(args.get("depth", 4))

	var root := _resolve_node(path)
	if root == null:
		# Default to current scene root when no path given and scene is open.
		root = _ei().get_edited_scene_root()
	if root == null:
		_send_error(id, "No scene is open")
		return

	_send_ok(id, {"tree": _node_tree_dict(root, depth)})


# ---------------------------------------------------------------------------
# Commands — node_get
# ---------------------------------------------------------------------------

func _cmd_node_get(id: String, args: Dictionary) -> void:
	var path   : String = str(args.get("path", ""))
	var detail : String = str(args.get("detail", "brief"))

	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return

	var node := _resolve_node(path)
	if node == null:
		_send_error(id, "Node not found: " + path)
		return

	var data := _node_brief(node)

	if detail == "full":
		# Collect all exported / editor-visible properties.
		var props := {}
		for p in node.get_property_list():
			var usage : int = p["usage"]
			# Only include properties visible in the editor.
			if usage & PROPERTY_USAGE_EDITOR:
				var val = node.get(p["name"])
				props[p["name"]] = _variant_to_json(val)
		data["properties"] = props

		var signals_list := []
		for s in node.get_signal_list():
			signals_list.append(s["name"])
		data["signals"] = signals_list

		var groups_list := []
		for g in node.get_groups():
			groups_list.append(str(g))
		data["groups"] = groups_list

	var children := []
	for child in node.get_children():
		children.append(_node_brief(child))
	data["children"] = children

	_send_ok(id, data)


# ---------------------------------------------------------------------------
# Commands — scene_open
# ---------------------------------------------------------------------------

func _cmd_scene_open(id: String, args: Dictionary) -> void:
	var path : String = str(args.get("path", ""))
	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return
	_ei().open_scene_from_path(path)
	_send_ok(id, {"opened": path})


# ---------------------------------------------------------------------------
# Commands — scene_save
# ---------------------------------------------------------------------------

func _cmd_scene_save(id: String, _args: Dictionary) -> void:
	var scene := _ei().get_edited_scene_root()
	if scene == null:
		_send_error(id, "No scene is open")
		return
	_ei().save_scene()
	_send_ok(id, {"saved": str(scene.get_scene_file_path())})


# ---------------------------------------------------------------------------
# Commands — node_add  (Phase 2)
# ---------------------------------------------------------------------------

func _cmd_node_add(id: String, args: Dictionary) -> void:
	var parent_path : String = str(args.get("parent", ""))
	var type_name   : String = str(args.get("type",   ""))
	var node_name   : String = str(args.get("name",   ""))
	var props       : Dictionary = args.get("props", {}) as Dictionary

	if type_name.is_empty():
		_send_error(id, "missing 'type' arg")
		return

	var parent := _resolve_node(parent_path)
	if parent == null:
		parent = _ei().get_edited_scene_root()
	if parent == null:
		_send_error(id, "No scene open and no valid parent path")
		return

	# ClassDB lets us create any registered class by name.
	if not ClassDB.class_exists(type_name):
		_send_error(id, "Unknown node type: " + type_name)
		return
	if not ClassDB.is_parent_class(type_name, "Node"):
		_send_error(id, type_name + " is not a Node subclass")
		return

	var new_node : Node = ClassDB.instantiate(type_name)
	if node_name.is_empty():
		node_name = type_name
	new_node.name = node_name

	# Apply initial properties before adding to tree.
	_apply_props(new_node, props)

	var undo := _ei().get_editor_undo_redo()
	undo.create_action("Add node " + node_name)
	undo.add_do_method(parent, "add_child", new_node, true)
	undo.add_do_property(new_node, "owner", _ei().get_edited_scene_root())
	undo.add_undo_method(parent, "remove_child", new_node)
	undo.commit_action()

	_send_ok(id, {"path": str(new_node.get_path()), "name": str(new_node.name)})


# ---------------------------------------------------------------------------
# Commands — node_modify  (Phase 2)
# ---------------------------------------------------------------------------

func _cmd_node_modify(id: String, args: Dictionary) -> void:
	var path  : String     = str(args.get("path", ""))
	var props : Dictionary = args.get("props", {}) as Dictionary

	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return
	var node := _resolve_node(path)
	if node == null:
		_send_error(id, "Node not found: " + path)
		return
	if props.is_empty():
		_send_error(id, "missing 'props' arg")
		return

	var undo := _ei().get_editor_undo_redo()
	undo.create_action("Modify node " + path)

	for key in props:
		var old_val = node.get(key)
		var new_val = _coerce_prop(node, key, props[key])
		undo.add_do_property(node, key, new_val)
		undo.add_undo_property(node, key, old_val)

	undo.commit_action()
	_send_ok(id, {"modified": path})


# ---------------------------------------------------------------------------
# Commands — node_delete  (Phase 2)
# ---------------------------------------------------------------------------

func _cmd_node_delete(id: String, args: Dictionary) -> void:
	var path : String = str(args.get("path", ""))
	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return
	var node := _resolve_node(path)
	if node == null:
		_send_error(id, "Node not found: " + path)
		return

	var parent := node.get_parent()
	if parent == null:
		_send_error(id, "Cannot delete root node")
		return

	var undo := _ei().get_editor_undo_redo()
	undo.create_action("Delete node " + path)
	undo.add_do_method(parent, "remove_child", node)
	undo.add_undo_method(parent, "add_child", node, true)
	undo.add_undo_property(node, "owner", _ei().get_edited_scene_root())
	undo.commit_action()

	_send_ok(id, {"deleted": path})


# ---------------------------------------------------------------------------
# Commands — node_move  (Phase 2)
# ---------------------------------------------------------------------------

func _cmd_node_move(id: String, args: Dictionary) -> void:
	var path       : String = str(args.get("path",       ""))
	var new_parent_path : String = str(args.get("new_parent", ""))

	if path.is_empty() or new_parent_path.is_empty():
		_send_error(id, "missing 'path' or 'new_parent' arg")
		return

	var node       := _resolve_node(path)
	var new_parent := _resolve_node(new_parent_path)

	if node == null:
		_send_error(id, "Node not found: " + path)
		return
	if new_parent == null:
		_send_error(id, "New parent not found: " + new_parent_path)
		return

	var old_parent := node.get_parent()
	if old_parent == null:
		_send_error(id, "Cannot move root node")
		return

	var undo := _ei().get_editor_undo_redo()
	undo.create_action("Move node " + path)
	undo.add_do_method(node,       "reparent", new_parent, true)
	undo.add_undo_method(node,     "reparent", old_parent, true)
	undo.commit_action()

	_send_ok(id, {"moved": str(node.get_path())})


# ---------------------------------------------------------------------------
# Commands — scene_run / scene_stop  (Phase 3)
# ---------------------------------------------------------------------------

func _cmd_scene_run(id: String, args: Dictionary) -> void:
	var path : String = str(args.get("path", ""))
	if path.is_empty():
		_ei().play_main_scene()
	else:
		_ei().play_scene(path)
	_send_ok(id, {"running": true})


func _cmd_scene_stop(id: String, _args: Dictionary) -> void:
	_ei().stop_playing_scene()
	_send_ok(id, {"running": false})


# ---------------------------------------------------------------------------
# Commands — script_open
# ---------------------------------------------------------------------------

func _cmd_script_open(id: String, args: Dictionary) -> void:
	var path : String = str(args.get("path", ""))
	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return
	var script := load(path)
	if script == null:
		_send_error(id, "Could not load script: " + path)
		return
	_ei().edit_resource(script)
	_send_ok(id, {"opened": path})


# ---------------------------------------------------------------------------
# Commands — resource_list
# ---------------------------------------------------------------------------

func _cmd_resource_list(id: String, args: Dictionary) -> void:
	var dir_path : String = str(args.get("path", "res://"))
	var fs := _ei().get_resource_filesystem()
	var dir := fs.get_filesystem_path(dir_path)
	if dir == null:
		_send_error(id, "Directory not found: " + dir_path)
		return

	var files := []
	for i in range(dir.get_file_count()):
		files.append({
			"name": dir.get_file(i),
			"type": dir.get_file_type(i),
			"path": dir_path.path_join(dir.get_file(i)),
		})

	var subdirs := []
	for i in range(dir.get_subdir_count()):
		subdirs.append(dir.get_subdir(i).get_path())

	_send_ok(id, {"path": dir_path, "files": files, "subdirs": subdirs})


# ---------------------------------------------------------------------------
# Commands — screenshot
# ---------------------------------------------------------------------------

func _cmd_screenshot(id: String, _args: Dictionary) -> void:
	var viewport := _ei().get_editor_viewport_2d()
	var img      := viewport.get_texture().get_image()
	var bytes    := img.save_png_to_buffer()
	var b64      := Marshalls.raw_to_base64(bytes)
	_send_ok(id, {"png_base64": b64, "width": img.get_width(), "height": img.get_height()})


# ---------------------------------------------------------------------------
# Property coercion helpers
# ---------------------------------------------------------------------------

## Apply a dictionary of JSON-encoded properties to a node.
func _apply_props(node: Node, props: Dictionary) -> void:
	for key in props:
		node.set(key, _coerce_prop(node, key, props[key]))


## Coerce a JSON value to the Godot type expected by the named property.
func _coerce_prop(node: Node, prop_name: String, value) -> Variant:
	for p in node.get_property_list():
		if p["name"] == prop_name:
			return _json_to_variant(value, p["type"])
	return value
