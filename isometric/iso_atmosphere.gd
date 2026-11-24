extends Node2D
## Ambient life for the isometric Catacumbas. Purely visual: no collision, no
## gameplay state, nothing that changes what the player can see of the fight.
##  * Mist      soft ground fog pooled in some areas, under every tall element.
##  * Embers    a few sparks over each brazier / wall sconce (Y-sorted with them).
##  * Motes     slow rising glints at the altar, pedestals, chest and exit seal.
##  * Dust      sparse cyan/violet specks drifting around the camera.
##  * Vignette  screen-edge darkening on its own CanvasLayer, below the HUD.
## Budget: ~260 CPU particles in total and 1-pixel quads (no textures), so the
## pixel art stays crisp and the cost stays negligible.
const DUST_AMOUNT: int = 44
const EMBER_AMOUNT: int = 5

var world: Node2D
var camera: Node2D
var dust: CPUParticles2D
var mist_root: Node2D
var mist_patches: Array[Sprite2D] = []
var shafts: Array[Polygon2D] = []
var time: float = 0.0

## `vignette_layer` must sit below the HUD's CanvasLayer.
func setup(world_node: Node2D, camera_node: Node2D, vignette_layer: int) -> void:
	world = world_node
	camera = camera_node
	name = "Atmosphere"
	_build_mist()
	for flame: Dictionary in world.flames:
		_anchored(flame["at"], flame["offset"], _embers(flame["color"]))
	for spot: Dictionary in world.motes:
		var emitter: CPUParticles2D = _motes(spot["color"], int(spot["amount"]), float(spot["radius"]))
		emitter.position = spot["at"]
		add_child(emitter)
	for spot: Vector2 in world.shafts: _shaft(spot)
	dust = _dust()
	add_child(dust)
	_build_vignette(vignette_layer)

## Soft moonlight falling through a crack in the vault onto a point of interest:
## an additive quad (transparent at the top) plus a faint pool on the floor.
func _shaft(spot: Vector2) -> void:
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var beam: Polygon2D = Polygon2D.new()
	beam.name = "MoonShaft"
	beam.material = additive
	var top: Vector2 = spot + Vector2(-46, -230)
	beam.polygon = PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0), spot + Vector2(22, 0), spot + Vector2(-22, 0)])
	var light: Color = Color(0.55, 0.85, 0.95)
	beam.vertex_colors = PackedColorArray([Color(light, 0.0), Color(light, 0.0), Color(light, 0.11), Color(light, 0.11)])
	add_child(beam)
	shafts.append(beam)
	var pool: Sprite2D = Sprite2D.new()
	pool.texture = world._glow_texture()
	pool.material = additive
	pool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pool.scale = Vector2(0.9, 0.45)
	pool.position = spot
	pool.modulate = Color(light, 0.12)
	world.add_child(pool)
	world.move_child(pool, world.depth.get_index())
	var emitter: CPUParticles2D = _motes(Color("bff3f2"), 6, 12.0)
	emitter.position = spot - Vector2(10, 40)
	emitter.direction = Vector2(0.2, 1)
	emitter.gravity = Vector2(0.6, 2.5)
	add_child(emitter)

func _process(delta: float) -> void:
	time += delta
	if is_instance_valid(camera): dust.global_position = camera.global_position
	for i in range(shafts.size()): shafts[i].modulate.a = 0.8 + sin(time * 0.45 + i * 1.9) * 0.2
	for i in range(mist_patches.size()):
		var patch: Sprite2D = mist_patches[i]
		patch.position = patch.get_meta("home") + Vector2(sin(time * 0.11 + i * 1.7) * 14.0, cos(time * 0.08 + i) * 5.0)
		patch.modulate.a = float(patch.get_meta("alpha")) * (0.8 + sin(time * 0.3 + i) * 0.2)

# --- layers -------------------------------------------------------------------------

## Fog sprites live in their own node right under the depth layer: they tint the
## floor but never cover walls, props or actors.
func _build_mist() -> void:
	mist_root = Node2D.new()
	mist_root.name = "Mist"
	world.add_child(mist_root)
	world.move_child(mist_root, world.depth.get_index())
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for area: Dictionary in world.mist:
		var size: Vector2 = area["size"]
		for k in range(3):
			var patch: Sprite2D = Sprite2D.new()
			patch.texture = world._glow_texture()
			patch.material = material
			patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			patch.scale = Vector2(size.x, size.x * 0.5) / 64.0 * (0.7 + k * 0.2)
			var home: Vector2 = area["at"] + Vector2((k - 1) * size.x * 0.35, (k % 2) * 10.0 - 5.0)
			patch.set_meta("home", home)
			patch.set_meta("alpha", 0.09 - k * 0.015)
			patch.position = home
			patch.modulate = area["color"]
			mist_root.add_child(patch)
			mist_patches.append(patch)

## A Y-sorted holder at the flame's BASE point keeps embers in the same depth slot
## as the brazier or wall they belong to.
func _anchored(base: Vector2, offset: Vector2, emitter: CPUParticles2D) -> void:
	var holder: Node2D = Node2D.new()
	holder.name = "Embers"
	holder.position = base
	emitter.position = offset
	holder.add_child(emitter)
	world.depth.add_child(holder)

func _build_vignette(layer_index: int) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = layer_index
	add_child(layer)
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([Color(0.01, 0.01, 0.04, 0.0), Color(0.01, 0.01, 0.04, 0.0), Color(0.01, 0.01, 0.04, 0.62)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.18)
	texture.width = 128
	texture.height = 128
	var rect: TextureRect = TextureRect.new()
	rect.name = "Edges"
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)

# --- emitters -----------------------------------------------------------------------

static func _fade(ink: Color, peak: float) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color(ink, 0.0), Color(ink, peak), Color(ink, 0.0)])
	return gradient

static func _base(amount: int, lifetime: float) -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.preprocess = lifetime
	emitter.randomness = 0.6
	emitter.lifetime_randomness = 0.4
	emitter.direction = Vector2(0, -1)
	emitter.scale_amount_min = 1.0
	emitter.scale_amount_max = 1.0
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = material
	return emitter

func _embers(ink: Color) -> CPUParticles2D:
	var emitter: CPUParticles2D = _base(EMBER_AMOUNT, 1.3)
	emitter.name = "Sparks"
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = Vector2(2, 1)
	emitter.spread = 18.0
	emitter.initial_velocity_min = 7.0
	emitter.initial_velocity_max = 14.0
	emitter.gravity = Vector2(0, -6)
	emitter.color_ramp = _fade(ink, 0.95)
	return emitter

func _motes(ink: Color, amount: int, radius: float) -> CPUParticles2D:
	var emitter: CPUParticles2D = _base(amount, 3.2)
	emitter.name = "Motes"
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = Vector2(radius, radius * 0.5)
	emitter.spread = 12.0
	emitter.initial_velocity_min = 4.0
	emitter.initial_velocity_max = 9.0
	emitter.gravity = Vector2(0, -1.5)
	emitter.color_ramp = _fade(ink, 0.8)
	return emitter

func _dust() -> CPUParticles2D:
	var emitter: CPUParticles2D = _base(DUST_AMOUNT, 9.0)
	emitter.name = "Dust"
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = Vector2(230, 140)
	emitter.spread = 180.0
	emitter.initial_velocity_min = 1.0
	emitter.initial_velocity_max = 4.0
	emitter.gravity = Vector2(0, -1.2)
	emitter.color_ramp = _fade(Color.WHITE, 0.35)
	var tints: Gradient = Gradient.new()
	tints.colors = PackedColorArray([Color("65dddb"), Color("8fa6d8"), Color("b995d0")])
	tints.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	emitter.color_initial_ramp = tints
	return emitter
