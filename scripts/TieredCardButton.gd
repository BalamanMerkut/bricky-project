extends Control
class_name TieredCardButton

signal card_chosen(card_data: Dictionary)

var card_data: Dictionary = {}
var tier: String = "BRONZE"
var anim_time: float = 0.0
var is_hovered: bool = false
var press_scale: float = 1.0

func setup(data: Dictionary, index: int) -> void:
	card_data = data
	tier = str(data.get("tier", "BRONZE"))
	anim_time = float(index) * 1.15
	custom_minimum_size = Vector2(212.0, 405.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = Vector2(106.0, 202.5)

	modulate.a = 0.0
	scale = Vector2(0.84, 0.84)
	var tw: Tween = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(float(index) * 0.09)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.24)
	tw.tween_property(self, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		is_hovered = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		is_hovered = false

func _gui_input(event: InputEvent) -> void:
	var clicked: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_scale = 0.96
			else:
				press_scale = 1.0
				if Rect2(Vector2.ZERO, size).has_point(mb.position):
					clicked = true
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			press_scale = 0.96
		else:
			press_scale = 1.0
			if Rect2(Vector2.ZERO, size).has_point(st.position):
				clicked = true

	if clicked:
		get_viewport().set_input_as_handled()
		emit_signal("card_chosen", card_data)

func _process(delta: float) -> void:
	var speed_mult: float = 2.0 if tier == "BRONZE" else (4.2 if tier == "SILVER" else 7.0)
	anim_time += delta * speed_mult

	if tier == "GOLD":
		var idle_pulse: float = 1.0 + sin(anim_time * 0.75) * 0.018
		var target_s: float = press_scale * (1.035 if is_hovered else idle_pulse)
		scale = scale.lerp(Vector2(target_s, target_s), min(1.0, delta * 14.0))
	elif tier == "SILVER":
		var target_s: float = press_scale * (1.025 if is_hovered else 1.0)
		scale = scale.lerp(Vector2(target_s, target_s), min(1.0, delta * 14.0))
	else:
		var target_s: float = press_scale * (1.015 if is_hovered else 1.0)
		scale = scale.lerp(Vector2(target_s, target_s), min(1.0, delta * 14.0))

	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	var font: Font = ThemeDB.fallback_font
	var outer_rect: Rect2 = Rect2(Vector2.ZERO, size)
	var pulse: float = 0.5 + 0.5 * sin(anim_time)

	# Kademeye göre Arena kart renk paleti
	var outer_bevel_col: Color
	var inner_dark_bg: Color
	var inner_rim_col: Color
	var glow_col: Color
	var icon_col: Color
	var badge_text: String
	var badge_bg: Color
	var stat_col: Color
	var btn_fill: Color
	var btn_border: Color
	var glow_layers: int = 0

	match tier:
		"GOLD":
			outer_bevel_col = Color("#D69E2E").lerp(Color("#FEFCBF"), pulse * 0.45)
			inner_dark_bg = Color(0.05, 0.09, 0.10, 0.98)
			inner_rim_col = Color("#F6E05E")
			glow_col = Color(1.0, 0.84, 0.22, 0.24 + pulse * 0.22)
			icon_col = Color("#F6E05E")
			badge_text = "Altın Çekirdek"
			badge_bg = Color(0.28, 0.22, 0.08, 0.95)
			stat_col = Color("#F6E05E")
			btn_fill = Color(0.14, 0.34, 0.40, 0.96)
			btn_border = Color("#F6E05E")
			glow_layers = 4
		"SILVER":
			outer_bevel_col = Color("#9AE6B4").lerp(Color("#81E6D9"), pulse * 0.35)
			inner_dark_bg = Color(0.04, 0.09, 0.10, 0.98)
			inner_rim_col = Color("#CBD5E0")
			glow_col = Color(0.50, 0.88, 0.85, 0.12 + pulse * 0.10)
			icon_col = Color("#CBD5E0")
			badge_text = "Gümüş Çekirdek"
			badge_bg = Color(0.16, 0.22, 0.25, 0.95)
			stat_col = Color("#81E6D9")
			btn_fill = Color(0.08, 0.28, 0.34, 0.95)
			btn_border = Color("#81E6D9")
			glow_layers = 2
		_:
			outer_bevel_col = Color("#9C6B30").lerp(Color("#C08540"), pulse * 0.15)
			inner_dark_bg = Color(0.04, 0.08, 0.09, 0.98)
			inner_rim_col = Color("#B7791F")
			glow_col = Color(0.72, 0.45, 0.18, 0.05 + pulse * 0.03)
			icon_col = Color("#CBD5E0")
			badge_text = "Bronz Çekirdek"
			badge_bg = Color(0.20, 0.16, 0.11, 0.95)
			stat_col = Color("#FBD38D")
			btn_fill = Color(0.07, 0.24, 0.30, 0.95)
			btn_border = Color("#4FD1C5")
			glow_layers = 1

	# Dış Parlama (Tier'a göre şiddetlenen)
	for i: int in range(1, glow_layers + 1):
		var expand: float = float(i) * (4.0 if tier == "GOLD" else 2.8)
		var layer_alpha: float = glow_col.a / float(i)
		var g_rect: Rect2 = Rect2(-expand, -expand, w + expand * 2.0, h + expand * 2.0)
		draw_rect(g_rect, Color(glow_col.r, glow_col.g, glow_col.b, layer_alpha), true)

	# 1. Dış Kalın Metalik Çerçeve (LoL Arena Kart Dış Kasası)
	draw_rect(outer_rect, outer_bevel_col, true)
	draw_rect(outer_rect, Color(0.08, 0.12, 0.14), false, 2.0)

	# 2. İç Koyu Zümrüt/Arduvaz Kart Gövdesi
	var inset: float = 9.0
	var inner_rect: Rect2 = Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0)
	draw_rect(inner_rect, inner_dark_bg, true)
	draw_rect(inner_rect, inner_rim_col, false, 2.0)

	# Köşe Dekoratif Perçinleri
	var corner_pts: Array[Vector2] = [
		Vector2(inset + 5.0, inset + 5.0),
		Vector2(w - inset - 5.0, inset + 5.0),
		Vector2(inset + 5.0, h - inset - 5.0),
		Vector2(w - inset - 5.0, h - inset - 5.0)
	]
	for cp: Vector2 in corner_pts:
		draw_circle(cp, 2.4, inner_rim_col)

	# Gümüş & Altın Işık Yansıması
	if tier == "SILVER" or tier == "GOLD":
		var cycle: float = fmod(anim_time * (0.28 if tier == "SILVER" else 0.45), 1.8) - 0.4
		var sweep_y: float = cycle * h
		var sweep_h: float = 40.0 if tier == "SILVER" else 65.0
		var sweep_alpha: float = 0.07 if tier == "SILVER" else 0.18
		var y0: float = clamp(sweep_y, inset, h - inset)
		var y1: float = clamp(sweep_y + sweep_h, inset, h - inset)
		if y1 > y0:
			draw_rect(Rect2(inset + 2.0, y0, w - (inset + 2.0) * 2.0, y1 - y0), Color(1.0, 0.98, 0.85, sweep_alpha), true)

	# Altın Parıltı Yıldızları
	if tier == "GOLD":
		for s_idx: int in range(5):
			var ang: float = anim_time * 0.7 + float(s_idx) * (TAU / 5.0)
			var sx: float = w * 0.5 + cos(ang) * (w * 0.36)
			var sy: float = h * 0.48 + sin(ang * 2.0) * (h * 0.38)
			var star_r: float = 2.2 + 1.8 * sin(anim_time * 2.2 + float(s_idx))
			draw_circle(Vector2(sx, sy), star_r, Color(1.0, 0.96, 0.65, 0.88))

	# 3. Üst Orta Vektörel Sembol İkonu (y = 84)
	var icon_center: Vector2 = Vector2(w * 0.5, 84.0)
	_draw_card_symbol(str(card_data.get("id", "DMG_UP")), icon_center, icon_col)

	# 4. Ortadaki Başlık (Örn: "Saldırı Gücü Kristali")
	var title_txt: String = str(card_data.get("title", "Yetenek Kristali"))
	draw_string(font, Vector2(14.0, 178.0), title_txt, HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 15, Color.WHITE)

	# 5. Küçük Kademe Rozeti Kutusu (LoL Arena "Nitelik Örsü" kutucuğu tarzında)
	var badge_w: float = 114.0
	var badge_h: float = 20.0
	var badge_rect: Rect2 = Rect2((w - badge_w) * 0.5, 190.0, badge_w, badge_h)
	draw_rect(badge_rect, badge_bg, true)
	draw_rect(badge_rect, inner_rim_col, false, 1.2)
	draw_string(font, Vector2(badge_rect.position.x, 204.0), badge_text, HORIZONTAL_ALIGNMENT_CENTER, badge_w, 11, Color("#E2E8F0"))

	# 6. Stat Kazancı Satırı (Örn: "+2 Çekirdek Hasarı")
	var stat_txt: String = str(card_data.get("stat_line", ""))
	draw_string(font, Vector2(14.0, 244.0), stat_txt, HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 14, stat_col)

	# 7. Bedel / Handikap Satırı (Varsa kırmızıyla altında)
	var drawback_txt: String = str(card_data.get("drawback", ""))
	if drawback_txt != "":
		draw_string(font, Vector2(14.0, 272.0), drawback_txt, HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 12, Color("#FC8181"))

	# 8. En Altta Kart İçi Seçim / İlerleme Butonu (LoL Arena alt mavi ok butonu tarzında)
	var sel_w: float = 148.0
	var sel_h: float = 34.0
	var sel_rect: Rect2 = Rect2((w - sel_w) * 0.5, h - 54.0, sel_w, sel_h)
	draw_rect(sel_rect, btn_fill, true)
	draw_rect(sel_rect, btn_border, false, 1.8)
	# Ortada sağa bakan keskin ok simgesi
	var cx: float = sel_rect.position.x + sel_w * 0.5
	var cy: float = sel_rect.position.y + sel_h * 0.5
	var arrow_pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 10.0, cy - 3.0),
		Vector2(cx + 2.0, cy - 3.0),
		Vector2(cx + 2.0, cy - 8.0),
		Vector2(cx + 12.0, cy),
		Vector2(cx + 2.0, cy + 8.0),
		Vector2(cx + 2.0, cy + 3.0),
		Vector2(cx - 10.0, cy + 3.0)
	])
	draw_colored_polygon(arrow_pts, Color("#E2F8F9"))

func _draw_card_symbol(arch: String, center: Vector2, col: Color) -> void:
	match arch:
		"DMG_UP":
			# Çapraz Kılıç / Balta Sembolü
			draw_line(center + Vector2(-18, 18), center + Vector2(18, -18), col, 5.0, true)
			var blade: PackedVector2Array = PackedVector2Array([
				center + Vector2(-4, -18),
				center + Vector2(20, -20),
				center + Vector2(18, 4),
				center + Vector2(6, -6)
			])
			draw_colored_polygon(blade, col)
			draw_line(center + Vector2(-16, 4), center + Vector2(-4, 16), col, 4.0, true)

		"HEAL":
			# Kalp Sembolü
			draw_circle(center + Vector2(-10, -6), 11.0, col)
			draw_circle(center + Vector2(10, -6), 11.0, col)
			var tri: PackedVector2Array = PackedVector2Array([
				center + Vector2(-20.5, -2.0),
				center + Vector2(20.5, -2.0),
				center + Vector2(0.0, 22.0)
			])
			draw_colored_polygon(tri, col)

		"GHOST_PULSE", "EXP_BOOST":
			# Hedef / Büyü Nüfuzu Halkası Sembolü
			draw_arc(center, 21.0, 0.0, TAU, 32, col, 4.0)
			draw_arc(center, 11.0, 0.0, TAU, 24, col, 3.0)
			draw_line(center, center + Vector2(18, -12), col, 3.5, true)
			draw_circle(center, 4.0, col)

		"WIDE_PADDLE":
			# Geniş Kalkan Sembolü
			var shield: PackedVector2Array = PackedVector2Array([
				center + Vector2(-18, -18),
				center + Vector2(18, -18),
				center + Vector2(18, 2),
				center + Vector2(0, 22),
				center + Vector2(-18, 2)
			])
			draw_colored_polygon(shield, col)

		"LASER_TURRET":
			# İkiz Işın Taret Sembolü
			draw_rect(Rect2(center.x - 16, center.y + 6, 32, 10), col, true)
			draw_rect(Rect2(center.x - 12, center.y - 18, 6, 24), col, true)
			draw_rect(Rect2(center.x + 6, center.y - 18, 6, 24), col, true)

		"MULTI_BALL":
			# Üçlü Çekirdek Küreleri
			draw_circle(center + Vector2(0, -13), 8.5, col)
			draw_circle(center + Vector2(-13, 10), 8.5, col)
			draw_circle(center + Vector2(13, 10), 8.5, col)

		"SPEED_UP":
			# Çift İleri İvme Oku
			var chev1: PackedVector2Array = PackedVector2Array([
				center + Vector2(-16, -6), center + Vector2(0, -20), center + Vector2(16, -6),
				center + Vector2(10, 0), center + Vector2(0, -10), center + Vector2(-10, 0)
			])
			var chev2: PackedVector2Array = PackedVector2Array([
				center + Vector2(-16, 10), center + Vector2(0, -4), center + Vector2(16, 10),
				center + Vector2(10, 16), center + Vector2(0, 6), center + Vector2(-10, 16)
			])
			draw_colored_polygon(chev1, col)
			draw_colored_polygon(chev2, col)

		_:
			# Altın Elmas Kristal Sembolü
			var gem: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -22),
				center + Vector2(18, 0),
				center + Vector2(0, 22),
				center + Vector2(-18, 0)
			])
			draw_colored_polygon(gem, col)
