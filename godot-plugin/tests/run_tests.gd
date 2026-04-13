extends SceneTree

const TEST_FILES := [
	"res://tests/test_debug_state.gd",
	"res://tests/test_project_settings.gd",
	"res://tests/test_animation_codec.gd",
]


func _init() -> void:
	var failures := []
	for path in TEST_FILES:
		var script := load(path)
		if script == null:
			failures.append("failed to load test script: " + path)
			continue
		var suite = script.new()
		if not suite.has_method("run"):
			failures.append("test suite is missing run(): " + path)
			continue
		var suite_failures: Array = suite.run()
		for failure in suite_failures:
			failures.append("%s: %s" % [path, str(failure)])

	if failures.is_empty():
		print("plugin tests passed")
		quit(0)
		return

	for failure in failures:
		push_error(str(failure))
	quit(1)
