extends RefCounted

const BridgeServer = preload("res://addons/godot_bridge/bridge_server.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_error_payload_prefers_structured_fields(failures)
	_test_error_payload_uses_stack_frame_fallback(failures)
	_test_error_payload_marks_warnings(failures)
	_test_error_payload_defaults_when_metadata_missing(failures)
	return failures


func _test_error_payload_prefers_structured_fields(failures: Array[String]) -> void:
	var payload := BridgeServer._error_event_payload([
		10, 11, 12, 13,
		"res://player.gd",
		"_ready",
		42,
		"Invalid get index 'foo'",
		"Attempt to access missing property",
		false,
		0,
	])
	_assert_eq(failures, payload.get("message", ""), "Attempt to access missing property", "error payload should prefer error_descr")
	_assert_eq(failures, payload.get("script", ""), "res://player.gd", "error payload should keep structured script path")
	_assert_eq(failures, payload.get("line", 0), 42, "error payload should keep structured line")
	_assert_eq(failures, payload.get("column", -1), 0, "error payload should use default column when unavailable")
	_assert_eq(failures, payload.get("severity", ""), "error", "error payload should mark non-warning payloads as error")


func _test_error_payload_uses_stack_frame_fallback(failures: Array[String]) -> void:
	var payload := BridgeServer._error_event_payload([
		10, 11, 12, 13,
		"",
		"",
		0,
		"Division by zero",
		"",
		false,
		3,
		"res://fallback.gd",
		"_process",
		9,
	])
	_assert_eq(failures, payload.get("script", ""), "res://fallback.gd", "error payload should fall back to first stack frame script")
	_assert_eq(failures, payload.get("line", 0), 9, "error payload should fall back to first stack frame line")
	_assert_eq(failures, payload.get("message", ""), "Division by zero", "error payload should fall back to raw error message")


func _test_error_payload_marks_warnings(failures: Array[String]) -> void:
	var payload := BridgeServer._error_event_payload([
		10, 11, 12, 13,
		"res://warn.gd",
		"_ready",
		5,
		"Deprecated call",
		"",
		true,
		0,
	])
	_assert_eq(failures, payload.get("severity", ""), "warning", "warning payloads should emit warning severity")


func _test_error_payload_defaults_when_metadata_missing(failures: Array[String]) -> void:
	var payload := BridgeServer._error_event_payload([])
	_assert_eq(failures, payload.get("message", ""), "", "empty payload should emit empty message")
	_assert_eq(failures, payload.get("script", ""), "", "empty payload should emit empty script")
	_assert_eq(failures, payload.get("line", -1), 0, "empty payload should emit zero line")
	_assert_eq(failures, payload.get("severity", ""), "error", "empty payload should default severity to error")


func _assert_eq(failures: Array[String], actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
