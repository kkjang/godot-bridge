@tool
class_name BridgeDebugger
extends EditorDebuggerPlugin

var _server


func _init(server = null) -> void:
	_server = server


func set_server(server) -> void:
	_server = server


func _has_capture(capture: String) -> bool:
	return capture in ["output", "error"]


func _capture(message: String, data: Array, _session_id: int) -> bool:
	if _server == null:
		return false

	if message.begins_with("output"):
		_server.push_debug_event("output", _output_payload(data))
		return true
	if message.begins_with("error"):
		_server.push_debug_event("error", _error_payload(data))
		return true
	return false


static func _output_payload(data: Array) -> Dictionary:
	return {
		"message": str(data[0]) if data.size() > 0 else "",
		"timestamp": Time.get_ticks_msec(),
	}


static func _error_payload(data: Array) -> Dictionary:
	return {
		"message": str(data[0]) if data.size() > 0 else "",
		"script": str(data[1]) if data.size() > 1 else "",
		"line": int(data[2]) if data.size() > 2 else 0,
		"timestamp": Time.get_ticks_msec(),
	}
