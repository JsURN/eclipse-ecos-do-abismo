extends AnimatedSprite2D
## Individually extracted frames, padded around the same foot pivot (80,140).
const Art = preload("res://concept_art.gd")
var actor_key: String
## Projection applied to gameplay directions before choosing pose/flip. Identity in
## the top-down slice; the isometric prototype sets IsoMath.BASIS.
var facing_transform: Transform2D = Transform2D.IDENTITY
var up_threshold: float = -0.55

func configure(key: String) -> void:
	actor_key = key
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(0,-30)
	scale = Vector2(0.5,0.5)
	sprite_frames = Art.actor_frames(key)
	play("idle")

func show_state(state: String, direction: Vector2) -> void:
	var selected: String = state
	if facing_transform != Transform2D.IDENTITY:
		direction = facing_transform.basis_xform(direction).normalized()
	if direction.y < up_threshold and sprite_frames.has_animation(state+"_up"):
		selected = state+"_up"
	if absf(direction.x)>0.1: flip_h = direction.x<0.0
	if animation!=selected: play(selected)

func restart_attack(direction: Vector2) -> void:
	show_state("attack",direction)
	frame = 0
