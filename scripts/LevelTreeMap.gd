extends Control
class_name LevelTreeMap

signal level_selected(level_num: int)

const NODE_STEP_Y: float = 155.0
const TOP_PADDING: float = 120.0
const BOTTOM_PADDING: float = 160.0

var max_visible_level: int = 15
var node_positions: Dictionary = {}
var anim_from_level: int = -1
var anim_to_level: int = -1
var anim_progress: float = 0.0
var glow_pulse: float = 0.0
var press_start_pos: Vector2 = Vector2.ZERO

func setup_tree(unlocked_level: int, animate_from: int = -1, animate_to: int = -1) -> void:
	max_visible_level = unlocked_level + 8
	anim_from_level = animate_from
	anim_to_level = animate_to
	anim_progress = 0.0 if animate_from > 0 else 1.0

	var total_height: float = TOP_PADDING + BOTTOM_PADDING + float(max_visible_level) * NODE_STEP_Y
	custom_minimum_size = Vector2(640.0, total_height)
	size = custom_minimum_size

	node_positions.clear()
	for lvl: int in range(1, max_visible_level + 1):
		node_positions[lvl] = _compute_node_pos(lvl, total_height)

	queue_redraw()

	if anim_from_level > 0 and anim_to_level > 0:
		var tw: Tween = create_tween()
		tw.tween_method(func(v: float) -> void:
			anim_progress = v
			queue_redraw()
		, 0.0, 1.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _compute_node_pos(lvl: int, total_h: float) -> Vector2:
	var y: float = total_h - BOTTOM_PADDING - float(lvl - 1) * NODE_STEP_Y
	var wave_x: float = sin(float(lvl - 1) * 0.85) * 165.0
	var x: float = 320.0 + wave_x
	return Vector2(x, y)

func get_node_y(lvl: int) -> float:
	if node_positions.has(lvl):
		return (node_positions[lvl] as Vector2).y
	return 0.0

func _process(delta: float) -> void:
	if visible:
		glow_pulse += delta * 4.0
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_start_pos = mb.position
			else:
				if mb.position.distance_to(press_start_pos) < 18.0:
					_try_select_node_at(mb.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			press_start_pos = st.position
		else:
			if st.position.distance_to(press_start_pos) < 18.0:
				_try_select_node_at(st.position)

func _try_select_node_at(pos_click: Vector2) -> void:
	for lvl_key: Variant in node_positions.keys():
		var lvl: int = int(lvl_key)
		if lvl <= GameData.classic_unlocked_level:
			var pos: Vector2 = node_positions[lvl]
			if pos.distance_to(pos_click) <= 46.0:
				AudioHapticManager.play_ui_click()
				get_viewport().set_input_as_handled()
				emit_signal("level_selected", lvl)
				break

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var unlocked: int = GameData.classic_unlocked_level

	for lvl: int in range(1, max_visible_level):
		var p1: Vector2 = node_positions[lvl]
		var p2: Vector2 = node_positions[lvl + 1]

		if lvl == anim_from_level and (lvl + 1) == anim_to_level:
			draw_line(p1, p2, Color(0.25, 0.3, 0.38, 0.6), 6.0, true)
			var cur_end: Vector2 = p1.lerp(p2, anim_progress)
			draw_line(p1, cur_end, Color(0.0, 0.85, 0.88, 0.35), 14.0, true)
			draw_line(p1, cur_end, Color("#38F2F6"), 6.0, true)
			draw_circle(cur_end, 8.0, Color.WHITE)
		elif (lvl + 1) <= unlocked:
			draw_line(p1, p2, Color(0.0, 0.64, 0.65, 0.35), 10.0, true)
			draw_line(p1, p2, Color("#00A3A6"), 5.0, true)
		else:
			draw_line(p1, p2, Color(0.22, 0.27, 0.35, 0.55), 4.0, true)

	for lvl: int in range(1, max_visible_level + 1):
		var pos: Vector2 = node_positions[lvl]
		var is_unlocked: bool = lvl <= unlocked
		var is_current_target: bool = (lvl == unlocked)
		var is_just_unlocked: bool = (lvl == anim_to_level and anim_progress >= 0.85)

		if is_current_target or is_just_unlocked:
			var pulse_r: float = 46.0 + sin(glow_pulse) * 7.0
			var glow_alpha: float = 0.28 + sin(glow_pulse) * 0.12
			if is_just_unlocked:
				pulse_r += 8.0
				glow_alpha = 0.55
			draw_circle(pos, pulse_r, Color(0.22, 0.95, 0.96, glow_alpha))

		var circle_col: Color = Color("#00A3A6") if is_unlocked else Color("#1E2633")
		if is_current_target:
			circle_col = Color("#0BC5EA")
		draw_circle(pos, 34.0, circle_col)

		var ring_col: Color = Color.WHITE if is_current_target else (Color("#81E6D9") if is_unlocked else Color("#4A5568"))
		draw_arc(pos, 34.0, 0.0, TAU, 32, ring_col, 3.0)

		var num_str: String = str(lvl)
		var font_size: int = 20 if num_str.length() <= 3 else 16
		var txt_col: Color = Color.WHITE if is_unlocked else Color("#718096")
		draw_string(font, pos + Vector2(-30, 7), num_str, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, txt_col)

		if is_current_target:
			draw_string(font, pos + Vector2(-45, 52), "OYNA", HORIZONTAL_ALIGNMENT_CENTER, 90, 13, Color("#38F2F6"))
		elif lvl < unlocked:
			draw_string(font, pos + Vector2(-45, 50), "TAMAM", HORIZONTAL_ALIGNMENT_CENTER, 90, 11, Color("#81E6D9"))
