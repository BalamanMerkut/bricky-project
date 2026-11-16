extends Area2D
class_name Laser

var direction: Vector2 = Vector2.UP
var speed: float = 980.0
var damage: int = 1
var is_turret_bullet: bool = false

func setup_bullet(dir: Vector2, dmg: int, turret_mode: bool = false) -> void:
	direction = dir.normalized()
	damage = maxi(1, dmg)
	is_turret_bullet = turret_mode
	rotation = direction.angle() + PI * 0.5
	queue_redraw()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += direction * speed * delta
	if position.y < -60.0 or position.y > 1340.0 or position.x < -60.0 or position.x > 780.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is Brick:
		var br: Brick = body
		br.take_hit(false, damage)
		queue_free()

func _draw() -> void:
	if is_turret_bullet:
		draw_circle(Vector2.ZERO, 7.0, Color("#38F2F6"))
		draw_circle(Vector2.ZERO, 3.5, Color.WHITE)
	else:
		draw_rect(Rect2(-3, -12, 6, 24), Color("#FC8181"), true)
		draw_rect(Rect2(-1.5, -10, 3, 20), Color.WHITE, true)
