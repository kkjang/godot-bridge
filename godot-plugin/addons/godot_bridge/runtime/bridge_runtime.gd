extends Node

const CAPTURE_PREFIX := &"godot_bridge"
const SCREENSHOT_RESULT_MESSAGE := "godot_bridge:screenshot_result"

var _capture_registered := false


func _ready() -> void:
	if not OS.is_debug_build() or not EngineDebugger.is_active():
		return
	if not EngineDebugger.has_capture(CAPTURE_PREFIX):
		EngineDebugger.register_message_capture(CAPTURE_PREFIX, _on_capture)
	_capture_registered = true


func _exit_tree() -> void:
	if not _capture_registered:
		return
	if EngineDebugger.has_capture(CAPTURE_PREFIX):
		EngineDebugger.unregister_message_capture(CAPTURE_PREFIX)
	_capture_registered = false


func _on_capture(message: String, data: Array) -> bool:
	if message != "screenshot":
		return false

	var seq := _extract_seq(data)
	if seq < 0:
		_send_result({"seq": seq, "error": "invalid screenshot request"})
		return true

	var root := get_tree().root
	if root == null:
		_send_result({"seq": seq, "error": "no running game"})
		return true

	var image := root.get_texture().get_image()
	var png_bytes := image.save_png_to_buffer()
	_send_result({
		"seq": seq,
		"png_base64": Marshalls.raw_to_base64(png_bytes),
		"width": image.get_width(),
		"height": image.get_height(),
	})
	return true


func _extract_seq(data: Array) -> int:
	if data.is_empty():
		return -1
	var payload = data[0]
	if payload is Dictionary:
		return int((payload as Dictionary).get("seq", -1))
	return int(payload)


func _send_result(payload: Dictionary) -> void:
	if not EngineDebugger.is_active():
		return
	EngineDebugger.send_message(SCREENSHOT_RESULT_MESSAGE, [payload])
