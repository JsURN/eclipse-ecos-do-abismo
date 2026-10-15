extends RefCounted
## Runtime assets come exclusively from the mapped conceptual sheets.
static var manifest: Dictionary = {}
static var frame_cache: Dictionary = {}

static func actor_frames(key: String) -> SpriteFrames:
	if frame_cache.has(key): return frame_cache[key]
	if manifest.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/concept_manifest.json"))
		assert(parsed is Dictionary, "Invalid concept asset manifest")
		manifest = parsed
	var data: Dictionary = manifest["actors"][key]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	for state in data["animations"]:
		frames.add_animation(state)
		frames.set_animation_speed(state,float(data["fps"][state]))
		frames.set_animation_loop(state,String(state).begins_with("idle") or String(state).begins_with("walk"))
		for path in data["animations"][state]:
			var texture: Texture2D = load(String(path)) as Texture2D
			assert(texture != null, "Missing extracted sprite: " + String(path))
			frames.add_frame(state,texture)
	frame_cache[key] = frames
	return frames
