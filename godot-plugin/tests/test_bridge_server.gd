extends RefCounted

const BridgeDebugState = preload("res://addons/godot_bridge/bridge_debug_state.gd")
const BridgeServer = preload("res://addons/godot_bridge/bridge_server.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_connection_ids_for_event_are_per_connection(failures)
	_test_build_debug_event_payloads_filters_backlog(failures)
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


func _test_build_debug_event_payloads_filters_backlog(failures: Array[String]) -> void:
	var server = BridgeServer.new()
	server._debug_backlog = [
		{"event": "output", "data": {"message": "hello"}},
		{"event": "error", "data": {"message": "boom"}},
	]

	var output_payloads := server._build_debug_event_payloads(["output"])
	_assert_eq(failures, output_payloads.size(), 1, "output-only replay should include one event")
	if output_payloads.size() == 1:
		_assert_eq(failures, output_payloads[0].get("event", ""), "output", "output-only replay should keep the output event")

	var all_payloads := server._build_debug_event_payloads([])
	_assert_eq(failures, all_payloads.size(), 2, "empty subscription replay should include all backlog events")


func _assert_eq(failures: Array[String], actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
