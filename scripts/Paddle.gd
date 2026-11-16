extends CharacterBody2D
class_name Paddle

signal launch_requested(launch_dir: Vector2)
signal laser_fired(pos: Vector2)
signal defense_shot_fired(origin: Vector2, dir: Vector2)

@export var base_width: float = 144.0
@export var paddle_height: float = 24.0
@export var follow_smoothness: float = 22.0

var current_width: float = 144.0
var target_x: float = 360.0
var is_dragging: bool = false
var is_holding_paddle: bool = false
var has_ball_attached: bool = true
var input_enabled: bool = false
var input_lock_timer: float = 0.0

var is_defense_mode: bool = false
var turret_angle: float = -PI * 0.5
var defense_fire_cooldown: float = 0.0

var aim_angle_rad: float = -PI * 0.42
var aim_pulse_time: float = 0.0

var wide_timer: float = 0.0
var laser_timer: float = 0.0
var laser_cooldown: float = 0.0
var permanent_laser: bool = false
var laser_fire_interval: float = 0.85

var character_mood: String = "idle"
var mood_timer: float = 0.0
var look_target_x: float = 360.0

@onready var col_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	apply_meta_stats()
	target_x = position.x
	_update_collider()
	GameData.skin_changed.connect(_on_skin_changed)
	GameData.upgrades_changed.connect(apply_meta_stats)

func reset_all_states() -> void:
	is_dragging = false
	is_holding_paddle = false
	wide_timer = 0.0
	laser_timer = 0.0
	laser_cooldown = 0.0
	permanent_laser = false
	laser_fire_interval = 0.85
	defense_fire_cooldown = 0.0
	character_mood = "idle"
	mood_timer = 0.0
	aim_angle_rad = -PI * 0.42
	apply_meta_stats()
	queue_redraw()

func set_input_active(active: bool, lock_delay: float = 0.18) -> void:
	input_enabled = active
	is_dragging = false
	is_holding_paddle = false
	if active:
		input_lock_timer = lock_delay
	else:
		input_lock_timer = 0.0

func apply_meta_stats(extra_bonus_w: float = 0.0) -> void:
	var size_lvl: int = int(GameData.meta_upgrades.get("paddle_size", 1))
	var raw_w: float = 144.0 + float(size_lvl - 1) * 9.0 + extra_bonus_w
	base_width = clamp(raw_w, 68.0, 260.0)
	if wide_timer <= 0.0 and not is_defense_mode:
		current_width = base_width
		_update_collider()

func set_defense_mode(active: bool) -> void:
	is_defense_mode = active
	is_dragging = false
	is_holding_paddle = false
	if active:
		has_ball_attached = false
		position = Vector2(360.0, 640.0)
		target_x = 360.0
		current_width = 92.0
		_update_collider()
	else:
		position = Vector2(360.0, 1110.0)
		target_x = 360.0
		apply_meta_stats()
	queue_redraw()

func _on_skin_changed(_id: String) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or input_lock_timer > 0.0 or get_tree().paused:
		is_holding_paddle = false
		return

	if is_defense_mode:
		var click_pos: Vector2 = Vector2.ZERO
		var fired: bool = false
		if event is InputEventScreenTouch:
			var te: InputEventScreenTouch = event
			if te.pressed and te.position.y > 125.0:
				click_pos = te.position
				fired = true
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.position.y > 125.0:
				click_pos = mb.position
				fired = true

		if fired and defense_fire_cooldown <= 0.0:
			var dir: Vector2 = (click_pos - global_position).normalized()
			if dir.length() < 0.1:
				dir = Vector2.UP
			turret_angle = dir.angle()
			var rate_lvl: int = int(GameData.meta_upgrades.get("fire_rate", 1))
			defense_fire_cooldown = max(0.11, 0.28 - float(rate_lvl - 1) * 0.018)
			AudioHapticManager.play_turret_shot()
			emit_signal("defense_shot_fired", global_position + dir * 32.0, dir)
			queue_redraw()
		return

	if event is InputEventScreenTouch:
		var touch_ev: InputEventScreenTouch = event
		if touch_ev.pressed:
			if touch_ev.position.y < 125.0:
				return
			is_dragging = true
			is_holding_paddle = true
			_handle_pointer_input(touch_ev.position)
		else:
			if is_dragging and has_ball_attached:
				emit_signal("launch_requested", get_aim_direction())
			is_dragging = false
			is_holding_paddle = false

	elif event is InputEventScreenDrag:
		var drag_ev: InputEventScreenDrag = event
		if is_dragging:
			is_holding_paddle = true
			_handle_pointer_input(drag_ev.position)

	elif event is InputEventMouseButton:
		var mb_ev: InputEventMouseButton = event
		if mb_ev.button_index == MOUSE_BUTTON_LEFT:
			if mb_ev.pressed:
				if mb_ev.position.y < 125.0:
					return
				is_dragging = true
				is_holding_paddle = true
				_handle_pointer_input(mb_ev.position)
			else:
				if is_dragging and has_ball_attached:
					emit_signal("launch_requested", get_aim_direction())
				is_dragging = false
				is_holding_paddle = false

	elif event is InputEventMouseMotion and is_dragging:
		var mm_ev: InputEventMouseMotion = event
		is_holding_paddle = true
		_handle_pointer_input(mm_ev.position)

func _handle_pointer_input(pointer_pos: Vector2) -> void:
	if has_ball_attached:
		var ball_origin: Vector2 = Vector2(position.x, position.y - 26.0)
		var vec: Vector2 = pointer_pos - ball_origin
		if vec.y < -25.0:
			var raw_angle: float = vec.angle()
			aim_angle_rad = clamp(raw_angle, deg_to_rad(-155.0), deg_to_rad(-25.0))
		else:
			target_x = pointer_pos.x
			var norm_x: float = clamp((pointer_pos.x - 360.0) / 300.0, -1.0, 1.0)
			aim_angle_rad = deg_to_rad(-90.0 + norm_x * 58.0)
	else:
		target_x = pointer_pos.x

func get_aim_direction() -> Vector2:
	return Vector2.from_angle(aim_angle_rad).normalized()

func _process(delta: float) -> void:
	if input_lock_timer > 0.0:
		input_lock_timer -= delta

	if not input_enabled:
		queue_redraw()
		return

	aim_pulse_time += delta * 4.5
	if defense_fire_cooldown > 0.0:
		defense_fire_cooldown -= delta

	if not is_defense_mode:
		var half_w: float = current_width * 0.5
		var clamped_target: float = clamp(target_x, half_w + 18.0, 720.0 - half_w - 18.0)
		var unscaled_dt: float = delta / max(Engine.time_scale, 0.1)
		position.x = lerp(position.x, clamped_target, clamp(follow_smoothness * unscaled_dt, 0.0, 1.0))

		if wide_timer > 0.0:
			wide_timer -= delta
			if wide_timer <= 0.0:
				_set_width_smooth(base_width)

		var has_laser_active: bool = (laser_timer > 0.0 or permanent_laser)
		if laser_timer > 0.0:
			laser_timer -= delta
		if has_laser_active:
			laser_cooldown -= delta
			if laser_cooldown <= 0.0:
				laser_cooldown = laser_fire_interval
				emit_signal("laser_fired", Vector2(position.x - half_w + 14.0, position.y - 16.0))
				emit_signal("laser_fired", Vector2(position.x + half_w - 14.0, position.y - 16.0))

	if mood_timer > 0.0:
		mood_timer -= delta
		if mood_timer <= 0.0:
			character_mood = "idle"

	queue_redraw()

func activate_wide(duration: float = 10.0) -> void:
	wide_timer = duration
	_set_width_smooth(base_width * 1.4)

func activate_laser(duration: float = 8.0) -> void:
	laser_timer = duration
	laser_cooldown = 0.05

func set_mood(mood: String, duration: float = 0.8) -> void:
	character_mood = mood
	mood_timer = duration

func _set_width_smooth(new_w: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(func(val: float) -> void:
		current_width = val
		_update_collider()
	, current_width, new_w, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_collider() -> void:
	if col_shape and col_shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = col_shape.shape
		if is_defense_mode:
			rect_shape.size = Vector2(72.0, 72.0)
		else:
			rect_shape.size = Vector2(current_width, paddle_height)

func _draw() -> void:
	var skin: Dictionary = GameData.get_current_skin_data()
	var main_col: Color = skin["paddle_color"]
	var accent_col: Color = skin["accent_color"]

	if is_defense_mode:
		draw_circle(Vector2.ZERO, 44.0, Color(main_col.r, main_col.g, main_col.b, 0.22))
		draw_circle(Vector2.ZERO, 34.0, main_col)
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, accent_col, 3.0)
		var barrel_end: Vector2 = Vector2.from_angle(turret_angle) * 44.0
		draw_line(Vector2.ZERO, barrel_end, accent_col, 10.0, true)
		draw_circle(Vector2.ZERO, 16.0, Color(0.1, 0.13, 0.18))
		var eye_dir: Vector2 = Vector2.from_angle(turret_angle) * 3.5
		draw_circle(Vector2(-4, -1) + eye_dir, 2.6, accent_col)
		draw_circle(Vector2(4, -1) + eye_dir, 2.6, accent_col)
		return

	var half_w: float = current_width * 0.5
	var half_h: float = paddle_height * 0.5

	if has_ball_attached and input_enabled:
		_draw_aim_trajectory(skin["ball_color"])

	var rect: Rect2 = Rect2(-half_w, -half_h, current_width, paddle_height)
	draw_rect(rect, main_col, true)
	draw_rect(Rect2(-half_w + 6, -half_h + 3, current_width - 12, 5), accent_col, true)

	if (laser_timer > 0.0 or permanent_laser) and input_enabled:
		draw_rect(Rect2(-half_w + 4, -half_h - 8, 10, 8), Color("#F56565"), true)
		draw_rect(Rect2(half_w - 14, -half_h - 8, 10, 8), Color("#F56565"), true)

	var char_y: float = -half_h - 14.0
	draw_circle(Vector2(0, char_y), 14.0, main_col)
	draw_circle(Vector2(0, char_y), 11.0, Color(0.1, 0.13, 0.18))
	var eye_offset_x: float = clamp((look_target_x - position.x) * 0.015, -3.5, 3.5)
	if has_ball_attached:
		eye_offset_x = cos(aim_angle_rad) * 3.5

	if character_mood == "happy":
		draw_arc(Vector2(-4 + eye_offset_x, char_y - 1), 3.0, PI, TAU, 8, accent_col, 2.0)
		draw_arc(Vector2(4 + eye_offset_x, char_y - 1), 3.0, PI, TAU, 8, accent_col, 2.0)
	elif character_mood == "shocked":
		draw_circle(Vector2(-4 + eye_offset_x, char_y - 1), 3.2, Color("#FEB2B2"))
		draw_circle(Vector2(4 + eye_offset_x, char_y - 1), 3.2, Color("#FEB2B2"))
	else:
		draw_circle(Vector2(-4 + eye_offset_x, char_y - 1), 2.4, accent_col)
		draw_circle(Vector2(4 + eye_offset_x, char_y - 1), 2.4, accent_col)

func _draw_aim_trajectory(dot_color: Color) -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return

	var current_origin: Vector2 = global_position + Vector2(0, -26.0)
	var current_dir: Vector2 = get_aim_direction()
	var total_preview_dist: float = 820.0
	var dot_spacing: float = 26.0
	var traveled: float = 0.0
	var max_bounces: int = 2
	var bounces_done: int = 0
	var phase_offset: float = fmod(aim_pulse_time * 12.0, dot_spacing)

	while traveled < total_preview_dist and bounces_done <= max_bounces:
		var remaining_dist: float = total_preview_dist - traveled
		var ray_end: Vector2 = current_origin + current_dir * remaining_dist

		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(current_origin, ray_end)
		query.collision_mask = 1
		query.exclude = [get_rid()]

		var result: Dictionary = space_state.intersect_ray(query)
		var segment_end: Vector2 = ray_end
		var hit_something: bool = not result.is_empty()

		if hit_something:
			segment_end = result["position"]

		var seg_vec: Vector2 = segment_end - current_origin
		var seg_len: float = seg_vec.length()

		var d: float = phase_offset if traveled == 0.0 else 10.0
		while d < seg_len:
			var world_pt: Vector2 = current_origin + current_dir * d
			var local_pt: Vector2 = to_local(world_pt)
			var progress: float = (traveled + d) / total_preview_dist
			var alpha: float = clamp(1.0 - progress * 0.85, 0.15, 0.95)
			var r_size: float = lerp(5.2, 2.8, progress)
			var c: Color = Color(dot_color.r, dot_color.g, dot_color.b, alpha)
			draw_circle(local_pt, r_size, c)
			d += dot_spacing

		traveled += seg_len

		if hit_something:
			var hit_normal: Vector2 = result["normal"]
			var collider: Object = result["collider"]
			var bounce_local: Vector2 = to_local(segment_end)
			draw_circle(bounce_local, 6.5, Color(1.0, 1.0, 1.0, 0.65))

			if not (collider is Brick) or (collider is Brick and (collider as Brick).brick_type == "UNBREAKABLE"):
				current_dir = current_dir.bounce(hit_normal).normalized()
				current_origin = segment_end + hit_normal * 4.0
				bounces_done += 1
			else:
				break
		else:
			break
