extends Node2D

var brick_scene: PackedScene = preload("res://scenes/Brick.tscn")
var ball_scene: PackedScene = preload("res://scenes/Ball.tscn")
var powerup_scene: PackedScene = preload("res://scenes/PowerUp.tscn")
var laser_scene: PackedScene = preload("res://scenes/Laser.tscn")

var game_mode: String = "CLASSIC"
var current_classic_level: int = 1

var score: int = 0
var lives: int = 3
var wave: int = 1
var remaining_breakable_bricks: int = 0
var is_transitioning: bool = false
var slow_mo_timer: float = 0.0
var shake_strength: float = 0.0
var is_in_menu: bool = true
var is_game_paused: bool = false

var run_level: int = 1
var run_exp: int = 0
var run_exp_to_next: int = 180
var pending_level_ups: int = 0

var run_bonus_damage: int = 0
var run_bonus_speed_mult: float = 1.0
var run_bonus_paddle_w: float = 0.0
var run_gold_mult: float = 1.0
var run_exp_mult: float = 1.0
var run_has_laser: bool = false
var run_laser_interval: float = 0.90
var run_ghost_duration_bonus: float = 0.0
var run_extra_balls: int = 0

var is_defense_wave: bool = false
var defense_spawn_timer: float = 0.0
var defense_bricks_to_spawn: int = 0

@onready var camera: Camera2D = $Camera2D
@onready var paddle: Paddle = $Paddle
@onready var bricks_container: Node2D = $BricksContainer
@onready var balls_container: Node2D = $BallsContainer
@onready var drops_container: Node2D = $DropsContainer
@onready var grid_gen: GridGenerator = $GridGenerator

@onready var top_bar: HBoxContainer = $UI/TopBar
@onready var lbl_score: Label = $UI/TopBar/LblScore
@onready var lbl_wave: Label = $UI/TopBar/LblWave
@onready var lbl_coins: Label = $UI/TopBar/LblCoins
@onready var lbl_lives: Label = $UI/TopBar/LblLives

@onready var exp_bar_container: HBoxContainer = $UI/ExpBarContainer
@onready var lbl_run_level: Label = $UI/ExpBarContainer/LblRunLevel
@onready var exp_progress: ProgressBar = $UI/ExpBarContainer/ExpProgress
@onready var lbl_exp_text: Label = $UI/ExpBarContainer/LblExpText

@onready var slowmo_overlay: ColorRect = $UI/SlowMoOverlay
@onready var lbl_aim_hint: Label = $UI/LblAimHint
@onready var lbl_wave_banner: Label = $UI/LblWaveBanner
@onready var lbl_version: Label = $UI/LblVersion

@onready var main_menu_panel: PanelContainer = $UI/MainMenuPanel
@onready var lbl_menu_records: Label = $UI/MainMenuPanel/VBox/LblRecords
@onready var mode_select_panel: PanelContainer = $UI/ModeSelectPanel
@onready var level_tree_panel: PanelContainer = $UI/LevelTreePanel
@onready var level_tree_scroll: ScrollContainer = $UI/LevelTreePanel/VBox/TreeScroll
@onready var level_tree_map: LevelTreeMap = $UI/LevelTreePanel/VBox/TreeScroll/LevelTreeMap

@onready var pause_panel: PanelContainer = $UI/PausePanel
@onready var card_draft_panel: PanelContainer = $UI/CardDraftPanel
@onready var lbl_card_title: Label = $UI/CardDraftPanel/VBox/LblCardTitle
@onready var card_row_box: HBoxContainer = $UI/CardDraftPanel/VBox/CardRow
@onready var ad_break_panel: PanelContainer = $UI/AdBreakPanel
@onready var lbl_ad_info: Label = $UI/AdBreakPanel/VBox/LblAdInfo

@onready var settings_panel: PanelContainer = $UI/SettingsPanel
@onready var slider_sfx: HSlider = $UI/SettingsPanel/VBox/SfxRow/SliderSfx
@onready var lbl_sfx_val: Label = $UI/SettingsPanel/VBox/SfxRow/LblSfxVal
@onready var btn_haptic_toggle: CheckButton = $UI/SettingsPanel/VBox/BtnHapticToggle

@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var shop_panel: PanelContainer = $UI/ShopPanel
@onready var shop_list: VBoxContainer = $UI/ShopPanel/VBox/Scroll/ShopList

const CARD_ARCHETYPES: Array[String] = [
	"DMG_UP",
	"WIDE_PADDLE",
	"LASER_TURRET",
	"MULTI_BALL",
	"SPEED_UP",
	"HEAL",
	"GOLD_RUSH",
	"EXP_BOOST",
	"GHOST_PULSE"
]

func _ready() -> void:
	lbl_version.text = "MERKUTSTUDIOS • %s" % GameData.GAME_VERSION
	DDAManager.reset_session()
	paddle.launch_requested.connect(_on_launch_requested)
	paddle.laser_fired.connect(_on_laser_fired)
	paddle.defense_shot_fired.connect(_on_defense_shot_fired)
	level_tree_map.level_selected.connect(_on_classic_level_selected)
	GameData.coins_changed.connect(func(c: int) -> void: lbl_coins.text = "ALTIN: %d" % c)
	_show_main_menu()

func _hide_all_panels() -> void:
	main_menu_panel.visible = false
	mode_select_panel.visible = false
	level_tree_panel.visible = false
	pause_panel.visible = false
	card_draft_panel.visible = false
	ad_break_panel.visible = false
	settings_panel.visible = false
	game_over_panel.visible = false
	shop_panel.visible = false
	slowmo_overlay.visible = false
	lbl_wave_banner.visible = false
	lbl_aim_hint.visible = false

func _clear_entities() -> void:
	for b: Node in balls_container.get_children():
		b.queue_free()
	for d: Node in drops_container.get_children():
		d.queue_free()
	for br: Node in bricks_container.get_children():
		br.queue_free()

func _show_main_menu() -> void:
	is_in_menu = true
	is_game_paused = false
	is_transitioning = false
	is_defense_wave = false
	slow_mo_timer = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	paddle.set_input_active(false)
	paddle.reset_all_states()
	paddle.set_defense_mode(false)
	paddle.visible = false
	top_bar.visible = false
	exp_bar_container.visible = false
	_hide_all_panels()
	_clear_entities()

	lbl_menu_records.text = "CLASSIC BÖLÜM: %d   |   MODERN REKOR: %d" % [GameData.classic_unlocked_level, GameData.high_score]
	main_menu_panel.visible = true

func _open_level_tree(anim_from: int = -1, anim_to: int = -1) -> void:
	is_in_menu = true
	is_game_paused = false
	is_transitioning = false
	is_defense_wave = false
	slow_mo_timer = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	paddle.set_input_active(false)
	paddle.reset_all_states()
	paddle.set_defense_mode(false)
	paddle.visible = false
	top_bar.visible = false
	exp_bar_container.visible = false
	_hide_all_panels()
	_clear_entities()

	level_tree_panel.visible = true
	level_tree_map.setup_tree(GameData.classic_unlocked_level, anim_from, anim_to)
	await get_tree().process_frame
	var target_y: float = level_tree_map.get_node_y(GameData.classic_unlocked_level)
	level_tree_scroll.scroll_vertical = int(max(0.0, target_y - 420.0))

func _on_classic_level_selected(lvl_num: int) -> void:
	game_mode = "CLASSIC"
	current_classic_level = lvl_num
	_start_gameplay_session()

func _start_modern_run() -> void:
	game_mode = "MODERN"
	wave = 1
	run_level = 1
	run_exp = 0
	run_exp_to_next = 180
	pending_level_ups = 0
	run_bonus_damage = 0
	run_bonus_speed_mult = 1.0
	run_bonus_paddle_w = 0.0
	run_gold_mult = 1.0
	run_exp_mult = 1.0
	run_has_laser = false
	run_laser_interval = 0.90
	run_ghost_duration_bonus = 0.0
	run_extra_balls = 0
	_start_gameplay_session()

func _start_gameplay_session() -> void:
	is_in_menu = false
	is_game_paused = false
	is_transitioning = false
	is_defense_wave = false
	score = 0
	lives = 3
	slow_mo_timer = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	_hide_all_panels()
	_clear_entities()

	top_bar.visible = true
	exp_bar_container.visible = (game_mode == "MODERN")
	paddle.visible = true
	paddle.reset_all_states()
	paddle.set_defense_mode(false)
	paddle.set_input_active(true, 0.22)
	DDAManager.reset_session()

	if game_mode == "CLASSIC":
		_spawn_attached_ball()
		_load_stage(current_classic_level, true)
	else:
		_start_modern_wave(wave)

	_update_hud()

func _load_stage(stage_num: int, is_classic: bool) -> void:
	remaining_breakable_bricks = grid_gen.spawn_wave(bricks_container, stage_num, brick_scene, is_classic)
	for child: Node in bricks_container.get_children():
		if child is Brick:
			var brick: Brick = child
			if not brick.destroyed.is_connected(_on_brick_destroyed):
				brick.destroyed.connect(_on_brick_destroyed)

func _apply_modern_run_upgrades_to_paddle() -> void:
	if game_mode != "MODERN":
		return
	paddle.apply_meta_stats(run_bonus_paddle_w)
	paddle.permanent_laser = run_has_laser
	paddle.laser_fire_interval = run_laser_interval

func _start_modern_wave(w: int) -> void:
	_clear_entities()
	paddle.reset_all_states()
	_apply_modern_run_upgrades_to_paddle()

	if w % 10 == 0:
		is_defense_wave = true
		paddle.set_defense_mode(true)
		paddle.set_input_active(true, 0.22)
		defense_bricks_to_spawn = 16 + int(w * 0.7)
		remaining_breakable_bricks = defense_bricks_to_spawn
		defense_spawn_timer = 0.3

		lbl_aim_hint.text = "DÖNÜM NOKTASI! ETRAFTAN GELEN TUĞLALARA TIKLA VE ATEŞ ET!"
		lbl_aim_hint.visible = true
		lbl_wave_banner.text = "10. DALGA DÖNÜM NOKTASI!
MERKEZ SAVUNMA MODU"
		lbl_wave_banner.modulate = Color(1, 1, 1, 1)
		lbl_wave_banner.visible = true
		var tw: Tween = create_tween()
		tw.tween_interval(1.3)
		tw.tween_property(lbl_wave_banner, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func() -> void: lbl_wave_banner.visible = false)
	else:
		is_defense_wave = false
		paddle.set_defense_mode(false)
		_apply_modern_run_upgrades_to_paddle()
		paddle.set_input_active(true, 0.22)
		lbl_aim_hint.text = "BASILI TUT: NORMAL HIZ • BIRAK: AĞIR ÇEKİM"
		_spawn_attached_ball()
		_load_stage(w, false)

func _spawn_attached_ball() -> Ball:
	var ball: Ball = ball_scene.instantiate() as Ball
	balls_container.add_child(ball)
	var diff: Dictionary = DDAManager.get_wave_difficulty(wave, game_mode == "MODERN")
	ball.speed = ball.base_speed * float(diff["speed_multiplier"]) * run_bonus_speed_mult
	if game_mode == "MODERN" and run_ghost_duration_bonus > 0.0:
		ball.activate_ghost(run_ghost_duration_bonus)
	ball.attach_to_paddle(paddle)
	ball.ball_lost.connect(_on_ball_lost)
	ball.brick_hit_event.connect(_on_ball_brick_hit)
	lbl_aim_hint.visible = true
	return ball

func _on_launch_requested(launch_dir: Vector2) -> void:
	if is_in_menu or is_transitioning:
		return
	lbl_aim_hint.visible = false
	var primary_dir: Vector2 = launch_dir
	for child: Node in balls_container.get_children():
		if child is Ball:
			var b: Ball = child
			if b.is_attached:
				b.launch(primary_dir)

	if game_mode == "MODERN" and run_extra_balls > 0:
		for i: int in range(run_extra_balls):
			var angle_offset: float = (-15.0 if i % 2 == 0 else 15.0) * float(int(i / 2) + 1)
			var nb: Ball = ball_scene.instantiate() as Ball
			balls_container.add_child(nb)
			nb.global_position = Vector2(paddle.position.x, paddle.position.y - 26.0)
			var diff: Dictionary = DDAManager.get_wave_difficulty(wave, true)
			nb.speed = nb.base_speed * float(diff["speed_multiplier"]) * run_bonus_speed_mult
			if run_ghost_duration_bonus > 0.0:
				nb.activate_ghost(run_ghost_duration_bonus)
			nb.is_attached = false
			nb.velocity = primary_dir.rotated(deg_to_rad(angle_offset)).normalized() * nb.speed
			nb.ball_lost.connect(_on_ball_lost)
			nb.brick_hit_event.connect(_on_ball_brick_hit)

func _get_effective_damage() -> int:
	if game_mode == "CLASSIC":
		return 1
	var meta_dmg_bonus: int = int((int(GameData.meta_upgrades.get("damage", 1)) - 1) / 2)
	return maxi(1, 1 + meta_dmg_bonus + run_bonus_damage)

func _on_laser_fired(pos: Vector2) -> void:
	if is_in_menu or is_transitioning or not paddle.input_enabled:
		return
	var laser: Laser = laser_scene.instantiate() as Laser
	laser.global_position = pos
	var dmg: int = maxi(1, int(_get_effective_damage() / 2))
	laser.setup_bullet(Vector2.UP, dmg, false)
	drops_container.add_child(laser)

func _on_defense_shot_fired(origin: Vector2, dir: Vector2) -> void:
	if is_in_menu or is_transitioning or not paddle.input_enabled:
		return
	var bullet: Laser = laser_scene.instantiate() as Laser
	bullet.global_position = origin
	var dmg: int = _get_effective_damage()
	bullet.setup_bullet(dir, dmg, true)
	drops_container.add_child(bullet)

func _on_ball_brick_hit(brick: Node, _impact_pos: Vector2, is_ghost: bool) -> void:
	if is_in_menu or is_transitioning:
		return
	if brick is Brick:
		var br: Brick = brick
		var dmg: int = _get_effective_damage()
		if is_ghost:
			dmg = maxi(1, int(round(float(dmg) * 1.5)))
		br.take_hit(false, dmg)
		add_screen_shake(4.0 if not is_ghost else 6.5)

func _on_brick_destroyed(brick: Brick, _by_ghost: bool) -> void:
	if is_in_menu:
		return
	if brick.brick_type != "UNBREAKABLE":
		remaining_breakable_bricks = maxi(0, remaining_breakable_bricks - 1)

	DDAManager.register_brick_broken()
	var gained: int = 10 * maxi(1, AudioHapticManager.combo_step)
	score += gained
	var base_coin: int = 2 if brick.brick_type == "ARMORED" else 1
	var coin_gain: int = int(round(float(base_coin) * run_gold_mult))
	GameData.add_coins(coin_gain)
	add_screen_shake(7.0)

	if brick.brick_type == "EXPLOSIVE":
		add_screen_shake(16.0)
		var blast_dmg: int = maxi(2, _get_effective_damage() * 2)
		for other: Node in bricks_container.get_children():
			if other != brick and is_instance_valid(other) and other is Brick:
				var other_brick: Brick = other
				if not other_brick.is_broken_state and other_brick.global_position.distance_to(brick.global_position) <= 105.0:
					other_brick.call_deferred("take_hit", false, blast_dmg)

	if game_mode == "MODERN":
		var base_exp: int = 16 if brick.brick_type == "ARMORED" else (13 if brick.brick_type == "EXPLOSIVE" else 9)
		var final_exp: int = int(round(float(base_exp) * run_exp_mult))
		_add_modern_exp(final_exp)
	else:
		if not is_transitioning:
			var armored_left: int = _count_armored_bricks()
			if randf() <= DDAManager.get_powerup_drop_chance(armored_left):
				var pu: PowerUp = powerup_scene.instantiate() as PowerUp
				drops_container.add_child(pu)
				pu.setup(DDAManager.pick_weighted_powerup(), brick.global_position)
				pu.collected.connect(_on_powerup_collected)

	_update_hud()
	_check_stage_cleared()

func _add_modern_exp(amount: int) -> void:
	if game_mode != "MODERN" or is_in_menu:
		return
	run_exp += amount
	while run_exp >= run_exp_to_next:
		run_exp -= run_exp_to_next
		run_level += 1
		run_exp_to_next = int(round(float(run_exp_to_next) * 1.38)) + 35
		pending_level_ups += 1

	_update_hud()

	if pending_level_ups > 0 and not card_draft_panel.visible and not is_transitioning:
		_trigger_modern_level_up_draft()

func _trigger_modern_level_up_draft() -> void:
	if pending_level_ups <= 0 or is_in_menu:
		return
	pending_level_ups -= 1
	Engine.time_scale = 1.0
	slowmo_overlay.visible = false
	AudioHapticManager.play_level_up()
	paddle.set_mood("happy", 1.2)
	get_tree().paused = true
	_open_card_draft()

func _roll_card_tier() -> String:
	var gold_chance: float = clamp(0.04 + float(run_level - 1) * 0.015, 0.04, 0.18)
	var silver_chance: float = clamp(0.22 + float(run_level - 1) * 0.018, 0.22, 0.36)
	var r: float = randf()
	if r < gold_chance:
		return "GOLD"
	elif r < gold_chance + silver_chance:
		return "SILVER"
	return "BRONZE"

func _build_tiered_card(arch: String, tier: String) -> Dictionary:
	match arch:
		"DMG_UP":
			if tier == "BRONZE":
				return {
					"id": "DMG_UP",
					"tier": "BRONZE",
					"dmg_add": 1,
					"paddle_w_add": 0.0,
					"title": "Saldırı Gücü Kristali",
					"stat_line": "+1 Çekirdek Hasarı",
					"drawback": ""
				}
			elif tier == "SILVER":
				return {
					"id": "DMG_UP",
					"tier": "SILVER",
					"dmg_add": 2,
					"paddle_w_add": -10.0,
					"title": "Saldırı Gücü Kristali",
					"stat_line": "+2 Çekirdek Hasarı",
					"drawback": "Bedel: -10px Raket"
				}
			else:
				return {
					"id": "DMG_UP",
					"tier": "GOLD",
					"dmg_add": 3,
					"paddle_w_add": -18.0,
					"title": "Yıkım Kristali",
					"stat_line": "+3 Çekirdek Hasarı",
					"drawback": "Bedel: -18px Raket"
				}

		"WIDE_PADDLE":
			if tier == "BRONZE":
				return {
					"id": "WIDE_PADDLE",
					"tier": "BRONZE",
					"paddle_w_add": 16.0,
					"speed_mult_add": 0.0,
					"title": "Kalkan Kristali",
					"stat_line": "+16px Raket Genişliği",
					"drawback": ""
				}
			elif tier == "SILVER":
				return {
					"id": "WIDE_PADDLE",
					"tier": "SILVER",
					"paddle_w_add": 28.0,
					"speed_mult_add": -0.04,
					"title": "Ağır Kalkan Kristali",
					"stat_line": "+28px Raket Genişliği",
					"drawback": "Bedel: -%4 Top Hızı"
				}
			else:
				return {
					"id": "WIDE_PADDLE",
					"tier": "GOLD",
					"paddle_w_add": 42.0,
					"speed_mult_add": -0.07,
					"title": "Kale Duvarı Kristali",
					"stat_line": "+42px Raket Genişliği",
					"drawback": "Bedel: -%7 Top Hızı"
				}

		"LASER_TURRET":
			if tier == "BRONZE":
				return {
					"id": "LASER_TURRET",
					"tier": "BRONZE",
					"interval": 1.15,
					"paddle_w_add": 0.0,
					"title": "Işın Taret Kristali",
					"stat_line": "1.15s İkiz Lazer",
					"drawback": ""
				}
			elif tier == "SILVER":
				return {
					"id": "LASER_TURRET",
					"tier": "SILVER",
					"interval": 0.85,
					"paddle_w_add": -8.0,
					"title": "Seri Lazer Kristali",
					"stat_line": "0.85s İkiz Lazer",
					"drawback": "Bedel: -8px Raket"
				}
			else:
				return {
					"id": "LASER_TURRET",
					"tier": "GOLD",
					"interval": 0.60,
					"paddle_w_add": -14.0,
					"title": "Hiper Lazer Kristali",
					"stat_line": "0.60s İkiz Lazer",
					"drawback": "Bedel: -14px Raket"
				}

		"MULTI_BALL":
			if tier == "BRONZE":
				return {
					"id": "MULTI_BALL",
					"tier": "BRONZE",
					"balls_add": 1,
					"dmg_add": 0,
					"paddle_w_add": -8.0,
					"title": "İkiz Çekirdek Kristali",
					"stat_line": "+1 Kalıcı Enerji Topu",
					"drawback": "Bedel: -8px Raket"
				}
			elif tier == "SILVER":
				return {
					"id": "MULTI_BALL",
					"tier": "SILVER",
					"balls_add": 1,
					"dmg_add": 0,
					"paddle_w_add": 0.0,
					"title": "Saf İkiz Kristal",
					"stat_line": "+1 Kalıcı Enerji Topu",
					"drawback": ""
				}
			else:
				return {
					"id": "MULTI_BALL",
					"tier": "GOLD",
					"balls_add": 2,
					"dmg_add": -1,
					"paddle_w_add": -12.0,
					"title": "Kaos Sürüsü Kristali",
					"stat_line": "+2 Kalıcı Enerji Topu",
					"drawback": "Bedel: -1 Hasar & -12px"
				}

		"SPEED_UP":
			var pct: int = 8 if tier == "BRONZE" else (15 if tier == "SILVER" else 24)
			var drawback_str: String = "" if tier == "BRONZE" else ("Bedel: -8px Raket" if tier == "SILVER" else "Bedel: -14px Raket")
			var w_pen: float = 0.0 if tier == "BRONZE" else (-8.0 if tier == "SILVER" else -14.0)
			return {
				"id": "SPEED_UP",
				"tier": tier,
				"speed_mult_add": float(pct) / 100.0,
				"paddle_w_add": w_pen,
				"title": "İvme Kristali",
				"stat_line": "+%%%d Top Hızı" % pct,
				"drawback": drawback_str
			}

		"HEAL":
			if tier == "BRONZE":
				return {
					"id": "HEAL",
					"tier": "BRONZE",
					"heal_amt": 1,
					"gold_mult_add": 0.0,
					"title": "Can Kristali",
					"stat_line": "+1 Can Yenileme",
					"drawback": ""
				}
			elif tier == "SILVER":
				return {
					"id": "HEAL",
					"tier": "SILVER",
					"heal_amt": 1,
					"gold_mult_add": 0.10,
					"title": "Can & Hurda Kristali",
					"stat_line": "+1 Can & +%10 Altın",
					"drawback": ""
				}
			else:
				return {
					"id": "HEAL",
					"tier": "GOLD",
					"heal_amt": 2,
					"gold_mult_add": -0.15,
					"title": "Yaşam Özü Kristali",
					"stat_line": "+2 Can Yenileme",
					"drawback": "Bedel: -%15 Altın Kazancı"
				}

		"GOLD_RUSH":
			var g_pct: int = 20 if tier == "BRONZE" else (40 if tier == "SILVER" else 75)
			var w_pen: float = 0.0 if tier == "BRONZE" else (-10.0 if tier == "SILVER" else -18.0)
			var db_txt: String = "" if tier == "BRONZE" else ("Bedel: -10px Raket" if tier == "SILVER" else "Bedel: -18px Raket")
			return {
				"id": "GOLD_RUSH",
				"tier": tier,
				"gold_mult_add": float(g_pct) / 100.0,
				"paddle_w_add": w_pen,
				"title": "Hazine Kristali",
				"stat_line": "+%%%d Altın Kazancı" % g_pct,
				"drawback": db_txt
			}

		"EXP_BOOST":
			var e_pct: int = 18 if tier == "BRONZE" else (35 if tier == "SILVER" else 60)
			var db_txt: String = "" if tier != "GOLD" else "Bedel: +%6 Top Hızı"
			var spd_pen: float = 0.0 if tier != "GOLD" else 0.06
			return {
				"id": "EXP_BOOST",
				"tier": tier,
				"exp_mult_add": float(e_pct) / 100.0,
				"speed_mult_add": spd_pen,
				"title": "Bilgelik Kristali",
				"stat_line": "+%%%d EXP Kazancı" % e_pct,
				"drawback": db_txt
			}

		_:
			var dur: float = 4.5 if tier == "BRONZE" else (7.5 if tier == "SILVER" else 11.0)
			return {
				"id": "GHOST_PULSE",
				"tier": tier,
				"ghost_dur": dur,
				"title": "Büyü Nüfuzu Kristali",
				"stat_line": "%.1fs Faz Delici (1.5x)" % dur,
				"drawback": "Dalga Başı +1.5s Faz"
			}

func _open_card_draft() -> void:
	for c: Node in card_row_box.get_children():
		c.queue_free()

	lbl_card_title.text = "SEVİYE %d • YETENEK KARTI SEÇ" % run_level

	var pool: Array[String] = CARD_ARCHETYPES.duplicate()
	pool.shuffle()

	for i: int in range(3):
		var arch: String = pool[i]
		var tier: String = _roll_card_tier()
		var card_data: Dictionary = _build_tiered_card(arch, tier)

		var card_btn: TieredCardButton = TieredCardButton.new()
		card_row_box.add_child(card_btn)
		card_btn.setup(card_data, i)
		card_btn.card_chosen.connect(_on_tiered_card_chosen)

	card_draft_panel.visible = true

func _on_tiered_card_chosen(card_data: Dictionary) -> void:
	var tier: String = str(card_data.get("tier", "BRONZE"))
	AudioHapticManager.play_card_select(tier)
	_apply_roguelite_card(card_data)
	card_draft_panel.visible = false

	if pending_level_ups > 0:
		_trigger_modern_level_up_draft()
	else:
		get_tree().paused = false
		paddle.set_input_active(true, 0.15)
		_update_hud()

func _apply_roguelite_card(card_data: Dictionary) -> void:
	var card_id: String = str(card_data.get("id", ""))

	if card_data.has("paddle_w_add"):
		run_bonus_paddle_w += float(card_data["paddle_w_add"])
		paddle.apply_meta_stats(run_bonus_paddle_w)

	if card_data.has("dmg_add"):
		run_bonus_damage = maxi(0, run_bonus_damage + int(card_data["dmg_add"]))

	if card_data.has("speed_mult_add"):
		var s_add: float = float(card_data["speed_mult_add"])
		if s_add != 0.0:
			run_bonus_speed_mult = clamp(run_bonus_speed_mult + s_add, 0.75, 1.85)
			for child: Node in balls_container.get_children():
				if child is Ball:
					var b: Ball = child
					b.speed *= (1.0 + s_add)
					if not b.is_attached:
						b.velocity = b.velocity.normalized() * b.speed

	if card_data.has("gold_mult_add"):
		run_gold_mult = max(0.5, run_gold_mult + float(card_data["gold_mult_add"]))

	if card_data.has("exp_mult_add"):
		run_exp_mult += float(card_data["exp_mult_add"])

	match card_id:
		"LASER_TURRET":
			run_has_laser = true
			run_laser_interval = min(run_laser_interval, float(card_data.get("interval", 1.15)))
			paddle.permanent_laser = true
			paddle.laser_fire_interval = run_laser_interval
		"MULTI_BALL":
			var add_count: int = int(card_data.get("balls_add", 1))
			run_extra_balls += add_count
			var existing: Array[Node] = balls_container.get_children()
			if existing.size() > 0 and existing[0] is Ball:
				var ref_ball: Ball = existing[0] as Ball
				if not ref_ball.is_attached:
					for k: int in range(add_count):
						var nb: Ball = ball_scene.instantiate() as Ball
						balls_container.add_child(nb)
						nb.global_position = ref_ball.global_position
						nb.speed = ref_ball.speed
						if ref_ball.is_ghost:
							nb.activate_ghost(ref_ball.ghost_timer)
						nb.is_attached = false
						var spread: float = (-20.0 + float(k) * 20.0) if add_count > 1 else 22.0
						nb.velocity = ref_ball.velocity.rotated(deg_to_rad(spread))
						nb.ball_lost.connect(_on_ball_lost)
						nb.brick_hit_event.connect(_on_ball_brick_hit)
		"HEAL":
			lives = mini(4, lives + int(card_data.get("heal_amt", 1)))
		"GHOST_PULSE":
			var dur: float = float(card_data.get("ghost_dur", 4.5))
			run_ghost_duration_bonus = min(6.0, run_ghost_duration_bonus + 1.5)
			for child: Node in balls_container.get_children():
				if child is Ball:
					(child as Ball).activate_ghost(dur)

func _on_rogue_brick_hit_paddle(_brick: Brick) -> void:
	if is_in_menu or is_transitioning:
		return
	remaining_breakable_bricks = maxi(0, remaining_breakable_bricks - 1)
	lives -= 1
	paddle.set_mood("shocked", 1.0)
	add_screen_shake(18.0)
	AudioHapticManager.trigger_haptic(50)
	_update_hud()
	if lives <= 0:
		_trigger_game_over()
	else:
		_check_stage_cleared()

func _check_stage_cleared() -> void:
	if is_in_menu or is_transitioning:
		return

	if is_defense_wave:
		if defense_bricks_to_spawn <= 0 and bricks_container.get_child_count() <= 1 and remaining_breakable_bricks <= 0:
			_handle_modern_wave_completed()
		return

	var alive_breakable: int = 0
	for child: Node in bricks_container.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and child is Brick:
			var b: Brick = child
			if b.brick_type != "UNBREAKABLE" and not b.is_broken_state:
				alive_breakable += 1

	if remaining_breakable_bricks <= 0 or alive_breakable == 0:
		if game_mode == "CLASSIC":
			_handle_classic_level_completed()
		else:
			_handle_modern_wave_completed()

func _handle_classic_level_completed() -> void:
	is_transitioning = true
	Engine.time_scale = 1.0
	slowmo_overlay.visible = false
	paddle.set_input_active(false)
	paddle.reset_all_states()
	_clear_entities()
	AudioHapticManager.play_wave_clear()
	paddle.set_mood("happy", 1.5)

	var completed_lvl: int = current_classic_level
	var newly_unlocked: bool = GameData.unlock_next_classic_level(completed_lvl)
	var bonus_coins: int = 30 + completed_lvl * 5
	GameData.add_coins(bonus_coins)
	GameData.update_records(score, completed_lvl)

	lbl_wave_banner.text = "BÖLÜM %d TAMAMLANDI!
+%d ALTIN" % [completed_lvl, bonus_coins]
	lbl_wave_banner.modulate = Color(1, 1, 1, 0)
	lbl_wave_banner.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(lbl_wave_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.95)
	tw.tween_property(lbl_wave_banner, "modulate:a", 0.0, 0.25)
	await tw.finished

	if newly_unlocked:
		_open_level_tree(completed_lvl, completed_lvl + 1)
	else:
		_open_level_tree(-1, -1)

func _handle_modern_wave_completed() -> void:
	is_transitioning = true
	Engine.time_scale = 1.0
	slowmo_overlay.visible = false
	paddle.set_input_active(false)
	_clear_entities()
	AudioHapticManager.play_wave_clear()
	paddle.set_mood("happy", 1.2)
	var bonus_gold: int = int(round(float(16 + wave * 3) * run_gold_mult))
	GameData.add_coins(bonus_gold)
	GameData.update_records(score, wave)

	if not GameData.is_pro and wave % 2 == 0:
		lbl_ad_info.text = "DALGA %d TAMAMLANDI!

Sponsor Reklam Arası (Ücretsiz Sürüm)
Pro Sürüm ile reklamları kalıcı olarak kapatabilirsiniz." % wave
		ad_break_panel.visible = true
	else:
		_advance_to_next_modern_wave()

func _on_btn_skip_ad_pressed() -> void:
	AudioHapticManager.play_ui_click()
	ad_break_panel.visible = false
	_advance_to_next_modern_wave()

func _advance_to_next_modern_wave() -> void:
	wave += 1
	DDAManager.register_wave_cleared(wave)
	is_transitioning = false
	_update_hud()
	_start_modern_wave(wave)

func _count_armored_bricks() -> int:
	var c: int = 0
	for child: Node in bricks_container.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and child is Brick:
			var b: Brick = child
			if b.brick_type == "ARMORED" and not b.is_broken_state:
				c += 1
	return c

func _on_powerup_collected(skill_type: String) -> void:
	if game_mode != "CLASSIC" or is_in_menu or is_transitioning or not paddle.input_enabled:
		return
	score += 50
	match skill_type:
		"GHOST":
			for child: Node in balls_container.get_children():
				if child is Ball:
					(child as Ball).activate_ghost(5.5)
		"SLOW_MO":
			slow_mo_timer = 5.0
		"TRI_BALL":
			var existing: Array[Node] = balls_container.get_children()
			if existing.size() > 0 and existing[0] is Ball:
				var ref_ball: Ball = existing[0] as Ball
				var angles: Array[float] = [-28.0, 28.0]
				for angle_deg: float in angles:
					var nb: Ball = ball_scene.instantiate() as Ball
					balls_container.add_child(nb)
					nb.global_position = ref_ball.global_position
					nb.is_attached = false
					nb.velocity = ref_ball.velocity.rotated(deg_to_rad(angle_deg))
					if ref_ball.is_ghost:
						nb.activate_ghost(ref_ball.ghost_timer)
					nb.ball_lost.connect(_on_ball_lost)
					nb.brick_hit_event.connect(_on_ball_brick_hit)
		"WIDE":
			paddle.activate_wide(10.0)
		"LASER":
			paddle.activate_laser(8.0)
	_update_hud()

func _on_ball_lost(ball: Ball) -> void:
	ball.queue_free()
	await get_tree().process_frame
	if is_in_menu or is_transitioning:
		return
	if balls_container.get_child_count() == 0:
		lives -= 1
		DDAManager.register_ball_missed(lives)
		AudioHapticManager.reset_combo()
		paddle.set_mood("shocked", 1.1)
		add_screen_shake(14.0)
		_update_hud()
		if lives <= 0:
			_trigger_game_over()
		else:
			_spawn_attached_ball()

func _trigger_game_over() -> void:
	is_in_menu = true
	is_game_paused = false
	get_tree().paused = false
	paddle.set_input_active(false)
	paddle.reset_all_states()
	is_defense_wave = false
	slow_mo_timer = 0.0
	Engine.time_scale = 1.0
	slowmo_overlay.visible = false
	lbl_aim_hint.visible = false
	exp_bar_container.visible = false
	_clear_entities()

	var stage_val: int = current_classic_level if game_mode == "CLASSIC" else wave
	GameData.update_records(score, stage_val)
	if game_mode == "CLASSIC":
		$UI/GameOverPanel/VBox/LblFinalStats.text = "SKOR: %d  |  BÖLÜM %d
EN YÜKSEK SKOR: %d" % [score, current_classic_level, GameData.high_score]
	else:
		$UI/GameOverPanel/VBox/LblFinalStats.text = "SKOR: %d  |  DALGA %d (SV.%d)
EN YÜKSEK SKOR: %d" % [score, wave, run_level, GameData.high_score]
	game_over_panel.visible = true

func _process(delta: float) -> void:
	if is_in_menu or is_transitioning or is_game_paused or get_tree().paused:
		camera.offset = Vector2.ZERO
		return

	if is_defense_wave:
		defense_spawn_timer -= delta
		if defense_spawn_timer <= 0.0 and defense_bricks_to_spawn > 0:
			defense_bricks_to_spawn -= 1
			defense_spawn_timer = max(0.30, 0.78 - float(wave) * 0.012)
			var ang: float = randf() * TAU
			var spawn_pos: Vector2 = Vector2(360.0, 640.0) + Vector2.from_angle(ang) * 560.0
			var br: Brick = brick_scene.instantiate() as Brick
			bricks_container.add_child(br)
			br.setup_rogue_attacker(spawn_pos, Vector2(360.0, 640.0), wave)
			br.destroyed.connect(_on_brick_destroyed)
			br.reached_center_paddle.connect(_on_rogue_brick_hit_paddle)

	if balls_container.get_child_count() > 0:
		var first_ball: Node = balls_container.get_child(0)
		if is_instance_valid(first_ball) and first_ball is Node2D:
			var fb2d: Node2D = first_ball
			paddle.look_target_x = fb2d.global_position.x

	if slow_mo_timer > 0.0:
		slow_mo_timer -= delta / max(Engine.time_scale, 0.1)

	# Basılı tutunca normal hız (1.0), parmağı çekince taktiksel Slow-Mo (0.42)
	var target_ts: float = 1.0
	if slow_mo_timer > 0.0:
		target_ts = 0.45
	elif not is_defense_wave and not paddle.has_ball_attached and not paddle.is_holding_paddle:
		target_ts = 0.42

	Engine.time_scale = lerp(Engine.time_scale, target_ts, min(1.0, (delta / max(Engine.time_scale, 0.1)) * 12.0))
	slowmo_overlay.visible = (Engine.time_scale < 0.78)

	if shake_strength > 0.0:
		shake_strength = lerp(shake_strength, 0.0, 12.0 * delta)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	else:
		camera.offset = Vector2.ZERO

func add_screen_shake(amount: float) -> void:
	shake_strength = min(shake_strength + amount, 22.0)

func _update_hud() -> void:
	lbl_score.text = "SKOR: %d" % score
	if game_mode == "CLASSIC":
		lbl_wave.text = "BÖLÜM %d" % current_classic_level
	else:
		lbl_wave.text = "DALGA %d" % wave
		lbl_run_level.text = "SV.%d" % run_level
		exp_progress.max_value = float(run_exp_to_next)
		exp_progress.value = float(run_exp)
		lbl_exp_text.text = "%d / %d EXP" % [run_exp, run_exp_to_next]
	lbl_coins.text = "ALTIN: %d" % GameData.coins
	lbl_lives.text = "CAN: %d" % lives

# --- OYUN İÇİ DURDURMA (PAUSE) ---
func _on_btn_pause_pressed() -> void:
	if is_in_menu or is_transitioning or card_draft_panel.visible:
		return
	AudioHapticManager.play_ui_click()
	is_game_paused = true
	Engine.time_scale = 1.0
	slowmo_overlay.visible = false
	paddle.is_dragging = false
	paddle.is_holding_paddle = false
	get_tree().paused = true
	pause_panel.visible = true

func _on_btn_resume_pressed() -> void:
	AudioHapticManager.play_ui_click()
	pause_panel.visible = false
	is_game_paused = false
	get_tree().paused = false
	paddle.set_input_active(true, 0.15)

func _on_btn_pause_settings_pressed() -> void:
	AudioHapticManager.play_ui_click()
	slider_sfx.value = GameData.sfx_volume * 100.0
	lbl_sfx_val.text = "%%%d" % int(round(GameData.sfx_volume * 100.0))
	btn_haptic_toggle.button_pressed = GameData.haptic_enabled
	settings_panel.visible = true

func _on_btn_pause_restart_pressed() -> void:
	AudioHapticManager.play_ui_click()
	pause_panel.visible = false
	is_game_paused = false
	get_tree().paused = false
	if game_mode == "CLASSIC":
		_start_gameplay_session()
	else:
		_start_modern_run()

func _on_btn_pause_menu_pressed() -> void:
	AudioHapticManager.play_ui_click()
	_show_main_menu()

# --- MENÜ & MAĞAZA BUTONLARI ---
func _on_btn_play_pressed() -> void:
	AudioHapticManager.play_ui_click()
	main_menu_panel.visible = false
	mode_select_panel.visible = true

func _on_btn_mode_classic_pressed() -> void:
	AudioHapticManager.play_ui_click()
	_open_level_tree(-1, -1)

func _on_btn_mode_modern_pressed() -> void:
	AudioHapticManager.play_ui_click()
	_start_modern_run()

func _on_btn_back_from_mode_pressed() -> void:
	AudioHapticManager.play_ui_click()
	_show_main_menu()

func _on_btn_back_from_tree_pressed() -> void:
	AudioHapticManager.play_ui_click()
	_show_main_menu()

func _on_btn_menu_shop_pressed() -> void:
	AudioHapticManager.play_ui_click()
	shop_panel.visible = true
	_refresh_shop_ui()

func _on_btn_settings_pressed() -> void:
	AudioHapticManager.play_ui_click()
	slider_sfx.value = GameData.sfx_volume * 100.0
	lbl_sfx_val.text = "%%%d" % int(round(GameData.sfx_volume * 100.0))
	btn_haptic_toggle.button_pressed = GameData.haptic_enabled
	settings_panel.visible = true

func _on_slider_sfx_value_changed(val: float) -> void:
	lbl_sfx_val.text = "%%%d" % int(round(val))
	GameData.set_sfx_volume(val / 100.0)

func _on_btn_haptic_toggled(toggled_on: bool) -> void:
	GameData.set_haptic_enabled(toggled_on)
	if toggled_on:
		AudioHapticManager.trigger_haptic(20)

func _on_btn_close_settings_pressed() -> void:
	AudioHapticManager.play_ui_click()
	settings_panel.visible = false

func _on_btn_restart_pressed() -> void:
	AudioHapticManager.play_ui_click()
	if game_mode == "CLASSIC":
		_start_gameplay_session()
	else:
		_start_modern_run()

func _on_btn_to_menu_pressed() -> void:
	AudioHapticManager.play_ui_click()
	_show_main_menu()

func _on_btn_continue_pressed() -> void:
	AudioHapticManager.play_ui_click()
	if GameData.coins >= 150:
		GameData.add_coins(-150)
		is_in_menu = false
		is_game_paused = false
		lives = 1
		paddle.reset_all_states()
		_apply_modern_run_upgrades_to_paddle()
		paddle.set_input_active(true, 0.22)
		game_over_panel.visible = false
		if game_mode == "MODERN":
			exp_bar_container.visible = true
		if game_mode == "MODERN" and wave % 10 == 0:
			is_defense_wave = true
			paddle.set_defense_mode(true)
			_start_modern_wave(wave)
		else:
			_load_stage(current_classic_level if game_mode == "CLASSIC" else wave, game_mode == "CLASSIC")
			_spawn_attached_ball()
		_update_hud()

func _on_btn_shop_pressed() -> void:
	AudioHapticManager.play_ui_click()
	shop_panel.visible = true
	if not is_in_menu:
		Engine.time_scale = 1.0
		slowmo_overlay.visible = false
		paddle.is_dragging = false
		paddle.is_holding_paddle = false
		get_tree().paused = true
	_refresh_shop_ui()

func _on_btn_close_shop_pressed() -> void:
	AudioHapticManager.play_ui_click()
	shop_panel.visible = false
	if not is_in_menu:
		if not card_draft_panel.visible and not is_game_paused:
			get_tree().paused = false
			paddle.set_input_active(true, 0.15)
		_apply_modern_run_upgrades_to_paddle()
	else:
		lbl_menu_records.text = "CLASSIC BÖLÜM: %d   |   MODERN REKOR: %d" % [GameData.classic_unlocked_level, GameData.high_score]

func _refresh_shop_ui() -> void:
	for c: Node in shop_list.get_children():
		c.queue_free()

	var coin_header: Label = Label.new()
	coin_header.text = "MEVCUT ALTIN: %d" % GameData.coins
	coin_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_header.add_theme_color_override("font_color", Color("#F6E05E"))
	shop_list.add_child(coin_header)

	var upg_title: Label = Label.new()
	upg_title.text = "— KALICI GELİŞTİRMELER (MODERN & SAVUNMA) —"
	upg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upg_title.add_theme_color_override("font_color", Color("#38F2F6"))
	shop_list.add_child(upg_title)

	var upg_names: Dictionary = {
		"damage": "Çekirdek Hasarı (Her 2 Sv. +1)",
		"paddle_size": "Raket Genişliği (+9px)",
		"fire_rate": "Savunma Taret Hızı",
		"magnet_gold": "Altın Kazanç Çarpanı (+%15)"
	}
	for u_key: String in ["damage", "paddle_size", "fire_rate", "magnet_gold"]:
		var lvl: int = int(GameData.meta_upgrades.get(u_key, 1))
		var cost: int = GameData.get_meta_upgrade_cost(u_key)
		var u_btn: Button = Button.new()
		u_btn.custom_minimum_size = Vector2(0, 44)
		if lvl >= 10:
			u_btn.text = "%s (Sv.%d)  [MAKSİMUM]" % [upg_names[u_key], lvl]
		else:
			u_btn.text = "%s (Sv.%d -> %d)  —  %d ALTIN" % [upg_names[u_key], lvl, lvl + 1, cost]
		u_btn.pressed.connect(func() -> void:
			AudioHapticManager.play_ui_click()
			if GameData.buy_meta_upgrade(u_key):
				_refresh_shop_ui()
		)
		shop_list.add_child(u_btn)

	var skin_title: Label = Label.new()
	skin_title.text = "— KARAKTER & RAKET KOZMETİKLERİ —"
	skin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skin_title.add_theme_color_override("font_color", Color("#38F2F6"))
	shop_list.add_child(skin_title)

	for skin_key: Variant in GameData.skins.keys():
		var skin_id: String = str(skin_key)
		var data: Dictionary = GameData.skins[skin_id]
		var skin_name: String = str(data["name"])
		var skin_price: int = int(data["price"])
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		if GameData.active_skin == skin_id:
			btn.text = "%s  [SEÇİLİ]" % skin_name
		elif skin_id in GameData.unlocked_skins:
			btn.text = "%s  [KUŞAN]" % skin_name
		else:
			btn.text = "%s  —  %d ALTIN" % [skin_name, skin_price]
		btn.pressed.connect(func() -> void:
			AudioHapticManager.play_ui_click()
			if GameData.buy_or_equip_skin(skin_id):
				_refresh_shop_ui()
		)
		shop_list.add_child(btn)

	var pro_btn: Button = Button.new()
	pro_btn.custom_minimum_size = Vector2(0, 50)
	pro_btn.text = "PRO SÜRÜM (REKLAMSIZ) [AKTİF]" if GameData.is_pro else "PRO SÜRÜM SATIN AL (REKLAMSIZ DENEYİM)"
	pro_btn.pressed.connect(func() -> void:
		AudioHapticManager.play_ui_click()
		GameData.unlock_pro_version()
		_refresh_shop_ui()
	)
	shop_list.add_child(pro_btn)
