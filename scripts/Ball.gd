extends CharacterBody2D
class_name Ball

signal ball_lost(ball: Ball)
signal brick_hit_event(brick: Node, impact_pos: Vector2, is_ghost: bool)
signal paddle_bounced

@export var base_speed: float = 690.0
@export var radius: float = 11.0

var speed: float = 690.0
var is_attached: bool = true
var is_ghost: bool = false
var ghost_timer: float = 0.0
var ghost_hit_cooldowns: Dictionary = {}
var paddle_ref: Paddle = null
var paddle_hit_cooldown: float = 0.0

@onready var trail: Line2D = $Trail

func _ready() -> void:
	var diff: Dictionary = DDAManager.get_wave_difficulty(DDAManager.current_wave, false)
	var mult: float = float(diff["speed_multiplier"])
	speed = base_speed * mult
	_apply_skin()
	GameData.skin_changed.connect(func(_id: String) -> void: _apply_skin())

func _apply_skin() -> void:
	var skin: Dictionary = GameData.get_current_skin_data()
	if trail:
		var t_col: Color = skin["trail_color"]
		trail.default_color = t_col
	queue_redraw()

func attach_to_paddle(paddle_node: Paddle) -> void:
	paddle_ref = paddle_node
	is_attached = true
	paddle_node.has_ball_attached = true
	velocity = Vector2.ZERO
	paddle_hit_cooldown = 0.0
	ghost_hit_cooldowns.clear()
	if trail:
		trail.clear_points()

func launch(dir: Vector2 = Vector2(0.28, -0.96)) -> void:
	if not is_attached:
		return
	is_attached = false
	if paddle_ref:
		paddle_ref.has_ball_attached = false
	velocity = dir.normalized() * speed

func activate_ghost(duration: float = 5.0) -> void:
	is_ghost = true
	ghost_timer = duration
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_attached and paddle_ref:
		global_position = Vector2(paddle_ref.position.x, paddle_ref.position.y - 26.0)
		return

	if paddle_hit_cooldown > 0.0:
		paddle_hit_cooldown -= delta

	if is_ghost:
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			is_ghost = false
			ghost_hit_cooldowns.clear()
			queue_redraw()

	var expired_ids: Array[int] = []
	for id_key: Variant in ghost_hit_cooldowns.keys():
		var bid: int = int(id_key)
		var rem: float = float(ghost_hit_cooldowns[bid]) - delta
		if rem <= 0.0:
			expired_ids.append(bid)
		else:
			ghost_hit_cooldowns[bid] = rem
	for eid: int in expired_ids:
		ghost_hit_cooldowns.erase(eid)

	if trail:
		trail.add_point(global_position)
		if trail.get_point_count() > 16:
			trail.remove_point(0)

	var motion: Vector2 = velocity * delta
	var collision: KinematicCollision2D = move_and_collide(motion)
	if collision:
		var collider: Object = collision.get_collider()
		var normal: Vector2 = collision.get_normal()

		if collider is Paddle:
			var pad: Paddle = collider
			var pad_top_y: float = pad.global_position.y - (pad.paddle_height * 0.5)
			var pad_bottom_y: float = pad.global_position.y + (pad.paddle_height * 0.5)

			# Top raketin altına geçmişse asla yukarı fırlatma! Sadece yan duvara çarptıysa yana sek, alttaysa düşmeye devam et
			if global_position.y > pad_bottom_y - 2.0 or normal.y > 0.35:
				global_position += velocity.normalized() * 6.0
			elif abs(normal.x) > 0.75 and global_position.y > pad_top_y + 2.0:
				# Raketin tam yan kenarına çarptıysa yana doğru sektir
				var side_sign: float = sign(global_position.x - pad.global_position.x)
				if side_sign == 0.0:
					side_sign = 1.0
				velocity = Vector2(side_sign * 0.85, max(0.35, velocity.normalized().y)).normalized() * speed
				global_position.x = pad.global_position.x + side_sign * (pad.current_width * 0.5 + radius + 3.0)
			elif velocity.y > 0.0 and paddle_hit_cooldown <= 0.0:
				# Geçerli üst yüzey sekmesi
				paddle_hit_cooldown = 0.08
				var hit_offset: float = (global_position.x - pad.position.x) / (pad.current_width * 0.5)
				hit_offset = clamp(hit_offset, -0.92, 0.92)
				var bounce_dir: Vector2 = Vector2(hit_offset * 0.85, -1.0).normalized()
				velocity = bounce_dir * speed
				global_position.y = pad_top_y - radius - 1.5
				pad.set_mood("happy", 0.55)
				AudioHapticManager.play_paddle_hit()
				emit_signal("paddle_bounced")
			else:
				global_position += velocity.normalized() * 4.0

		elif collider is Brick:
			var br: Brick = collider
			if is_ghost and br.brick_type != "UNBREAKABLE":
				var bid: int = br.get_instance_id()
				if not ghost_hit_cooldowns.has(bid):
					ghost_hit_cooldowns[bid] = 0.14
					emit_signal("brick_hit_event", br, collision.get_position(), true)
				global_position += velocity.normalized() * 8.0
			else:
				velocity = velocity.bounce(normal)
				_prevent_flat_angle()
				emit_signal("brick_hit_event", br, collision.get_position(), false)
		else:
			velocity = velocity.bounce(normal)
			_prevent_flat_angle()

	if global_position.y > 1320.0:
		emit_signal("ball_lost", self)

func _prevent_flat_angle() -> void:
	var dir: Vector2 = velocity.normalized()
	if abs(dir.y) < 0.22:
		dir.y = -0.25 if dir.y <= 0.0 else 0.25
		velocity = dir.normalized() * speed

func _draw() -> void:
	var skin: Dictionary = GameData.get_current_skin_data()
	var skin_ball_col: Color = skin["ball_color"]
	var col: Color = Color("#9AE6B4") if is_ghost else skin_ball_col
	if is_ghost:
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.6, 0.9, 0.7, 0.3))
	draw_circle(Vector2.ZERO, radius, col)
	draw_circle(Vector2(-3, -3), radius * 0.35, Color(1, 1, 1, 0.75))
