extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var script := load("res://tests/test_sprite_frames_from_manifest.gd")
	if script == null:
		push_error("failed to load editor integration suite")
		quit(1)
		return

	var suite = script.new()
	if not suite.has_method("run_editor_integration"):
		push_error("editor integration suite is missing run_editor_integration()")
		quit(1)
		return

	var failures: Array = await suite.run_editor_integration(self)
	if failures.is_empty():
		print("editor integration tests passed")
		quit(0)
		return

	for failure in failures:
		push_error("res://tests/test_sprite_frames_from_manifest.gd: %s" % str(failure))
	quit(1)
