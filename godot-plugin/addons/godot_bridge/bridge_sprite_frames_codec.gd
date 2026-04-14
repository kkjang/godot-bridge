@tool
class_name BridgeSpriteFramesCodec
extends RefCounted


static func sprite_frames_detail(sprite_frames: SpriteFrames) -> Dictionary:
	var animations := []
	for animation_name in sprite_frames.get_animation_names():
		var name := str(animation_name)
		var frames := []
		for index in range(sprite_frames.get_frame_count(name)):
			frames.append(_frame_detail(sprite_frames, name, index))
		animations.append({
			"name": name,
			"speed": sprite_frames.get_animation_speed(name),
			"loop": sprite_frames.get_animation_loop(name),
			"frames": frames,
		})
	return {"animations": animations}


static func build_sprite_frames(spec: Dictionary) -> Dictionary:
	var sprite_frames := SpriteFrames.new()
	return _apply_animation_specs(sprite_frames, spec, true)


static func apply_sprite_frames_changes(existing: SpriteFrames, spec: Dictionary, mode: String = "merge") -> Dictionary:
	var normalized_mode := mode.to_lower()
	if existing == null:
		return {"error": "SpriteFrames resource is missing"}
	var sprite_frames := SpriteFrames.new() if normalized_mode == "replace" else existing.duplicate(true) as SpriteFrames
	if sprite_frames == null:
		return {"error": "failed to duplicate SpriteFrames resource"}
	return _apply_animation_specs(sprite_frames, spec, normalized_mode == "replace")


static func _apply_animation_specs(sprite_frames: SpriteFrames, spec: Dictionary, clear_existing: bool) -> Dictionary:
	var raw_animations = spec.get("animations", [])
	if not (raw_animations is Array):
		return {"error": "'animations' must be an array"}

	if clear_existing:
		for existing_name in sprite_frames.get_animation_names():
			sprite_frames.remove_animation(existing_name)

	for raw_animation in raw_animations:
		if not (raw_animation is Dictionary):
			return {"error": "animation entries must be objects"}
		var animation_spec := raw_animation as Dictionary
		var animation_name := str(animation_spec.get("name", ""))
		if animation_name.is_empty():
			return {"error": "animation is missing 'name'"}

		if sprite_frames.has_animation(animation_name):
			sprite_frames.remove_animation(animation_name)
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, float(animation_spec.get("speed", 5.0)))
		sprite_frames.set_animation_loop(animation_name, bool(animation_spec.get("loop", true)))

		var raw_frames = animation_spec.get("frames", [])
		if not (raw_frames is Array):
			return {"error": "animation '%s' has non-array 'frames'" % animation_name}
		for raw_frame in raw_frames:
			if not (raw_frame is Dictionary):
				return {"error": "animation '%s' frame entries must be objects" % animation_name}
			var frame_result := _build_frame(raw_frame as Dictionary)
			if frame_result.has("error"):
				return frame_result
			sprite_frames.add_frame(animation_name, frame_result["texture"], float((raw_frame as Dictionary).get("duration", 1.0)))

	return {"sprite_frames": sprite_frames}


static func _build_frame(frame_spec: Dictionary) -> Dictionary:
	var texture_path := str(frame_spec.get("texture", ""))
	if texture_path.is_empty():
		return {"error": "frame is missing 'texture'"}
	var texture := load(texture_path)
	if not (texture is Texture2D):
		return {"error": "could not load Texture2D: %s" % texture_path}

	if not frame_spec.has("region"):
		return {"texture": texture}

	var region_value = frame_spec.get("region")
	if not (region_value is Dictionary):
		return {"error": "frame 'region' must be an object"}
	var region_spec := region_value as Dictionary
	if not region_spec.has("x") or not region_spec.has("y") or not region_spec.has("w") or not region_spec.has("h"):
		return {"error": "frame 'region' must include x, y, w, and h"}

	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		float(region_spec.get("x", 0.0)),
		float(region_spec.get("y", 0.0)),
		float(region_spec.get("w", 0.0)),
		float(region_spec.get("h", 0.0))
	)
	return {"texture": atlas}


static func _frame_detail(sprite_frames: SpriteFrames, animation_name: String, index: int) -> Dictionary:
	var texture := sprite_frames.get_frame_texture(animation_name, index)
	var detail := {
		"texture": _texture_path(texture),
		"duration": sprite_frames.get_frame_duration(animation_name, index),
	}
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		var region := atlas_texture.region
		detail["region"] = {
			"x": region.position.x,
			"y": region.position.y,
			"w": region.size.x,
			"h": region.size.y,
		}
	return detail


static func _texture_path(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		if atlas != null:
			return atlas.resource_path
	if texture == null:
		return ""
	return texture.resource_path
