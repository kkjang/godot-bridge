@tool
class_name BridgeAnimationCodec
extends RefCounted


static func animation_summary(name: String, animation: Animation) -> Dictionary:
	return {
		"name": name,
		"length": animation.length,
		"loop_mode": loop_mode_name(animation.loop_mode),
		"track_count": animation.get_track_count(),
	}


static func animation_detail(name: String, animation: Animation, variant_to_json: Callable) -> Dictionary:
	var tracks := []
	for index in range(animation.get_track_count()):
		var keyframes := []
		for keyframe_index in range(animation.track_get_key_count(index)):
			keyframes.append({
				"time": animation.track_get_key_time(index, keyframe_index),
				"value": variant_to_json.call(animation.track_get_key_value(index, keyframe_index)),
			})
		tracks.append({
			"path": str(animation.track_get_path(index)),
			"type": track_type_name(animation.track_get_type(index)),
			"keyframes": keyframes,
		})

	return {
		"name": name,
		"length": animation.length,
		"loop_mode": loop_mode_name(animation.loop_mode),
		"tracks": tracks,
	}


static func build_animation(spec: Dictionary, value_parser: Callable) -> Animation:
	var animation := Animation.new()
	animation.length = float(spec.get("length", 1.0))
	animation.loop_mode = parse_loop_mode(str(spec.get("loop_mode", "none")))
	for track_spec in spec.get("tracks", []):
		_add_value_track(animation, track_spec as Dictionary, value_parser)
	return animation


static func apply_animation_changes(existing: Animation, spec: Dictionary, value_parser: Callable) -> Animation:
	var updated := existing.duplicate(true) as Animation
	if spec.has("length"):
		updated.length = float(spec.get("length", updated.length))
	if spec.has("loop_mode"):
		updated.loop_mode = parse_loop_mode(str(spec.get("loop_mode", loop_mode_name(updated.loop_mode))))
	if spec.has("tracks"):
		var replacements := {}
		for track_spec in spec.get("tracks", []):
			var path := str((track_spec as Dictionary).get("path", ""))
			if not path.is_empty():
				replacements[path] = track_spec

		var to_remove := []
		for index in range(updated.get_track_count()):
			var existing_path := str(updated.track_get_path(index))
			if replacements.has(existing_path):
				to_remove.append(index)
		to_remove.reverse()
		for index in to_remove:
			updated.remove_track(index)

		for track_path in replacements.keys():
			_add_value_track(updated, replacements[track_path] as Dictionary, value_parser)
	return updated


static func parse_loop_mode(name: String) -> int:
	match name.to_lower():
		"linear":
			return Animation.LOOP_LINEAR
		"pingpong":
			return Animation.LOOP_PINGPONG
		_:
			return Animation.LOOP_NONE


static func loop_mode_name(loop_mode: int) -> String:
	match loop_mode:
		Animation.LOOP_LINEAR:
			return "linear"
		Animation.LOOP_PINGPONG:
			return "pingpong"
		_:
			return "none"


static func track_type_name(track_type: int) -> String:
	match track_type:
		Animation.TYPE_VALUE:
			return "value"
		Animation.TYPE_METHOD:
			return "method"
		Animation.TYPE_BEZIER:
			return "bezier"
		Animation.TYPE_AUDIO:
			return "audio"
		Animation.TYPE_ANIMATION:
			return "animation"
		_:
			return "unknown"


static func _add_value_track(animation: Animation, track_spec: Dictionary, value_parser: Callable) -> void:
	var track_path := str(track_spec.get("path", ""))
	if track_path.is_empty():
		push_error("GodotBridge: animation track is missing a path")
		return
	var track_type := str(track_spec.get("type", "value")).to_lower()
	if track_type != "value":
		push_error("GodotBridge: only value tracks are supported in animation_new/animation_modify")
		return

	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(track_path))
	for keyframe in track_spec.get("keyframes", []):
		var keyframe_data := keyframe as Dictionary
		var time := float(keyframe_data.get("time", 0.0))
		var raw_value = keyframe_data.get("value")
		var value = value_parser.call(track_path, raw_value)
		animation.track_insert_key(index, time, value)
