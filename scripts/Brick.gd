extends StaticBody2D
class_name Brick

signal destroyed(brick: Brick, by_ghost: bool)
signal reached_center_paddle(brick: Brick)

@export var brick_size: Vector2 = Vector2(78.0, 32.0)

var brick_type: String = "NORMAL"
var max_hp: int = 1
var hp: int = 1
var grid_coord: Vector2i = Vector2i.ZERO
var flash_amount: float = 0.0
var is_broken_state: bool = false

var is_rogue_attacker: bool = false
var move_vel: Vector2 = Vector2.ZERO
var spin_speed: float = 0.0
var target_center: Vector2 = Vector2(360.0, 640.0)

func setup(type: String, coord: Vector2i, wave_num: int = 1, is_modern: bool = false) -> void:
	brick_type = type
	grid_coord = coord
	is_broken_state = false
	is_rogue_attacker = false
	rotation = 0.0

	if is_modern:
		var diff: Dictionary = DDAManager.get_wave_difficulty(wave_num, true)
		var hp_scale: float = float(diff.get("hp_scale", 1.0))
		match brick_type:
			"NORMAL":
				max_hp = maxi(1, int(round(1.0 * hp_scale)))
			"ARMORED":
				max_hp = maxi(3, int(round(3.0 * hp_scale)))
			"UNBREAKABLE":
				max_hp = 999999
			"EXPLOSIVE":
				max_hp = maxi(1, int(round(1.0 * (hp_scale * 0.75))))
	else:
		match brick_type:
			"NORMAL":
				max_hp = 1
			"ARMORED":
				max_hp = 3 if wave_num >= 6 else 2
			"UNBREAKABLE":
				max_hp = 999999
			"EXPLOSIVE":
				max_hp = 1

	hp = max_hp
	queue_redraw()

func setup_rogue_attacker(start_pos: Vector2, center_pos: Vector2, wave_num: int) -> void:
	is_rogue_attacker = true
	is_broken_state = false
	brick_type = "ARMORED" if randf() < 0.45 else "NORMAL"
	var scale_mult: float = 1.0 + float(wave_num) * 0.14
	max_hp = maxi(3, int(round(3.0 * scale_mult))) if brick_type == "ARMORED" else maxi(1, int(round(1.5 * scale_mult)))
	hp = max_hp
	global_position = start_pos
	target_center = center_pos
	var to_center: Vector2 = (center_pos - start_pos).normalized()
	var spd: float = randf_range(115.0, 175.0) + float(wave_num) * 2.2
	move_vel = to_center * spd
	spin_speed = randf_range(-3.2, 3.2)
	queue_redraw()

func take_hit(instant_kill: bool = false, damage_amount: int = 1) -> bool:
	if is_broken_state:
		return true

	if brick_type == "UNBREAKABLE":
		flash_amount = 1.0
		AudioHapticManager.play_brick_hit("UNBREAKABLE", false)
		_pulse_anim()
		return false

	if instant_kill:
		hp = 0
	else:
		hp -= maxi(1, damage_amount)

	var broken: bool = hp <= 0
	AudioHapticManager.play_brick_hit(brick_type, broken)

	if broken:
		is_broken_state = true
		emit_signal("destroyed", self, instant_kill)
		queue_free()
		return true
	else:
		flash_amount = 1.0
		_pulse_anim()
		queue_redraw()
		return false

func _pulse_anim() -> void:
	var tw: Tween = create_tween()
	scale = Vector2(1.12, 0.88)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_ELASTIC)

func _process(delta: float) -> void:
	if flash_amount > 0.0:
		flash_amount = max(0.0, flash_amount - delta * 5.0)
		queue_redraw()

	if is_rogue_attacker and not is_broken_state:
		var perp: Vector2 = Vector2(-move_vel.y, move_vel.x).normalized()
		var wobble: Vector2 = perp * sin(Time.get_ticks_msec() * 0.005 + float(get_instance_id() % 10)) * 42.0
		position += (move_vel + wobble) * delta
		rotation += spin_speed * delta

		if global_position.distance_to(target_center) <= 52.0:
			is_broken_state = true
			emit_signal("reached_center_paddle", self)
			queue_free()

func _draw() -> void:
	var half: Vector2 = brick_size * 0.5
	var rect: Rect2 = Rect2(-half, brick_size)
	var hp_ratio: float = clamp(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)

	if brick_type == "UNBREAKABLE":
		# Tamamen düz, ağır siyah obsidyen/çelik blok (X işareti yok)
		var obsidian_col: Color = Color(0.05, 0.06, 0.08)
		if flash_amount > 0.0:
			obsidian_col = obsidian_col.lerp(Color(0.28, 0.32, 0.38), flash_amount * 0.6)
		draw_rect(rect, obsidian_col, true)
		draw_rect(rect, Color(0.16, 0.19, 0.24), false, 2.0)
		return

	var base_col: Color = Color("#38B2AC")
	match brick_type:
		"NORMAL":
			if is_rogue_attacker:
				base_col = Color("#E53E3E")
			else:
				var row_colors: Array[Color] = [Color("#00A3A6"), Color("#3182CE"), Color("#4FD1C5"), Color("#63B3ED")]
				base_col = row_colors[grid_coord.y % row_colors.size()]
		"ARMORED":
			# Can azaldıkça koyu çelikten açık griye doğru ton değiştirir
			base_col = Color("#A0AEC0").lerp(Color("#4A5568"), hp_ratio)
		"EXPLOSIVE":
			base_col = Color("#ED8936")

	if flash_amount > 0.0:
		base_col = base_col.lerp(Color.WHITE, flash_amount * 0.7)

	draw_rect(rect, base_col, true)
	draw_rect(Rect2(-half.x + 3, -half.y + 3, brick_size.x - 6, 4), Color(1, 1, 1, 0.25), true)

	if brick_type == "ARMORED":
		draw_rect(rect, Color("#CBD5E0"), false, 2.2)

	elif brick_type == "EXPLOSIVE":
		draw_circle(Vector2.ZERO, 7.0, Color("#FEFCBF"))

	# Hasar almış her tuğlada görsel çatlak izleri (sayı yerine görsel aşinalık)
	if hp < max_hp:
		draw_line(Vector2(-14, -half.y), Vector2(-2, -1), Color(0.08, 0.1, 0.14, 0.85), 2.2)
		draw_line(Vector2(-2, -1), Vector2(-10, half.y), Color(0.08, 0.1, 0.14, 0.85), 2.2)
		if hp_ratio <= 0.5:
			draw_line(Vector2(14, -half.y), Vector2(4, 2), Color(0.08, 0.1, 0.14, 0.85), 2.2)
			draw_line(Vector2(4, 2), Vector2(16, half.y), Color(0.08, 0.1, 0.14, 0.85), 2.2)
