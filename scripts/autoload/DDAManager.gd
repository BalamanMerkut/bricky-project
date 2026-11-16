extends Node

var current_wave: int = 1
var player_lives: int = 3
var recent_misses: int = 0
var bricks_broken_without_miss: int = 0

func reset_session() -> void:
	current_wave = 1
	player_lives = 3
	recent_misses = 0
	bricks_broken_without_miss = 0

func register_brick_broken() -> void:
	bricks_broken_without_miss += 1

func register_ball_missed(remaining_lives: int) -> void:
	player_lives = remaining_lives
	recent_misses += 1
	bricks_broken_without_miss = 0

func register_wave_cleared(new_wave: int) -> void:
	current_wave = new_wave
	recent_misses = maxi(0, recent_misses - 1)

func get_powerup_drop_chance(active_armored_count: int) -> float:
	var base_chance: float = 0.065
	if player_lives == 1:
		base_chance += 0.045
	if recent_misses >= 2:
		base_chance += 0.03
	if active_armored_count >= 6:
		base_chance += 0.02
	if bricks_broken_without_miss > 25 and player_lives >= 3:
		base_chance -= 0.015
	return clamp(base_chance, 0.03, 0.16)

func pick_weighted_powerup() -> String:
	var weights: Dictionary = {
		"GHOST": 20.0,
		"SLOW_MO": 20.0,
		"TRI_BALL": 22.0,
		"WIDE": 20.0,
		"LASER": 18.0
	}
	if player_lives == 1:
		weights["WIDE"] = float(weights["WIDE"]) + 25.0
		weights["SLOW_MO"] = float(weights["SLOW_MO"]) + 20.0
		weights["GHOST"] = float(weights["GHOST"]) + 15.0
	elif bricks_broken_without_miss > 20:
		weights["TRI_BALL"] = float(weights["TRI_BALL"]) + 25.0
		weights["GHOST"] = float(weights["GHOST"]) + 15.0

	var total: float = 0.0
	for w: float in weights.values():
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for skill: String in weights.keys():
		acc += float(weights[skill])
		if roll <= acc:
			return skill
	return "TRI_BALL"

func get_wave_difficulty(wave_num: int, is_modern: bool = false) -> Dictionary:
	var skill_factor: float = clamp(float(bricks_broken_without_miss) / 40.0, 0.0, 0.25)
	var struggle_penalty: float = 0.12 if player_lives == 1 else 0.0

	if is_modern:
		var mod_armored: float = clamp(0.24 + (wave_num * 0.055) + skill_factor - (struggle_penalty * 0.5), 0.18, 0.82)
		var mod_unbreakable: int = mini(int((wave_num + 1) / 2), 3)
		var mod_explosive: float = clamp(0.06, 0.05, 0.10)
		var mod_speed: float = clamp(1.05 + (wave_num - 1) * 0.035 + (skill_factor * 0.25), 1.05, 1.65)
		var hp_scale: float = 1.0 + float(wave_num - 1) * 0.35 + pow(float(maxi(0, wave_num - 3)), 1.35) * 0.22
		return {
			"armored_chance": mod_armored,
			"unbreakable_pairs": mod_unbreakable,
			"explosive_chance": mod_explosive,
			"speed_multiplier": mod_speed,
			"hp_scale": hp_scale
		}

	var armored_chance: float = clamp(0.12 + (wave_num * 0.035) + skill_factor - struggle_penalty, 0.05, 0.55)
	var unbreakable_pairs: int = mini(int(wave_num / 3), 2)
	if player_lives == 1 and wave_num < 5:
		unbreakable_pairs = 0
	var explosive_chance: float = clamp(0.08 + (0.04 if player_lives == 1 else 0.0), 0.06, 0.18)
	var speed_multiplier: float = clamp(1.0 + (wave_num - 1) * 0.025 + (skill_factor * 0.2), 1.0, 1.45)

	return {
		"armored_chance": armored_chance,
		"unbreakable_pairs": unbreakable_pairs,
		"explosive_chance": explosive_chance,
		"speed_multiplier": speed_multiplier,
		"hp_scale": 1.0
	}
