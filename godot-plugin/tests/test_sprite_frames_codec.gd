extends RefCounted

const BridgeSpriteFramesCodec = preload("res://addons/godot_bridge/bridge_sprite_frames_codec.gd")

const TEST_TEXTURE_PATH := "res://tests/fixtures/test_texture.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	_ensure_test_texture(failures)
	_test_build_sprite_frames_builds_animations_and_regions(failures)
	_test_apply_sprite_frames_changes_merges_by_name(failures)
	_test_apply_sprite_frames_changes_replace_overwrites_all(failures)
	return failures


func _ensure_test_texture(failures: Array[String]) -> void:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var err := ResourceSaver.save(texture, TEST_TEXTURE_PATH)
	if err != OK:
		failures.append("failed to save test texture resource")


func _test_build_sprite_frames_builds_animations_and_regions(failures: Array[String]) -> void:
	var result := BridgeSpriteFramesCodec.build_sprite_frames({
		"animations": [
			{
				"name": "idle",
				"speed": 6,
				"loop": true,
				"frames": [
					{"texture": TEST_TEXTURE_PATH, "region": {"x": 1, "y": 2, "w": 3, "h": 4}, "duration": 1.5}
				],
			}
		],
	})
	if result.has("error"):
		failures.append("build_sprite_frames should accept valid animation data")
		return

	var sprite_frames := result.get("sprite_frames") as SpriteFrames
	if sprite_frames == null:
		failures.append("build_sprite_frames should return a SpriteFrames resource")
		return
	if not sprite_frames.has_animation("idle"):
		failures.append("build_sprite_frames should create named animations")
		return
	if sprite_frames.get_animation_speed("idle") != 6.0:
		failures.append("build_sprite_frames should set animation speed")
	if not sprite_frames.get_animation_loop("idle"):
		failures.append("build_sprite_frames should set animation loop")
	if sprite_frames.get_frame_count("idle") != 1:
		failures.append("build_sprite_frames should add frame data")
	var frame_texture := sprite_frames.get_frame_texture("idle", 0)
	if not (frame_texture is AtlasTexture):
		failures.append("build_sprite_frames should wrap region frames in AtlasTexture")
	else:
		_assert_eq(failures, frame_texture.atlas.resource_path, TEST_TEXTURE_PATH, "AtlasTexture should load the source texture path")
		_assert_eq(failures, frame_texture.region, Rect2(1, 2, 3, 4), "AtlasTexture should keep the requested region")
	_assert_eq(failures, sprite_frames.get_frame_duration("idle", 0), 1.5, "build_sprite_frames should set frame duration")


func _test_apply_sprite_frames_changes_merges_by_name(failures: Array[String]) -> void:
	var original_result := BridgeSpriteFramesCodec.build_sprite_frames({
		"animations": [
			{"name": "idle", "speed": 4, "loop": true, "frames": [{"texture": TEST_TEXTURE_PATH}]},
			{"name": "walk", "speed": 8, "loop": true, "frames": [{"texture": TEST_TEXTURE_PATH, "duration": 2.0}]},
		],
	})
	var updated_result := BridgeSpriteFramesCodec.apply_sprite_frames_changes(original_result.get("sprite_frames") as SpriteFrames, {
		"animations": [
			{"name": "walk", "speed": 12, "loop": false, "frames": [{"texture": TEST_TEXTURE_PATH, "duration": 3.0}]}
		]
	}, "merge")
	if updated_result.has("error"):
		failures.append("apply_sprite_frames_changes merge should accept valid data")
		return
	var updated := updated_result.get("sprite_frames") as SpriteFrames
	if updated == null:
		failures.append("apply_sprite_frames_changes merge should return a SpriteFrames resource")
		return
	if not updated.has_animation("idle"):
		failures.append("merge should preserve unrelated animations")
	if not updated.has_animation("walk"):
		failures.append("merge should keep replaced animations")
	else:
		_assert_eq(failures, updated.get_animation_speed("walk"), 12.0, "merge should replace matching animation speed")
		_assert_eq(failures, updated.get_animation_loop("walk"), false, "merge should replace matching animation loop")
		_assert_eq(failures, updated.get_frame_duration("walk", 0), 3.0, "merge should replace matching animation frames")


func _test_apply_sprite_frames_changes_replace_overwrites_all(failures: Array[String]) -> void:
	var original_result := BridgeSpriteFramesCodec.build_sprite_frames({
		"animations": [
			{"name": "idle", "frames": [{"texture": TEST_TEXTURE_PATH}]},
			{"name": "walk", "frames": [{"texture": TEST_TEXTURE_PATH}]},
		],
	})
	var updated_result := BridgeSpriteFramesCodec.apply_sprite_frames_changes(original_result.get("sprite_frames") as SpriteFrames, {
		"animations": [
			{"name": "attack", "frames": [{"texture": TEST_TEXTURE_PATH}]}
		]
	}, "replace")
	if updated_result.has("error"):
		failures.append("apply_sprite_frames_changes replace should accept valid data")
		return
	var updated := updated_result.get("sprite_frames") as SpriteFrames
	if updated == null:
		failures.append("apply_sprite_frames_changes replace should return a SpriteFrames resource")
		return
	if updated.has_animation("idle") or updated.has_animation("walk"):
		failures.append("replace should remove omitted animations")
	if not updated.has_animation("attack"):
		failures.append("replace should keep provided animations")


func _assert_eq(failures: Array[String], actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])
