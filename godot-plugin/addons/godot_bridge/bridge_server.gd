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

const BridgeAnimationCodec = preload("res://addons/godot_bridge/bridge_animation_codec.gd")
const BridgeDebugState = preload("res://addons/godot_bridge/bridge_debug_state.gd")
const BridgeProjectSettings = preload("res://addons/godot_bridge/bridge_project_settings.gd")

var _tcp_server  : TCPServer
var _peer        : WebSocketPeer
var _port        : int
var _heartbeat_t : float = 0.0
var _debug_state := BridgeDebugState.new()


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
		"scene_new":
			_cmd_scene_new(id, args)
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
		"signal_connect":
			_cmd_signal_connect(id, args)
		"signal_disconnect":
			_cmd_signal_disconnect(id, args)
		"signal_connections":
			_cmd_signal_connections(id, args)
		"node_instance":
			_cmd_node_instance(id, args)
		"project_get":
			_cmd_project_get(id, args)
		"project_set":
			_cmd_project_set(id, args)
		"animation_list":
			_cmd_animation_list(id, args)
		"animation_get":
			_cmd_animation_get(id, args)
		"animation_new":
			_cmd_animation_new(id, args)
		"animation_modify":
			_cmd_animation_modify(id, args)
		"debug_subscribe":
			_cmd_debug_subscribe(id, args)
		"debug_unsubscribe":
			_cmd_debug_unsubscribe(id, args)
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


func push_debug_event(event_name: String, data: Dictionary) -> void:
	# TODO: subscriptions are global because the bridge only supports one client.
	# Support independent subscriptions once the transport allows multiple streams.
	if not _debug_state.should_forward(event_name):
		return
	_send_json({"type": "event", "event": event_name, "data": data})


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

## Resolve a node path string to an actual Node.
## Accepts /root/… absolute paths or scene-relative paths like Main/Player.
func _resolve_node(path: String) -> Node:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		return null
	var scene_prefix := "/root/" + str(scene.name)
	if path.is_empty() or path == "/" or path == scene_prefix:
		return scene
	# Strip /root/<SceneName>/ prefix to get a scene-relative path.
	var rel: String = path
	if path.begins_with(scene_prefix + "/"):
		rel = path.substr(scene_prefix.length() + 1)
	return scene.get_node_or_null(rel)


## Return the user-facing path for a node: /root/<SceneName>[/child/...].
func _node_path(node: Node) -> String:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		return str(node.name)
	if node == scene:
		return "/root/" + str(scene.name)
	return "/root/" + str(scene.name) + "/" + str(scene.get_path_to(node))


## Serialize a node for "brief" listing (name, type, child count).
func _node_brief(node: Node) -> Dictionary:
	return {
		"name":        node.name,
		"type":        node.get_class(),
		"path":        _node_path(node),
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
		TYPE_OBJECT:
			if v is Resource and not v.resource_path.is_empty():
				return v.resource_path
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
		TYPE_PACKED_VECTOR2_ARRAY:
			var arr := PackedVector2Array()
			if v is Array:
				for item in v:
					if item is Array and item.size() >= 2:
						arr.append(Vector2(item[0], item[1]))
			return arr
		TYPE_PACKED_COLOR_ARRAY:
			var arr := PackedColorArray()
			if v is Array:
				for item in v:
					if item is Array and item.size() >= 3:
						arr.append(Color(item[0], item[1], item[2], item[3] if item.size() > 3 else 1.0))
			return arr
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var arr := PackedFloat32Array()
			if v is Array:
				for item in v:
					arr.append(float(item))
			return arr
	return v


# ---------------------------------------------------------------------------
# Commands — editor_state
# ---------------------------------------------------------------------------

func _cmd_editor_state(id: String, _args: Dictionary) -> void:
	var scene    := EditorInterface.get_edited_scene_root()
	var selection: EditorSelection = EditorInterface.get_selection()

	var open_scenes := []
	# get_open_scenes() returns PackedStringArray of paths
	for path in EditorInterface.get_open_scenes():
		open_scenes.append(str(path))

	var selected_paths := []
	for node in selection.get_selected_nodes():
		selected_paths.append(_node_path(node))

	var data := {
		"current_scene": str(scene.get_scene_file_path()) if scene else "",
		"open_scenes":   open_scenes,
		"selected_nodes": selected_paths,
		"editor_screen":  _current_screen_name(),
	}
	_send_ok(id, data)


func _current_screen_name() -> String:
	var vp2d := EditorInterface.get_editor_viewport_2d()
	if vp2d and vp2d.get_parent() and vp2d.get_parent().visible:
		return "2D"
	var vp3d := EditorInterface.get_editor_viewport_3d(0)
	if vp3d and vp3d.get_parent() and vp3d.get_parent().visible:
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
		root = EditorInterface.get_edited_scene_root()
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
# Commands — scene_new
# ---------------------------------------------------------------------------

func _cmd_scene_new(id: String, args: Dictionary) -> void:
	var path      : String = str(args.get("path", ""))
	var root_type : String = str(args.get("root_type", "Node2D"))
	var root_name : String = str(args.get("root_name", ""))

	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return
	if not path.ends_with(".tscn"):
		_send_error(id, "'path' must end with .tscn")
		return
	if not ClassDB.class_exists(root_type) or not ClassDB.is_parent_class(root_type, "Node"):
		_send_error(id, "Unknown or non-Node root_type: " + root_type)
		return

	var root : Node = ClassDB.instantiate(root_type)
	root.name = root_name if not root_name.is_empty() else root_type

	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		_send_error(id, "PackedScene.pack() failed (error %d)" % err)
		return

	err = ResourceSaver.save(packed, path)
	if err != OK:
		_send_error(id, "ResourceSaver.save() failed (error %d)" % err)
		return

	EditorInterface.open_scene_from_path(path)
	_send_ok(id, {"path": path, "root_type": root_type})


# ---------------------------------------------------------------------------
# Commands — scene_open
# ---------------------------------------------------------------------------

func _cmd_scene_open(id: String, args: Dictionary) -> void:
	var path : String = str(args.get("path", ""))
	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return
	EditorInterface.open_scene_from_path(path)
	_send_ok(id, {"opened": path})


# ---------------------------------------------------------------------------
# Commands — scene_save
# ---------------------------------------------------------------------------

func _cmd_scene_save(id: String, _args: Dictionary) -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		_send_error(id, "No scene is open")
		return
	EditorInterface.save_scene()
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
		parent = EditorInterface.get_edited_scene_root()
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

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Add node " + node_name)
	undo.add_do_method(parent, "add_child", new_node, true)
	undo.add_do_property(new_node, "owner", EditorInterface.get_edited_scene_root())
	undo.add_undo_method(parent, "remove_child", new_node)
	undo.commit_action()

	_send_ok(id, {"path": _node_path(new_node), "name": str(new_node.name)})


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

	var undo := EditorInterface.get_editor_undo_redo()
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

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Delete node " + path)
	undo.add_do_method(parent, "remove_child", node)
	undo.add_undo_method(parent, "add_child", node, true)
	undo.add_undo_property(node, "owner", EditorInterface.get_edited_scene_root())
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

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Move node " + path)
	undo.add_do_method(node,       "reparent", new_parent, true)
	undo.add_undo_method(node,     "reparent", old_parent, true)
	undo.commit_action()

	_send_ok(id, {"moved": _node_path(node)})


# ---------------------------------------------------------------------------
# Commands — signals
# ---------------------------------------------------------------------------

func _cmd_signal_connect(id: String, args: Dictionary) -> void:
	var source_path := str(args.get("source", ""))
	var signal_name := str(args.get("signal", ""))
	var target_path := str(args.get("target", ""))
	var method_name := str(args.get("method", ""))
	if source_path.is_empty() or signal_name.is_empty() or target_path.is_empty() or method_name.is_empty():
		_send_error(id, "missing signal connection args")
		return

	var source := _resolve_node(source_path)
	var target := _resolve_node(target_path)
	if source == null:
		_send_error(id, "Node not found: " + source_path)
		return
	if target == null:
		_send_error(id, "Node not found: " + target_path)
		return
	if not source.has_signal(signal_name):
		_send_error(id, "Signal not found on source: " + signal_name)
		return

	var callable := Callable(target, method_name)
	if source.is_connected(signal_name, callable):
		_send_error(id, "Signal is already connected")
		return

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Connect signal " + signal_name)
	undo.add_do_method(source, "connect", signal_name, callable)
	undo.add_undo_method(source, "disconnect", signal_name, callable)
	undo.commit_action()
	_send_ok(id, {"source": source_path, "signal": signal_name, "target": target_path, "method": method_name})


func _cmd_signal_disconnect(id: String, args: Dictionary) -> void:
	var source_path := str(args.get("source", ""))
	var signal_name := str(args.get("signal", ""))
	var target_path := str(args.get("target", ""))
	var method_name := str(args.get("method", ""))
	if source_path.is_empty() or signal_name.is_empty() or target_path.is_empty() or method_name.is_empty():
		_send_error(id, "missing signal disconnection args")
		return

	var source := _resolve_node(source_path)
	var target := _resolve_node(target_path)
	if source == null:
		_send_error(id, "Node not found: " + source_path)
		return
	if target == null:
		_send_error(id, "Node not found: " + target_path)
		return

	var callable := Callable(target, method_name)
	if not source.is_connected(signal_name, callable):
		_send_error(id, "Signal is not connected")
		return

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Disconnect signal " + signal_name)
	undo.add_do_method(source, "disconnect", signal_name, callable)
	undo.add_undo_method(source, "connect", signal_name, callable)
	undo.commit_action()
	_send_ok(id, {"source": source_path, "signal": signal_name, "target": target_path, "method": method_name})


func _cmd_signal_connections(id: String, args: Dictionary) -> void:
	var path := str(args.get("path", ""))
	if path.is_empty():
		_send_error(id, "missing 'path' arg")
		return

	var node := _resolve_node(path)
	if node == null:
		_send_error(id, "Node not found: " + path)
		return

	var connections := []
	for signal_info in node.get_signal_list():
		var signal_name := str(signal_info.get("name", ""))
		for connection in node.get_signal_connection_list(signal_name):
			var callable: Callable = connection.get("callable", Callable())
			var target = callable.get_object()
			connections.append({
				"signal": signal_name,
				"target": _node_path(target) if target is Node else "",
				"method": str(callable.get_method()),
				"flags": int(connection.get("flags", 0)),
			})
	_send_ok(id, {"connections": connections})


# ---------------------------------------------------------------------------
# Commands — node_instance
# ---------------------------------------------------------------------------

func _cmd_node_instance(id: String, args: Dictionary) -> void:
	var scene_path := str(args.get("scene", ""))
	var parent_path := str(args.get("parent", ""))
	var node_name := str(args.get("name", ""))
	if scene_path.is_empty():
		_send_error(id, "missing 'scene' arg")
		return

	var parent := _resolve_node(parent_path)
	if parent == null:
		parent = EditorInterface.get_edited_scene_root()
	if parent == null:
		_send_error(id, "No scene open and no valid parent path")
		return

	var packed := load(scene_path)
	if packed == null or not (packed is PackedScene):
		_send_error(id, "scene is not a PackedScene: " + scene_path)
		return

	var instance := (packed as PackedScene).instantiate()
	if not instance is Node:
		_send_error(id, "instanced root is not a Node")
		return
	if not node_name.is_empty():
		instance.name = node_name

	var owner := EditorInterface.get_edited_scene_root()
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Instance scene " + scene_path)
	undo.add_do_method(parent, "add_child", instance, true)
	undo.add_do_property(instance, "owner", owner)
	undo.add_undo_method(parent, "remove_child", instance)
	undo.commit_action()
	_send_ok(id, _node_brief(instance))


# ---------------------------------------------------------------------------
# Commands — project settings
# ---------------------------------------------------------------------------

func _cmd_project_get(id: String, args: Dictionary) -> void:
	var keys := args.get("keys", []) as Array
	var prefix := str(args.get("prefix", ""))
	if keys.is_empty() and prefix.is_empty():
		_send_error(id, "project_get requires 'keys' and/or 'prefix'")
		return

	var settings := BridgeProjectSettings.read_settings(
		ProjectSettings.get_property_list(),
		Callable(ProjectSettings, "get_setting"),
		keys,
		prefix
	)
	for key in settings.keys():
		settings[key] = _variant_to_json(settings[key])
	_send_ok(id, {"settings": settings})


func _cmd_project_set(id: String, args: Dictionary) -> void:
	var settings := args.get("settings", {}) as Dictionary
	if settings.is_empty():
		_send_error(id, "missing 'settings' arg")
		return

	var updated := []
	for key in settings.keys():
		ProjectSettings.set_setting(str(key), settings[key])
		updated.append(str(key))
	var err := ProjectSettings.save()
	if err != OK:
		_send_error(id, "ProjectSettings.save() failed (error %d)" % err)
		return
	updated.sort()
	_send_ok(id, {"updated": updated})


# ---------------------------------------------------------------------------
# Commands — animation
# ---------------------------------------------------------------------------

func _cmd_animation_list(id: String, args: Dictionary) -> void:
	var player := _resolve_animation_player(str(args.get("path", "")))
	if player == null:
		_send_error(id, "AnimationPlayer not found")
		return

	var animations := []
	for animation_name in player.get_animation_list():
		var name := str(animation_name)
		animations.append(BridgeAnimationCodec.animation_summary(name, player.get_animation(name)))
	_send_ok(id, {"animations": animations})


func _cmd_animation_get(id: String, args: Dictionary) -> void:
	var player := _resolve_animation_player(str(args.get("path", "")))
	var animation_name := str(args.get("animation", ""))
	if player == null:
		_send_error(id, "AnimationPlayer not found")
		return
	if animation_name.is_empty() or not player.has_animation(animation_name):
		_send_error(id, "Animation not found: " + animation_name)
		return
	_send_ok(id, BridgeAnimationCodec.animation_detail(animation_name, player.get_animation(animation_name), Callable(self, "_variant_to_json")))


func _cmd_animation_new(id: String, args: Dictionary) -> void:
	var player := _resolve_animation_player(str(args.get("path", "")))
	var animation_name := str(args.get("name", ""))
	if player == null:
		_send_error(id, "AnimationPlayer not found")
		return
	if animation_name.is_empty():
		_send_error(id, "missing 'name' arg")
		return

	var library := _ensure_default_animation_library(player)
	if library.has_animation(animation_name):
		_send_error(id, "Animation already exists: " + animation_name)
		return

	var animation := BridgeAnimationCodec.build_animation(args, Callable(self, "_animation_value_from_json").bind(player))
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Create animation " + animation_name)
	undo.add_do_method(library, "add_animation", animation_name, animation)
	undo.add_undo_method(library, "remove_animation", animation_name)
	undo.commit_action()
	_send_ok(id, BridgeAnimationCodec.animation_summary(animation_name, animation))


func _cmd_animation_modify(id: String, args: Dictionary) -> void:
	var player := _resolve_animation_player(str(args.get("path", "")))
	var animation_name := str(args.get("animation", ""))
	if player == null:
		_send_error(id, "AnimationPlayer not found")
		return
	if animation_name.is_empty() or not player.has_animation(animation_name):
		_send_error(id, "Animation not found: " + animation_name)
		return

	var library := _ensure_default_animation_library(player)
	if not library.has_animation(animation_name):
		_send_error(id, "Only animations in the default library can be modified")
		return
	var existing := library.get_animation(animation_name)
	var updated := BridgeAnimationCodec.apply_animation_changes(existing, args, Callable(self, "_animation_value_from_json").bind(player))

	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Modify animation " + animation_name)
	undo.add_do_method(library, "remove_animation", animation_name)
	undo.add_do_method(library, "add_animation", animation_name, updated)
	undo.add_undo_method(library, "remove_animation", animation_name)
	undo.add_undo_method(library, "add_animation", animation_name, existing)
	undo.commit_action()
	_send_ok(id, BridgeAnimationCodec.animation_summary(animation_name, updated))


func _resolve_animation_player(path: String) -> AnimationPlayer:
	if path.is_empty():
		return null
	var node := _resolve_node(path)
	if node == null or not (node is AnimationPlayer):
		return null
	return node as AnimationPlayer


func _ensure_default_animation_library(player: AnimationPlayer) -> AnimationLibrary:
	var library := player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		player.add_animation_library("", library)
	return library


func _animation_value_from_json(player: AnimationPlayer, track_path: String, value):
	var separator := track_path.find(":")
	if separator == -1:
		return value
	var node_path := track_path.substr(0, separator)
	var property_name := track_path.substr(separator + 1)
	var root_node := player.get_node_or_null(player.get_root())
	if root_node == null:
		root_node = player.get_parent()
	if root_node == null:
		return value
	var target: Node = null
	if node_path.is_empty() or node_path == ".":
		target = root_node
	else:
		target = root_node.get_node_or_null(NodePath(node_path))
	if target == null:
		return value
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return _json_to_variant(value, int(property_info.get("type", TYPE_NIL)))
	return value


# ---------------------------------------------------------------------------
# Commands — debug subscriptions
# ---------------------------------------------------------------------------

func _cmd_debug_subscribe(id: String, args: Dictionary) -> void:
	var events := args.get("events", []) as Array
	_send_ok(id, {"subscribed": _debug_state.subscribe(events)})


func _cmd_debug_unsubscribe(id: String, args: Dictionary) -> void:
	var events := args.get("events", []) as Array
	_send_ok(id, {"subscribed": _debug_state.unsubscribe(events)})


# ---------------------------------------------------------------------------
# Commands — scene_run / scene_stop  (Phase 3)
# ---------------------------------------------------------------------------

func _cmd_scene_run(id: String, args: Dictionary) -> void:
	var path : String = str(args.get("path", ""))
	if path.is_empty():
		EditorInterface.play_main_scene()
	else:
		EditorInterface.open_scene_from_path(path)
		EditorInterface.play_current_scene()
	_send_ok(id, {"running": true})


func _cmd_scene_stop(id: String, _args: Dictionary) -> void:
	EditorInterface.stop_playing_scene()
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
	EditorInterface.edit_resource(script)
	_send_ok(id, {"opened": path})


# ---------------------------------------------------------------------------
# Commands — resource_list
# ---------------------------------------------------------------------------

func _cmd_resource_list(id: String, args: Dictionary) -> void:
	var dir_path : String = str(args.get("path", "res://"))
	var fs := EditorInterface.get_resource_filesystem()
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
	var viewport := EditorInterface.get_editor_viewport_2d()
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
