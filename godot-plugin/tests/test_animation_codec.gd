extends RefCounted

const BridgeAnimationCodec = preload("res://addons/godot_bridge/bridge_animation_codec.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_build_animation_creates_value_track(failures)
	_test_build_animation_uses_bound_value_parser_arguments_in_order(failures)
	_test_apply_animation_changes_replaces_matching_tracks(failures)
	return failures


func _test_build_animation_creates_value_track(failures: Array[String]) -> void:
	var animation := BridgeAnimationCodec.build_animation({
		"name": "walk",
		"length": 1.25,
		"loop_mode": "linear",
		"tracks": [
			{"path": ".:frame", "type": "value", "keyframes": [{"time": 0.0, "value": 0}, {"time": 0.5, "value": 1}]}
		],
	}, func(_track_path: String, value):
		return value
	)

	if animation.length != 1.25:
		failures.append("build_animation should set length")
	if BridgeAnimationCodec.loop_mode_name(animation.loop_mode) != "linear":
		failures.append("build_animation should set loop mode")
	if animation.get_track_count() != 1:
		failures.append("build_animation should add one track")
	if str(animation.track_get_path(0)) != ".:frame":
		failures.append("build_animation should set the track path")
	if animation.track_get_key_count(0) != 2:
		failures.append("build_animation should insert keyframes")


func _test_build_animation_uses_bound_value_parser_arguments_in_order(failures: Array[String]) -> void:
	var animation := BridgeAnimationCodec.build_animation({
		"tracks": [
			{"path": ".:frame", "type": "value", "keyframes": [{"time": 0.0, "value": 7}]}
		],
	}, Callable(self, "_bound_value_parser").bind("marker"))

	if animation.track_get_key_count(0) != 1:
		failures.append("bound value parser should still insert keyframes")
	elif animation.track_get_key_value(0, 0) != 14:
		failures.append("bound value parser should receive track path and value before bound args")


func _test_apply_animation_changes_replaces_matching_tracks(failures: Array[String]) -> void:
	var original := BridgeAnimationCodec.build_animation({
		"length": 1.0,
		"tracks": [
			{"path": ".:frame", "type": "value", "keyframes": [{"time": 0.0, "value": 0}]},
			{"path": ".:modulate", "type": "value", "keyframes": [{"time": 0.0, "value": [1, 1, 1, 1]}]},
		],
	}, func(_track_path: String, value):
		return value
	)
	var updated := BridgeAnimationCodec.apply_animation_changes(original, {
		"length": 2.0,
		"tracks": [
			{"path": ".:frame", "type": "value", "keyframes": [{"time": 0.25, "value": 3}]}
		],
	}, func(_track_path: String, value):
		return value
	)

	if updated.length != 2.0:
		failures.append("apply_animation_changes should update length")
	if updated.get_track_count() != 2:
		failures.append("apply_animation_changes should preserve unrelated tracks")
	var frame_track := _find_track(updated, ".:frame")
	if frame_track == -1:
		failures.append("updated animation should include replacement frame track")
	elif updated.track_get_key_time(frame_track, 0) != 0.25 or updated.track_get_key_value(frame_track, 0) != 3:
		failures.append("replacement track should contain new keyframe data")


func _find_track(animation: Animation, track_path: String) -> int:
	for index in range(animation.get_track_count()):
		if str(animation.track_get_path(index)) == track_path:
			return index
	return -1


func _bound_value_parser(track_path: String, value, marker: String):
	if track_path != ".:frame" or marker != "marker":
		return -1
	return int(value) * 2
