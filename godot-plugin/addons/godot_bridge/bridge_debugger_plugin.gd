@tool
extends EditorDebuggerPlugin

const CAPTURE_PREFIX := "godot_bridge"
const SCREENSHOT_MESSAGE := "godot_bridge:screenshot"
const SCREENSHOT_RESULT_MESSAGE := "godot_bridge:screenshot_result"

var _server: Node


func set_server(server: Node) -> void:
	_server = server


func request_game_screenshot(seq: int) -> bool:
	for session in get_sessions():
		if session == null or not session.is_active():
			continue
		session.send_message(SCREENSHOT_MESSAGE, [{"seq": seq}])
		return true
	return false


func _has_capture(capture: String) -> bool:
	return capture == CAPTURE_PREFIX


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != SCREENSHOT_RESULT_MESSAGE:
		return false
	if _server:
		_server.handle_game_screenshot_result(session_id, data)
	return true
