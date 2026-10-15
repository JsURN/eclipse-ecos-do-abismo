extends StaticBody2D
var amount: float = 0.0
var gate_tween: Tween
var open_art: Sprite2D
var closed_art: Sprite2D

func _ready() -> void:
	z_index = 2
	open_art = _sprite(0)
	closed_art = _sprite(1)
	closed_art.modulate.a = 0.0

func _sprite(frame: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = preload("res://assets/environments/props/doors.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame*128,0,128,128)
	sprite.scale = Vector2(0.5,0.5)
	sprite.rotation = PI/2.0
	add_child(sprite)
	return sprite

func set_closed(closed: bool) -> void:
	if gate_tween and gate_tween.is_running(): gate_tween.kill()
	gate_tween = create_tween()
	gate_tween.tween_property(self, "amount", 1.0 if closed else 0.0, 0.35)

func _process(_delta: float) -> void:
	open_art.modulate.a = 1.0-amount
	closed_art.modulate.a = amount
