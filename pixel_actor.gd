extends AnimatedSprite2D
## Individually extracted frames, padded around the same foot pivot (80,140).
const Art = preload("res://concept_art.gd")
var actor_key: String

func configure(key: String) -> void:
	actor_key = key
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2(0,-30)
	scale = Vector2(0.5,0.5)
	sprite_frames = Art.actor_frames(key)
	play("idle")

func show_state(state: String, direction: Vector2) -> void:
	var selected: String = state
	if direction.y < -0.55 and sprite_frames.has_animation(state+"_up"):
		selected = state+"_up"
	if absf(direction.x)>0.1: flip_h = direction.x<0.0
	if animation!=selected: play(selected)

func restart_attack(direction: Vector2) -> void:
	show_state("attack",direction)
	frame = 0
