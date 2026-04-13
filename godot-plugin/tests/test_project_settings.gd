extends RefCounted

const BridgeProjectSettings = preload("res://addons/godot_bridge/bridge_project_settings.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_read_settings_merges_keys_and_prefix_without_duplicates(failures)
	return failures


func _test_read_settings_merges_keys_and_prefix_without_duplicates(failures: Array[String]) -> void:
	var source := {
		"display/window/size/viewport_width": 1280,
		"display/window/size/viewport_height": 720,
		"input/jump": {"deadzone": 0.2},
	}
	var property_list := [
		{"name": "display/window/size/viewport_width"},
		{"name": "display/window/size/viewport_height"},
		{"name": "input/jump"},
	]
	var getter := func(key: String):
		return source.get(key)

	var settings := BridgeProjectSettings.read_settings(property_list, getter, ["input/jump"], "display/")
	var expected := {
		"display/window/size/viewport_width": 1280,
		"display/window/size/viewport_height": 720,
		"input/jump": {"deadzone": 0.2},
	}
	if settings != expected:
		failures.append("read_settings should merge explicit keys with prefix matches")
