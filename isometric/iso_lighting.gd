extends Node2D
## Light for the isometric Catacumbas, in three tiers that work together:
##   AMBIENT        the world CanvasModulate plus one faint mood fill per area: keeps
##                  navigation readable without lighting everything equally.
##   ARCHITECTURAL  braziers, wall sconces and candles: warm-cold fixed sources that
##                  reveal the structure. They breathe with smooth low-frequency noise
##                  (no fast blinking) and throw a dithered pool on the floor.
##   INTEREST       altar, seals, relic chest, pedestals: the brightest, slowly pulsing
##                  lights with a colour signature (cyan lunar, violet arcane, gold
##                  reward) that guide the eye.
## Floor pools are dithered 1-bit-ish sprites (nearest filter, additive) drawn under the
## depth-sorted layer, so they light the floor without blurring the pixel art.
## Cost: one PointLight2D per source (as before) + static pool sprites; per frame only
## a noise lookup per flickering light.
enum Tier { AMBIENT, ARCHITECTURAL, INTEREST }
const CYAN: Color = Color("71cfdf")
const VIOLET: Color = Color("9674d6")
const GOLD: Color = Color("e0bf7a")

var glow_texture: Texture2D
var pool_texture: ImageTexture
var pool_material: CanvasItemMaterial
var pools: Node2D
var noise: FastNoiseLite
var flickering: Array[PointLight2D] = []
var pulsing: Array[PointLight2D] = []
## Sprites with frame animation (flames, candles).
var animated: Array[Sprite2D] = []
var time: float = 0.0

func _init() -> void:
	name = "Lights"
	noise = FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.9
	pool_texture = _pool_texture()

## `floor_holder` must be drawn after the floor and before the depth-sorted layer.
func setup(glow: Texture2D, floor_holder: Node2D) -> void:
	glow_texture = glow
	pools = floor_holder

func add(at: Vector2, ink: Color, energy: float, radius_scale: float, tier: int = Tier.AMBIENT) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.position = at
	light.texture = glow_texture
	light.texture_scale = radius_scale
	light.color = ink
	light.energy = energy
	light.set_meta("base", energy)
	light.set_meta("tier", tier)
	light.set_meta("phase", float(flickering.size() + pulsing.size()) * 37.0)
	add_child(light)
	if tier == Tier.ARCHITECTURAL: flickering.append(light)
	elif tier == Tier.INTEREST: pulsing.append(light)
	return light

## Dithered light pool on the floor, centred on a screen point (2:1 ellipse).
func add_pool(at: Vector2, ink: Color, width: float, strength: float) -> Sprite2D:
	var pool: Sprite2D = Sprite2D.new()
	pool.name = "LightPool"
	pool.texture = pool_texture
	pool.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# One shared material and texture: all pools batch into a single draw.
	if pool_material == null:
		pool_material = CanvasItemMaterial.new()
		pool_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = pool_material
	# Half-step scales keep the dither pattern crisp (whole or every-other texel).
	pool.scale = Vector2.ONE * maxf(0.5, roundf(width / 32.0) * 0.5)
	pool.position = at.round()
	pool.modulate = Color(ink, strength)
	pools.add_child(pool)
	return pool

## Animated lunar flame (4-frame strip) as a child of `holder`, its base at `base`
## (holder-local). Being a child, it sorts and fades together with its wall/brazier.
func add_flame(holder: Node2D, base: Vector2, large: bool) -> Sprite2D:
	var flame: Sprite2D = Sprite2D.new()
	flame.name = "Flame"
	flame.texture = load("res://assets/isometric/catacombs/%s.png" % ("flame_large" if large else "flame_small"))
	flame.hframes = 4
	flame.centered = false
	var size: Vector2 = Vector2(flame.texture.get_width() / 4.0, flame.texture.get_height())
	flame.offset = Vector2(-floorf(size.x * 0.5), -size.y)
	flame.position = base
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(flame)
	animate(flame, 4, 7.0 if large else 8.0)
	return flame

## Cycles a sprite's frames at `fps`, with a per-sprite phase and slightly irregular
## timing so neighbouring flames never move in lockstep.
func animate(sprite: Sprite2D, frames: int, fps: float) -> void:
	var index: int = animated.size()
	sprite.set_meta("anim", [frames, fps * (0.85 + float(index * 37 % 30) / 100.0), float(index) * 0.61])
	animated.append(sprite)

func _process(delta: float) -> void:
	time += delta
	for sprite in animated:
		var anim: Array = sprite.get_meta("anim")
		var frame: int = int(time * float(anim[1]) + float(anim[2])) % int(anim[0])
		if sprite.frame != frame: sprite.frame = frame
	for light in flickering:
		var phase: float = float(light.get_meta("phase"))
		# Two octaves of smooth noise: slow breathing plus a gentle shimmer (<= ±9 %).
		var breath: float = noise.get_noise_1d(time * 0.9 + phase) * 0.06 + noise.get_noise_1d(time * 2.6 + phase * 3.0) * 0.03
		light.energy = float(light.get_meta("base")) * (1.0 + breath)
	for light in pulsing:
		if light.has_meta("still"): continue
		var phase_p: float = float(light.get_meta("phase"))
		light.energy = float(light.get_meta("base")) * (1.0 + sin(time * 1.5 + phase_p) * 0.12)

## 64x32 ellipse, alpha quantised to 4 levels with a 4x4 Bayer matrix (pixel-art dither).
static func _pool_texture() -> ImageTexture:
	var bayer: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var image: Image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(64):
			var d: float = Vector2((x + 0.5 - 32.0) / 32.0, (y + 0.5 - 16.0) / 16.0).length()
			var level: float = clampf(1.0 - d, 0.0, 1.0) * 4.0
			var base: float = floorf(level)
			if level - base > (bayer[(y % 4) * 4 + x % 4] + 0.5) / 16.0: base += 1.0
			image.set_pixel(x, y, Color(1, 1, 1, base / 4.0))
	return ImageTexture.create_from_image(image)
