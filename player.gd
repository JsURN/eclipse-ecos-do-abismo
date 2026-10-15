extends CharacterBody2D

const PixelActor = preload("res://pixel_actor.gd")

signal health_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int)
signal leveled_up(new_level: int)
signal died

var game: Node
var room_bounds: Rect2 = Rect2(72, 104, 1008, 470)
var speed: float = 110.0
var max_health: float = 100.0
var health: float = 100.0
var level: int = 1
var experience: int = 0
var experience_to_next: int = 5
var attack_damage: float = 18.0
var attack_cooldown: float = 0.0
var invulnerability: float = 0.0
var last_direction: Vector2 = Vector2.RIGHT
var visual: PixelActor
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var attack_visual_timer: float = 0.0
var trail_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 5.0
	collider.shape = shape
	add_child(collider)
	visual = PixelActor.new()
	visual.configure("kael")
	add_child(visual)
	var light: PointLight2D = PointLight2D.new()
	light.texture = game.dungeon._glow_texture()
	light.texture_scale = 1.5
	light.position = Vector2(0, -10)
	light.color = Color("b8cde8")
	light.energy = 0.55
	add_child(light)

func _physics_process(delta: float) -> void:
	if health <= 0.0 or game.game_finished:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_visual_timer = maxf(0.0, attack_visual_timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.01:
		last_direction = input_vector.normalized()
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		dash_direction = input_vector.normalized() if input_vector != Vector2.ZERO else last_direction
		dash_timer = 0.16
		dash_cooldown = 0.9
		invulnerability = maxf(invulnerability, 0.22)
	velocity = input_vector * speed
	if dash_timer > 0.0:
		velocity = dash_direction * 340.0
		trail_timer -= delta
		if trail_timer <= 0.0:
			trail_timer = 0.045
			var texture: Texture2D = visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
			game.dash_echo(position, texture, visual.flip_h, dash_direction)
	move_and_slide()
	if Input.is_action_pressed("attack") and attack_cooldown <= 0.0:
		attack()
	var state: String = "walk" if input_vector != Vector2.ZERO else "idle"
	if attack_visual_timer > 0.0: state = "attack"
	if dash_timer > 0.0: state = "dash"
	if invulnerability > 0.3: state = "hurt"
	visual.show_state(state, last_direction)
	visual.modulate = Color("ffffff") if invulnerability <= 0.0 else Color(1.4, 1.0, 1.2)

func attack() -> void:
	attack_cooldown = 0.22
	attack_visual_timer = 0.18
	var aim: Vector2 = last_direction
	var mouse_direction: Vector2 = get_global_mouse_position() - global_position
	if mouse_direction.length_squared() > 16.0:
		aim = mouse_direction.normalized()
	last_direction = aim
	visual.restart_attack(aim)
	game.spawn_projectile(global_position + aim * 8.0, aim, attack_damage)
	game.effect(global_position + aim * 8.0, Color("b7f6ee"), "attack", aim)

func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or health <= 0.0 or game.game_finished:
		return
	invulnerability = 0.55
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	game.effect(position, Color("ff947f"), "hurt")
	game.damage_number(position, amount, true)
	if health <= 0.0:
		visual.show_state("death", last_direction)
		died.emit()

func gain_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = 5 + level * 3
		max_health += 12.0
		health = max_health
		attack_damage += 4.0
		leveled_up.emit(level)
	experience_changed.emit(experience, experience_to_next)
	health_changed.emit(health, max_health)

func reset_for_room() -> void:
	health = minf(max_health, health + 10.0)
	attack_cooldown = 0.0
	health_changed.emit(health, max_health)

func _draw() -> void:
	draw_set_transform(Vector2(0,1),0,Vector2(1,0.35))
	draw_circle(Vector2.ZERO,9.0,Color("080e1970"))
