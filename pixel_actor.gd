extends AnimatedSprite2D
## Six 32px frames per state; large silhouettes without scaling the hitboxes.
const FRAME_SIZE: int = 32
const FRAME_COUNT: int = 6

func configure(texture: Texture2D) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(0, -12)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var states: Array[String] = ["idle", "walk", "attack", "dash", "hurt", "death"]
	for row in range(states.size()):
		var state: String = states[row]
		frames.add_animation(state)
		var fps: float = 6.0
		if state == "walk": fps = 10.0
		if state == "attack": fps = 28.0
		if state == "dash" or state == "hurt": fps = 24.0
		if state == "death": fps = 15.0
		frames.set_animation_speed(state, fps)
		frames.set_animation_loop(state, state == "idle" or state == "walk")
		for frame in range(FRAME_COUNT):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(state, atlas)
	sprite_frames = frames
	play("idle")

func show_state(state: String, direction: Vector2) -> void:
	if absf(direction.x) > 0.1:
		flip_h = direction.x < 0.0
	if animation != state:
		play(state)

func restart_attack(direction: Vector2) -> void:
	show_state("attack", direction)
	frame = 0
