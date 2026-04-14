extends RefCounted

const BridgeDebugState = preload("res://addons/godot_bridge/bridge_debug_state.gd")
const BridgeServer = preload("res://addons/godot_bridge/bridge_server.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_connection_ids_for_event_are_per_connection(failures)
	_test_build_debug_event_payloads_filters_backlog(failures)
	_test_coerce_prop_loads_resource_paths(failures)
	_test_coerce_prop_loads_texture_paths(failures)
	_test_coerce_prop_preserves_null(failures)
	return failures


func _test_connection_ids_for_event_are_per_connection(failures: Array[String]) -> void:
	var server = BridgeServer.new()
	var output_state := BridgeDebugState.new()
	var error_state := BridgeDebugState.new()
	output_state.subscribe(["output"])
	error_state.subscribe(["error"])
	server._connections = {
		1: {"debug_state": output_state},
		2: {"debug_state": error_state},
	}

	_assert_eq(failures, server._connection_ids_for_event("output"), [1], "output events should route only to output subscribers")
	_assert_eq(failures, server._connection_ids_for_event("error"), [2], "error events should route only to error subscribers")
	server.free()


func _test_build_debug_event_payloads_filters_backlog(failures: Array[String]) -> void:
	var server = BridgeServer.new()
	server._debug_backlog = [
		{"event": "output", "data": {"message": "hello"}},
		{"event": "error", "data": {"message": "boom"}},
	]

	var output_payloads: Array[Dictionary] = server._build_debug_event_payloads(["output"])
	_assert_eq(failures, output_payloads.size(), 1, "output-only replay should include one event")
	if output_payloads.size() == 1:
		_assert_eq(failures, output_payloads[0].get("event", ""), "output", "output-only replay should keep the output event")

	var all_payloads: Array[Dictionary] = server._build_debug_event_payloads([])
	_assert_eq(failures, all_payloads.size(), 2, "empty subscription replay should include all backlog events")
	server.free()


func _test_coerce_prop_loads_resource_paths(failures: Array[String]) -> void:
	var server = BridgeServer.new()
	var node := Node.new()
	var value = server._coerce_prop(node, "script", "res://tests/test_bridge_server.gd")
	if not (value is Script):
		failures.append("script resource path should coerce to a Script resource")
	else:
		_assert_eq(failures, value.resource_path, "res://tests/test_bridge_server.gd", "coerced script should keep its resource path")
	node.free()
	server.free()


func _test_coerce_prop_preserves_null(failures: Array[String]) -> void:
	var server = BridgeServer.new()
	var node := Node.new()
	var value = server._coerce_prop(node, "script", null)
	_assert_eq(failures, value, null, "null resource values should stay null")
	node.free()
	server.free()


func _test_coerce_prop_loads_texture_paths(failures: Array[String]) -> void:
	var server = BridgeServer.new()
	var sprite := Sprite2D.new()
	var value = server._coerce_prop(sprite, "material", "res://tests/fixtures/test_material.tres")
	if not (value is Material):
		failures.append("material resource path should coerce to a Material resource")
	else:
		_assert_eq(failures, value.resource_path, "res://tests/fixtures/test_material.tres", "coerced material should keep its resource path")
	sprite.free()
	server.free()


func _assert_eq(failures: Array[String], actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
