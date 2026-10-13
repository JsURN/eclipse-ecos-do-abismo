extends AnimatedSprite2D
## Shared frame layout: four 24px frames, six animation rows.

func configure(texture: Texture2D) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(0, -7)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var states: Array[String] = ["idle", "walk", "attack", "dash", "hurt", "death"]
	for row in range(states.size()):
		var state: String = states[row]
		frames.add_animation(state)
		frames.set_animation_speed(state, 8.0 if state == "idle" else 12.0)
		frames.set_animation_loop(state, state == "idle" or state == "walk")
		for frame in range(4):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame * 24, row * 24, 24, 24)
			frames.add_frame(state, atlas)
	sprite_frames = frames
	play("idle")

func show_state(state: String, direction: Vector2) -> void:
	if absf(direction.x) > 0.1:
		flip_h = direction.x < 0.0
	if animation != state:
		play(state)
