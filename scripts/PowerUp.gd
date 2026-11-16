extends Area2D
class_name PowerUp

signal collected(skill_type: String)

var skill_type: String = "TRI_BALL"
var fall_speed: float = 235.0
var anim_time: float = 0.0

func setup(type: String, start_pos: Vector2) -> void:
	skill_type = type
	global_position = start_pos
	queue_redraw()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	anim_time += delta * 5.0
	position.y += fall_speed * delta
	position.x += sin(anim_time * 0.8) * 18.0 * delta
	queue_redraw()
	if position.y > 1320.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is Paddle:
		AudioHapticManager.play_powerup()
		emit_signal("collected", skill_type)
		queue_free()

func _draw() -> void:
	var pulse: float = 1.0 + sin(anim_time) * 0.07

	match skill_type:
		"GHOST":
			var ghost_col: Color = Color("#68D391")
			draw_circle(Vector2.ZERO, 22.0 * pulse, Color(0.41, 0.83, 0.57, 0.22))
			draw_circle(Vector2(0, -4), 12.0, ghost_col)
			var body_pts: PackedVector2Array = PackedVector2Array([
				Vector2(-12, -4), Vector2(12, -4), Vector2(12, 11),
				Vector2(6, 7), Vector2(0, 12), Vector2(-6, 7), Vector2(-12, 11)
			])
			draw_colored_polygon(body_pts, ghost_col)
			draw_circle(Vector2(-4, -5), 2.3, Color("#1A202C"))
			draw_circle(Vector2(4, -5), 2.3, Color("#1A202C"))

		"SLOW_MO":
			var time_col: Color = Color("#63B3ED")
			draw_circle(Vector2.ZERO, 22.0 * pulse, Color(0.39, 0.70, 0.93, 0.22))
			draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, time_col, 3.0)
			draw_circle(Vector2.ZERO, 12.5, Color(0.1, 0.15, 0.22, 0.9))
			draw_rect(Rect2(-4, -19, 8, 4), Color.WHITE, true)
			var hand_angle: float = anim_time * 0.6
			draw_line(Vector2.ZERO, Vector2(0, -8), Color.WHITE, 2.2)
			draw_line(Vector2.ZERO, Vector2.from_angle(hand_angle) * 7.5, time_col, 2.0)
			draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

		"TRI_BALL":
			var orb_col: Color = Color("#F6AD55")
			draw_circle(Vector2.ZERO, 23.0 * pulse, Color(0.96, 0.68, 0.33, 0.22))
			for i: int in range(3):
				var ang: float = (TAU / 3.0) * i + anim_time * 0.7
				var pos: Vector2 = Vector2.from_angle(ang) * 9.5
				draw_circle(pos, 6.2, orb_col)
				draw_circle(pos + Vector2(-1.8, -1.8), 2.0, Color.WHITE)

		"WIDE":
			var wide_col: Color = Color("#00A3A6")
			draw_circle(Vector2.ZERO, 22.0 * pulse, Color(0.0, 0.64, 0.65, 0.24))
			draw_rect(Rect2(-14, -4, 28, 8), wide_col, true)
			draw_rect(Rect2(-12, -2, 24, 3), Color("#E2F8F9"), true)
			var left_arrow: PackedVector2Array = PackedVector2Array([
				Vector2(-23, 0), Vector2(-16, -6), Vector2(-16, 6)
			])
			var right_arrow: PackedVector2Array = PackedVector2Array([
				Vector2(23, 0), Vector2(16, -6), Vector2(16, 6)
			])
			draw_colored_polygon(left_arrow, Color.WHITE)
			draw_colored_polygon(right_arrow, Color.WHITE)

		"LASER":
			var laser_col: Color = Color("#FC8181")
			draw_circle(Vector2.ZERO, 22.0 * pulse, Color(0.99, 0.51, 0.51, 0.24))
			draw_rect(Rect2(-13, 4, 26, 7), Color("#CBD5E0"), true)
			draw_rect(Rect2(-10, -13, 4, 17), laser_col, true)
			draw_rect(Rect2(6, -13, 4, 17), laser_col, true)
			draw_line(Vector2(-8, -15), Vector2(-8, -3), Color.WHITE, 1.8)
			draw_line(Vector2(8, -15), Vector2(8, -3), Color.WHITE, 1.8)
