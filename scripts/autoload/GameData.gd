extends Node

signal coins_changed(new_amount: int)
signal skin_changed(skin_id: String)
signal pro_status_changed(is_pro: bool)
signal settings_changed
signal upgrades_changed

const SAVE_PATH: String = "user://bricky_save.json"
const GAME_VERSION: String = "v0.9.0-alpha"

var coins: int = 350
var high_score: int = 0
var highest_wave: int = 1
var classic_unlocked_level: int = 1
var is_pro: bool = false
var active_skin: String = "merküt_turquoise"
var unlocked_skins: Array = ["merküt_turquoise"]

var sfx_volume: float = 0.85
var haptic_enabled: bool = true

var meta_upgrades: Dictionary = {
	"damage": 1,
	"paddle_size": 1,
	"fire_rate": 1,
	"magnet_gold": 1
}

var skins: Dictionary = {
	"merküt_turquoise": {
		"name": "Merküt Turkuaz",
		"price": 0,
		"paddle_color": Color("#00A3A6"),
		"accent_color": Color("#E2F8F9"),
		"ball_color": Color("#38F2F6"),
		"trail_color": Color(0.0, 0.64, 0.65, 0.55),
		"pitch_offset": 1.0
	},
	"cyber_crimson": {
		"name": "Siber Kızıl",
		"price": 500,
		"paddle_color": Color("#E53E3E"),
		"accent_color": Color("#FED7D7"),
		"ball_color": Color("#FC8181"),
		"trail_color": Color(0.9, 0.24, 0.24, 0.55),
		"pitch_offset": 1.12
	},
	"royal_gold": {
		"name": "Altın İmparator",
		"price": 1200,
		"paddle_color": Color("#D69E2E"),
		"accent_color": Color("#FEFCBF"),
		"ball_color": Color("#F6E05E"),
		"trail_color": Color(0.84, 0.62, 0.18, 0.55),
		"pitch_offset": 0.94
	},
	"void_amethyst": {
		"name": "Gölge Ametist",
		"price": 2500,
		"paddle_color": Color("#805AD5"),
		"accent_color": Color("#E9D8FD"),
		"ball_color": Color("#B794F4"),
		"trail_color": Color(0.5, 0.35, 0.83, 0.55),
		"pitch_offset": 1.25
	}
}

func _ready() -> void:
	load_game()

func get_current_skin_data() -> Dictionary:
	return skins.get(active_skin, skins["merküt_turquoise"])

func add_coins(amount: int) -> void:
	var mult: float = 1.0 + (int(meta_upgrades.get("magnet_gold", 1)) - 1) * 0.15
	var final_amt: int = amount if amount < 0 else int(round(float(amount) * mult))
	coins += final_amt
	emit_signal("coins_changed", coins)
	save_game()

func unlock_next_classic_level(completed_lvl: int) -> bool:
	if completed_lvl >= classic_unlocked_level:
		classic_unlocked_level = completed_lvl + 1
		save_game()
		return true
	return false

func get_meta_upgrade_cost(key: String) -> int:
	var lvl: int = int(meta_upgrades.get(key, 1))
	return 200 * lvl * lvl

func buy_meta_upgrade(key: String) -> bool:
	if not meta_upgrades.has(key):
		return false
	var lvl: int = int(meta_upgrades[key])
	if lvl >= 10:
		return false
	var cost: int = get_meta_upgrade_cost(key)
	if coins >= cost:
		coins -= cost
		meta_upgrades[key] = lvl + 1
		emit_signal("coins_changed", coins)
		emit_signal("upgrades_changed")
		save_game()
		return true
	return false

func set_sfx_volume(val: float) -> void:
	sfx_volume = clamp(val, 0.0, 1.0)
	emit_signal("settings_changed")
	save_game()

func set_haptic_enabled(enabled: bool) -> void:
	haptic_enabled = enabled
	emit_signal("settings_changed")
	save_game()

func buy_or_equip_skin(skin_id: String) -> bool:
	if not skins.has(skin_id):
		return false
	if skin_id in unlocked_skins:
		active_skin = skin_id
		emit_signal("skin_changed", active_skin)
		save_game()
		return true
	var skin_dict: Dictionary = skins[skin_id]
	var price: int = int(skin_dict["price"])
	if coins >= price:
		coins -= price
		unlocked_skins.append(skin_id)
		active_skin = skin_id
		emit_signal("coins_changed", coins)
		emit_signal("skin_changed", active_skin)
		save_game()
		return true
	return false

func unlock_pro_version() -> void:
	is_pro = true
	emit_signal("pro_status_changed", true)
	save_game()

func update_records(score_val: int, wave_val: int) -> void:
	if score_val > high_score:
		high_score = score_val
	if wave_val > highest_wave:
		highest_wave = wave_val
	save_game()

func save_game() -> void:
	var data: Dictionary = {
		"coins": coins,
		"high_score": high_score,
		"highest_wave": highest_wave,
		"classic_unlocked_level": classic_unlocked_level,
		"is_pro": is_pro,
		"active_skin": active_skin,
		"unlocked_skins": unlocked_skins,
		"sfx_volume": sfx_volume,
		"haptic_enabled": haptic_enabled,
		"meta_upgrades": meta_upgrades
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			var parsed_dict: Dictionary = parsed
			coins = int(parsed_dict.get("coins", 350))
			high_score = int(parsed_dict.get("high_score", 0))
			highest_wave = int(parsed_dict.get("highest_wave", 1))
			classic_unlocked_level = int(parsed_dict.get("classic_unlocked_level", 1))
			is_pro = bool(parsed_dict.get("is_pro", false))
			active_skin = str(parsed_dict.get("active_skin", "merküt_turquoise"))
			unlocked_skins = parsed_dict.get("unlocked_skins", ["merküt_turquoise"])
			sfx_volume = float(parsed_dict.get("sfx_volume", 0.85))
			haptic_enabled = bool(parsed_dict.get("haptic_enabled", true))
			var loaded_upg: Variant = parsed_dict.get("meta_upgrades", {})
			if typeof(loaded_upg) == TYPE_DICTIONARY:
				for k: Variant in (loaded_upg as Dictionary).keys():
					meta_upgrades[str(k)] = int((loaded_upg as Dictionary)[k])
