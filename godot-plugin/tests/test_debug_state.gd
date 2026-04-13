extends RefCounted

const BridgeDebugState = preload("res://addons/godot_bridge/bridge_debug_state.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_subscribe_all_then_unsubscribe_subset(failures)
	_test_normalize_events_filters_duplicates(failures)
	return failures


func _test_subscribe_all_then_unsubscribe_subset(failures: Array[String]) -> void:
	var state := BridgeDebugState.new()
	var subscribed := state.subscribe([])
	_assert_eq(failures, subscribed, ["output", "error"], "subscribe([]) should enable all events")
	_assert_true(failures, state.should_forward("output"), "output should be forwarded after subscribe all")
	_assert_true(failures, state.should_forward("error"), "error should be forwarded after subscribe all")

	subscribed = state.unsubscribe(["error"])
	_assert_eq(failures, subscribed, ["output"], "unsubscribe(error) should leave output")
	_assert_true(failures, state.should_forward("output"), "output should still be forwarded")
	_assert_false(failures, state.should_forward("error"), "error should stop forwarding")


func _test_normalize_events_filters_duplicates(failures: Array[String]) -> void:
	var events := BridgeDebugState.normalize_events([" output ", "error", "output", "unknown"])
	_assert_eq(failures, events, ["output", "error"], "normalize_events should trim, dedupe, and filter invalid values")


func _assert_eq(failures: Array[String], actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func _assert_true(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _assert_false(failures: Array[String], condition: bool, message: String) -> void:
	if condition:
		failures.append(message)
