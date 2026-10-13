extends CharacterBody2D

const PixelActor = preload("res://pixel_actor.gd")
signal died(enemy: Node2D, experience: int)

var target: CharacterBody2D
var game: Node
var enemy_type: String = "shade"
var speed: float = 44.0
var max_health: float = 32.0
var health: float = 32.0
var contact_damage: float = 8.0
var experience_value: int = 2
var hit_flash: float = 0.0
var damage_timer: float = 0.0
var shot_timer: float = 1.6
var navigation_timer: float = 0.0
var travel: Vector2 = Vector2.ZERO
var visual: PixelActor
var dying: bool = false

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var collider: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	collider.shape = circle
	add_child(collider)
	var texture: Texture2D = preload("res://assets/crawler.png")
	match enemy_type:
		"stalker":
			texture = preload("res://assets/archer.png")
			speed = 38.0
			max_health = 24.0
			contact_damage = 11.0
			experience_value = 3
		"brute":
			texture = preload("res://assets/guardian.png")
			speed = 28.0
			max_health = 78.0
			contact_damage = 18.0
			experience_value = 5
	health = max_health
	visual = PixelActor.new()
	visual.configure(texture)
	add_child(visual)

func _physics_process(delta: float) -> void:
	if dying or game.game_finished: return
	damage_timer = maxf(0.0, damage_timer - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	shot_timer -= delta
	navigation_timer -= delta
	if not is_instance_valid(target) or target.health <= 0.0: return
	var distance: float = position.distance_to(target.position)
	var direction: Vector2 = position.direction_to(target.position)
	if navigation_timer <= 0.0:
		navigation_timer = 0.2
		travel = game.dungeon.path_direction(position, target.position)
	velocity = travel * speed
	if enemy_type == "stalker" and distance < 136.0 and _can_see_target():
		velocity = -direction * speed if distance < 56.0 else Vector2.ZERO
		if shot_timer <= 0.0:
			shot_timer = 1.6
			game.spawn_projectile(position + direction * 9.0, direction, 10.0, true)
			game.effect(position, Color("927aa9"), "attack", direction)
	move_and_slide()
	if distance < 14.0 and damage_timer <= 0.0:
		damage_timer = 0.75
		target.take_damage(contact_damage)
	visual.show_state("hurt" if hit_flash > 0.0 else ("walk" if velocity.length() > 1.0 else "idle"), direction)
	visual.modulate = Color(1.8, 1.8, 1.8) if hit_flash > 0.0 else Color.WHITE
	queue_redraw()

func _can_see_target() -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(position, target.position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: float) -> void:
	if dying or game.game_finished: return
	health -= amount
	hit_flash = 0.13
	game.effect(position, Color("b7f6ee"), "impact")
	game.damage_number(position, amount)
	if health <= 0.0:
		dying = true
		remove_from_group("enemies")
		visual.show_state("death", Vector2.RIGHT)
		game.effect(position, Color("b995d0"), "death")
		died.emit(self, experience_value)
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	queue_redraw()

func _draw() -> void:
	if health < max_health and not dying:
		draw_rect(Rect2(-10, -31, 20, 3), Color("080e19"))
		draw_rect(Rect2(-9, -30, maxf(0, 18 * health / max_health), 1), Color("ff947f"))
