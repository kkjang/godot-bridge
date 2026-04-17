extends RefCounted

const BridgeServer = preload("res://addons/godot_bridge/bridge_server.gd")

const PORT := 6515
const SHEET_PATH := "res://tests/fixtures/hero_sheet.png"
const MANIFEST_PATH := "res://tests/fixtures/hero_sheet.json"
const SCENE_PATH := "res://tests/fixtures/from_manifest_scene.tscn"
const OUTPUT_PATH := "res://tests/fixtures/hero_frames_from_manifest.tres"
const DEFAULT_OUTPUT_PATH := "res://tests/fixtures/default_frames_from_manifest.tres"
const MIXED_OUTPUT_PATH := "res://tests/fixtures/mixed_frames_from_manifest.tres"
const FAILED_OUTPUT_PATH := "res://tests/fixtures/failed_frames_from_manifest.tres"
const BROKEN_SHEET_PATH := "res://tests/fixtures/broken_sheet.png"
const SOCKET_URL := "ws://127.0.0.1:%d" % PORT


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_no_tag_falls_back_to_default_animation(failures)
	_test_mixed_durations_become_relative_frame_multipliers(failures)
	return failures


func run_editor_integration(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	_cleanup_generated_files()
	_ensure_sheet_fixture(failures)
	if not failures.is_empty():
		return failures

	var socket := await _connect_socket(tree, failures)
	if socket == null:
		return failures

	var happy_response := await _run_happy_path(tree, socket, failures)
	await _run_no_tag_command(tree, socket, failures)
	await _run_mixed_duration_command(tree, socket, failures)
	await _run_missing_uid_error(tree, socket, failures)

	if happy_response.has("data"):
		_assert_saved_uid_matches_sheet_import(failures, happy_response.get("data", {}) as Dictionary)

	socket.close()
	_cleanup_generated_files()
	return failures


func _test_no_tag_falls_back_to_default_animation(failures: Array[String]) -> void:
	var server := BridgeServer.new()
	var result := server._build_sprite_frames_from_manifest_spec(SHEET_PATH, {
		"version": 1,
		"frames": [
			{"name": "frame_0", "x": 0, "y": 0, "w": 32, "h": 32},
			{"name": "frame_1", "x": 32, "y": 0, "w": 32, "h": 32},
		],
	}, 10.0)
	if result.has("error"):
		failures.append("manifest spec builder should accept untagged frames")
		server.free()
		return
	var animations := result.get("animations", []) as Array
	_assert_eq(failures, animations.size(), 1, "untagged manifest should produce one animation")
	if animations.size() == 1:
		var animation := animations[0] as Dictionary
		_assert_eq(failures, animation.get("name", ""), "default", "untagged manifest should use the default animation name")
		_assert_eq(failures, (animation.get("frames", []) as Array).size(), 2, "untagged manifest should preserve frame order")
	server.free()


func _test_mixed_durations_become_relative_frame_multipliers(failures: Array[String]) -> void:
	var server := BridgeServer.new()
	var result := server._build_sprite_frames_from_manifest_spec(SHEET_PATH, {
		"version": 1,
		"frames": [
			{"name": "walk_0", "x": 0, "y": 0, "w": 32, "h": 32, "duration_ms": 100, "tag": "walk"},
			{"name": "walk_1", "x": 32, "y": 0, "w": 32, "h": 32, "duration_ms": 200, "tag": "walk"},
		],
	}, 10.0)
	if result.has("error"):
		failures.append("manifest spec builder should accept mixed frame durations")
		server.free()
		return
	var animation := ((result.get("animations", []) as Array)[0] as Dictionary)
	var frames := animation.get("frames", []) as Array
	_assert_close(failures, float(animation.get("speed", 0.0)), 1000.0 / 150.0, 0.0001, "mixed durations should use the average animation FPS")
	_assert_close(failures, float((frames[0] as Dictionary).get("duration", 0.0)), 100.0 / 150.0, 0.0001, "first frame should scale duration relative to the average")
	_assert_close(failures, float((frames[1] as Dictionary).get("duration", 0.0)), 200.0 / 150.0, 0.0001, "second frame should scale duration relative to the average")
	server.free()


func _run_happy_path(tree: SceneTree, socket: WebSocketPeer, failures: Array[String]) -> Dictionary:
	var manifest := _load_manifest_fixture(failures)
	if manifest.is_empty():
		return {}

	var scene_response := await _send_command(tree, socket, "scene_new", {
		"path": SCENE_PATH,
		"root_type": "Node2D",
		"root_name": "Main",
	})
	_assert_ok(failures, scene_response, "scene_new should succeed for manifest integration")

	var node_response := await _send_command(tree, socket, "node_add", {
		"type": "AnimatedSprite2D",
		"parent": "/root/Main",
		"name": "AnimatedSprite2D",
	})
	_assert_ok(failures, node_response, "node_add should create the AnimatedSprite2D target node")

	var response := await _send_command(tree, socket, "sprite_frames_from_manifest", {
		"out_path": OUTPUT_PATH,
		"sheet_path": SHEET_PATH,
		"manifest": manifest,
		"node_path": "/root/Main/AnimatedSprite2D",
		"default_fps": 10,
	})
	_assert_ok(failures, response, "sprite_frames_from_manifest should succeed for a valid sheet manifest")
	if not bool(response.get("ok", false)):
		return response

	var data := response.get("data", {}) as Dictionary
	_assert_eq(failures, data.get("path", ""), OUTPUT_PATH, "manifest import should report the saved resource path")
	_assert_true(failures, str(data.get("sheet_uid", "")).begins_with("uid://"), "manifest import should return the resolved sheet UID")
	_assert_true(failures, str(data.get("uid", "")).begins_with("uid://"), "manifest import should return the saved SpriteFrames UID")

	var animations := data.get("animations", []) as Array
	_assert_eq(failures, animations.size(), 2, "happy path should create two animations")
	if animations.size() == 2:
		_assert_animation_shape(failures, animations[0] as Dictionary, "idle", [Rect2(0, 0, 32, 32), Rect2(32, 0, 32, 32)], 10.0)
		_assert_animation_shape(failures, animations[1] as Dictionary, "run", [Rect2(64, 0, 32, 32), Rect2(96, 0, 32, 32)], 10.0)

	var node_get := await _send_command(tree, socket, "node_get", {
		"path": "/root/Main/AnimatedSprite2D",
		"detail": "full",
	})
	_assert_ok(failures, node_get, "node_get should read the node after manifest assignment")
	if bool(node_get.get("ok", false)):
		var properties := (node_get.get("data", {}) as Dictionary).get("properties", {}) as Dictionary
		_assert_eq(failures, properties.get("sprite_frames", ""), OUTPUT_PATH, "node assignment should point AnimatedSprite2D.sprite_frames at the saved resource")

	return response


func _run_no_tag_command(tree: SceneTree, socket: WebSocketPeer, failures: Array[String]) -> void:
	var response := await _send_command(tree, socket, "sprite_frames_from_manifest", {
		"out_path": DEFAULT_OUTPUT_PATH,
		"sheet_path": SHEET_PATH,
		"manifest": {
			"version": 1,
			"frames": [
				{"name": "frame_0", "x": 0, "y": 0, "w": 32, "h": 32},
				{"name": "frame_1", "x": 32, "y": 0, "w": 32, "h": 32},
			],
		},
		"default_fps": 10,
	})
	_assert_ok(failures, response, "manifest import should accept untagged frames")
	if not bool(response.get("ok", false)):
		return
	var animations := ((response.get("data", {}) as Dictionary).get("animations", []) as Array)
	_assert_eq(failures, animations.size(), 1, "untagged manifest command should create one animation")
	if animations.size() == 1:
		_assert_eq(failures, (animations[0] as Dictionary).get("name", ""), "default", "untagged manifest command should use the default animation name")


func _run_mixed_duration_command(tree: SceneTree, socket: WebSocketPeer, failures: Array[String]) -> void:
	var response := await _send_command(tree, socket, "sprite_frames_from_manifest", {
		"out_path": MIXED_OUTPUT_PATH,
		"sheet_path": SHEET_PATH,
		"manifest": {
			"version": 1,
			"frames": [
				{"name": "walk_0", "x": 0, "y": 0, "w": 32, "h": 32, "duration_ms": 100, "tag": "walk"},
				{"name": "walk_1", "x": 32, "y": 0, "w": 32, "h": 32, "duration_ms": 200, "tag": "walk"},
			],
		},
		"default_fps": 10,
	})
	_assert_ok(failures, response, "manifest import should support mixed frame durations")
	if not bool(response.get("ok", false)):
		return
	var animations := ((response.get("data", {}) as Dictionary).get("animations", []) as Array)
	if animations.is_empty():
		failures.append("mixed duration command should return one animation")
		return
	var animation := animations[0] as Dictionary
	var frames := animation.get("frames", []) as Array
	if frames.size() < 2:
		failures.append("mixed duration command should return two frames")
		return
	_assert_close(failures, float(animation.get("speed", 0.0)), 1000.0 / 150.0, 0.0001, "mixed duration command should use the average animation FPS")
	_assert_close(failures, float((frames[0] as Dictionary).get("duration", 0.0)), 100.0 / 150.0, 0.0001, "mixed duration command should scale the first frame duration")
	_assert_close(failures, float((frames[1] as Dictionary).get("duration", 0.0)), 200.0 / 150.0, 0.0001, "mixed duration command should scale the second frame duration")


func _run_missing_uid_error(tree: SceneTree, socket: WebSocketPeer, failures: Array[String]) -> void:
	var broken_path := ProjectSettings.globalize_path(BROKEN_SHEET_PATH)
	var file := FileAccess.open(broken_path, FileAccess.WRITE)
	if file == null:
		failures.append("failed to create broken PNG fixture for missing UID test")
		return
	file.store_string("not a png")
	file.close()

	var response := await _send_command(tree, socket, "sprite_frames_from_manifest", {
		"out_path": FAILED_OUTPUT_PATH,
		"sheet_path": BROKEN_SHEET_PATH,
		"manifest": {
			"version": 1,
			"frames": [
				{"name": "broken_0", "x": 0, "y": 0, "w": 32, "h": 32, "tag": "broken"},
			],
		},
		"default_fps": 10,
	})
	_assert_error_contains(failures, response, "UID", "invalid sheet import should fail before writing a broken SpriteFrames resource")
	_assert_true(failures, not FileAccess.file_exists(FAILED_OUTPUT_PATH), "failed manifest import should not write an output SpriteFrames resource")
	_cleanup_path(BROKEN_SHEET_PATH)


func _connect_socket(tree: SceneTree, failures: Array[String]) -> WebSocketPeer:
	for _attempt in range(120):
		var socket := WebSocketPeer.new()
		var err := socket.connect_to_url(SOCKET_URL)
		if err == OK:
			for _spin in range(120):
				socket.poll()
				if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
					return socket
				if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
					break
				await tree.process_frame
		await tree.create_timer(0.1).timeout
	failures.append("failed to connect to the headless editor bridge at %s" % SOCKET_URL)
	return null


func _send_command(tree: SceneTree, socket: WebSocketPeer, command: String, args: Dictionary) -> Dictionary:
	var request_id := str(Time.get_ticks_usec())
	var send_err := socket.send_text(JSON.stringify({
		"id": request_id,
		"command": command,
		"args": args,
	}))
	if send_err != OK:
		return {"ok": false, "error": "failed to send %s (error %d)" % [command, send_err]}

	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet().get_string_from_utf8()
			var parsed = JSON.parse_string(packet)
			if not (parsed is Dictionary):
				continue
			var message := parsed as Dictionary
			if str(message.get("type", "")) == "ping":
				continue
			if str(message.get("id", "")) != request_id:
				continue
			return message
		await tree.process_frame
	return {"ok": false, "error": "%s timed out waiting for a response" % command}


func _assert_saved_uid_matches_sheet_import(failures: Array[String], response_data: Dictionary) -> void:
	var sprite_frames_text := FileAccess.get_file_as_string(OUTPUT_PATH)
	if sprite_frames_text.is_empty():
		failures.append("saved SpriteFrames resource should be readable as text for UID verification")
		return
	var ext_uid := _extract_uid(sprite_frames_text, "ext_resource")
	if ext_uid.is_empty():
		failures.append("saved SpriteFrames resource should reference the sheet through an ext_resource UID")

	var import_text := FileAccess.get_file_as_string(SHEET_PATH + ".import")
	if import_text.is_empty():
		failures.append("sheet import sidecar should exist after manifest import")
		return
	var import_uid := _extract_uid(import_text, "uid")
	if import_uid.is_empty():
		failures.append("sheet import sidecar should record a UID")
		return
	_assert_eq(failures, ext_uid, import_uid, "saved SpriteFrames should use the same sheet UID Godot imported")
	_assert_eq(failures, ext_uid, response_data.get("sheet_uid", ""), "response should report the same sheet UID written into the saved resource")


func _extract_uid(text: String, marker: String) -> String:
	for line in text.split("\n"):
		if marker == "ext_resource" and not line.contains("ext_resource"):
			continue
		if marker == "uid" and not line.contains("uid="):
			continue
		var regex := RegEx.new()
		if regex.compile('uid="([^"]+)"') != OK:
			return ""
		var match := regex.search(line)
		if match != null:
			return match.get_string(1)
	return ""


func _load_manifest_fixture(failures: Array[String]) -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		failures.append("failed to read manifest fixture")
		return {}
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		failures.append("manifest fixture should parse into a dictionary")
		return {}
	return parsed as Dictionary


func _assert_animation_shape(failures: Array[String], animation: Dictionary, expected_name: String, expected_regions: Array, expected_speed: float) -> void:
	_assert_eq(failures, animation.get("name", ""), expected_name, "animation should keep the manifest tag name")
	_assert_close(failures, float(animation.get("speed", 0.0)), expected_speed, 0.0001, "animation should keep a 10 FPS speed when all frames have 100 ms duration")
	_assert_eq(failures, animation.get("loop", false), true, "manifest import should default animations to loop")
	var frames := animation.get("frames", []) as Array
	_assert_eq(failures, frames.size(), expected_regions.size(), "animation should preserve the manifest frame count")
	for index in range(min(frames.size(), expected_regions.size())):
		var frame := frames[index] as Dictionary
		_assert_eq(failures, frame.get("texture", ""), SHEET_PATH, "animation frame should reference the sheet path")
		_assert_close(failures, float(frame.get("duration", 0.0)), 1.0, 0.0001, "uniform frame durations should map to duration multiplier 1.0")
		var region := frame.get("region", {}) as Dictionary
		var rect := Rect2(
			float(region.get("x", 0.0)),
			float(region.get("y", 0.0)),
			float(region.get("w", 0.0)),
			float(region.get("h", 0.0))
		)
		_assert_eq(failures, rect, expected_regions[index], "animation frame region should match the manifest rectangle")


func _ensure_sheet_fixture(failures: Array[String]) -> void:
	var image := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for x in range(32):
		for y in range(32):
			image.set_pixel(x, y, Color(1.0, 0.0, 0.0, 1.0))
			image.set_pixel(x + 32, y, Color(0.0, 1.0, 0.0, 1.0))
			image.set_pixel(x + 64, y, Color(0.0, 0.0, 1.0, 1.0))
			image.set_pixel(x + 96, y, Color(1.0, 1.0, 0.0, 1.0))
	var err := image.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	if err != OK:
		failures.append("failed to create sheet PNG fixture")


func _cleanup_generated_files() -> void:
	for path in [SHEET_PATH, OUTPUT_PATH, DEFAULT_OUTPUT_PATH, MIXED_OUTPUT_PATH, FAILED_OUTPUT_PATH, BROKEN_SHEET_PATH, SCENE_PATH]:
		_cleanup_path(path)


func _cleanup_path(resource_path: String) -> void:
	for suffix in ["", ".uid", ".import"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path + suffix))


func _assert_ok(failures: Array[String], response: Dictionary, message: String) -> void:
	if not bool(response.get("ok", false)):
		failures.append("%s: %s" % [message, str(response.get("error", "missing error"))])


func _assert_error_contains(failures: Array[String], response: Dictionary, expected_text: String, message: String) -> void:
	if bool(response.get("ok", false)):
		failures.append("%s: expected an error response" % message)
		return
	if not str(response.get("error", "")).contains(expected_text):
		failures.append("%s: expected error containing %s, got %s" % [message, expected_text, str(response.get("error", ""))])


func _assert_true(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _assert_eq(failures: Array[String], actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func _assert_close(failures: Array[String], actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
