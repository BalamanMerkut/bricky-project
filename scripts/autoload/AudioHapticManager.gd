extends Node

const PENTATONIC_RATIOS: Array[float] = [
	1.0,
	1.12246,
	1.25992,
	1.49831,
	1.68179,
	2.0,
	2.24492,
	2.51984,
	2.99661
]

var combo_step: int = 0
var sfx_players: Array[AudioStreamPlayer] = []
var pool_size: int = 12
var pool_index: int = 0

var stream_brick_normal: AudioStreamWAV
var stream_brick_armored: AudioStreamWAV
var stream_brick_unbreakable: AudioStreamWAV
var stream_paddle: AudioStreamWAV
var stream_powerup: AudioStreamWAV
var stream_explosion: AudioStreamWAV
var stream_wave_clear: AudioStreamWAV
var stream_turret_shot: AudioStreamWAV
var stream_level_up: AudioStreamWAV

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(pool_size):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
	_generate_procedural_sounds()
	_apply_volume_setting()
	GameData.settings_changed.connect(_apply_volume_setting)

func _apply_volume_setting() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if GameData.sfx_volume <= 0.01:
		AudioServer.set_bus_mute(master_idx, true)
	else:
		AudioServer.set_bus_mute(master_idx, false)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(GameData.sfx_volume))

func _generate_procedural_sounds() -> void:
	stream_brick_normal = _create_tone(523.25, 0.11, "sine", 0.35)
	stream_brick_armored = _create_tone(880.0, 0.09, "triangle", 0.4)
	stream_brick_unbreakable = _create_tone(196.0, 0.14, "square", 0.25)
	stream_paddle = _create_tone(329.63, 0.08, "sine", 0.35)
	stream_turret_shot = _create_tone(660.0, 0.06, "triangle", 0.28)
	var chime_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	stream_powerup = _create_chime(chime_freqs, 0.26)
	var clear_freqs: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
	stream_wave_clear = _create_chime(clear_freqs, 0.45)
	var lvl_freqs: Array[float] = [440.0, 554.37, 659.25, 880.0, 1108.73, 1318.5]
	stream_level_up = _create_chime(lvl_freqs, 0.52)
	stream_explosion = _create_noise_burst(0.28, 0.45)

func _create_tone(freq: float, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	for i: int in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = pow(1.0 - (float(i) / float(num_samples)), 1.8)
		var s: float = 0.0
		match wave_type:
			"sine":
				s = sin(TAU * freq * t)
			"triangle":
				s = 2.0 * abs(2.0 * (t * freq - floor(t * freq + 0.5))) - 1.0
			"square":
				s = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		var sample_val: int = int(clamp(s * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_val)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_chime(freqs: Array[float], duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var step_len: int = maxi(1, num_samples / freqs.size())
	for i: int in range(num_samples):
		var idx: int = mini(i / step_len, freqs.size() - 1)
		var freq: float = freqs[idx]
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (float(i) / float(num_samples))
		var s: float = sin(TAU * freq * t) * env * 0.38
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	for i: int in range(num_samples):
		var env: float = pow(1.0 - (float(i) / float(num_samples)), 2.2)
		var s: float = randf_range(-1.0, 1.0) * env * volume
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _play_stream(stream: AudioStreamWAV, pitch: float = 1.0, db: float = 0.0) -> void:
	if stream == null or GameData.sfx_volume <= 0.01:
		return
	var player: AudioStreamPlayer = sfx_players[pool_index]
	pool_index = (pool_index + 1) % pool_size
	player.stream = stream
	var skin_dict: Dictionary = GameData.get_current_skin_data()
	var skin_pitch: float = float(skin_dict.get("pitch_offset", 1.0))
	player.pitch_scale = pitch * skin_pitch
	player.volume_db = db
	player.play()

func reset_combo() -> void:
	combo_step = 0

func play_brick_hit(brick_type: String, broken: bool) -> void:
	match brick_type:
		"UNBREAKABLE":
			_play_stream(stream_brick_unbreakable, randf_range(0.95, 1.05), -2.0)
			trigger_haptic(18)
		"ARMORED":
			if broken:
				var ratio: float = PENTATONIC_RATIOS[mini(combo_step, PENTATONIC_RATIOS.size() - 1)]
				combo_step += 1
				_play_stream(stream_brick_normal, ratio * 0.9, 1.0)
				trigger_haptic(25)
			else:
				_play_stream(stream_brick_armored, randf_range(0.95, 1.1), -1.0)
				trigger_haptic(15)
		"EXPLOSIVE":
			combo_step += 2
			_play_stream(stream_explosion, 1.0, 2.0)
			trigger_haptic(45)
		_:
			var ratio: float = PENTATONIC_RATIOS[mini(combo_step, PENTATONIC_RATIOS.size() - 1)]
			combo_step += 1
			_play_stream(stream_brick_normal, ratio, 0.0)
			trigger_haptic(12)

func play_paddle_hit() -> void:
	reset_combo()
	_play_stream(stream_paddle, randf_range(0.96, 1.04), -1.0)
	trigger_haptic(10)

func play_turret_shot() -> void:
	_play_stream(stream_turret_shot, randf_range(0.92, 1.08), -2.0)
	trigger_haptic(8)

func play_powerup() -> void:
	_play_stream(stream_powerup, 1.0, 1.0)
	trigger_haptic(30)

func play_wave_clear() -> void:
	_play_stream(stream_wave_clear, 1.0, 2.0)
	trigger_haptic(40)

func play_level_up() -> void:
	_play_stream(stream_level_up, 1.0, 2.5)
	trigger_haptic(50)

func play_card_select(tier: String) -> void:
	var p: float = 1.0 if tier == "BRONZE" else (1.18 if tier == "SILVER" else 1.38)
	_play_stream(stream_powerup, p, 2.0)
	trigger_haptic(35)

func play_ui_click() -> void:
	_play_stream(stream_paddle, 1.35, -3.0)
	trigger_haptic(8)

func trigger_haptic(duration_ms: int) -> void:
	if GameData.haptic_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
