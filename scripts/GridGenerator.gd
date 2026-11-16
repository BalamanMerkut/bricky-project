extends Node
class_name GridGenerator

const COLS: int = 8
const ROWS: int = 6
const BRICK_W: float = 78.0
const BRICK_H: float = 32.0
const GAP: float = 8.0
const START_X: float = 54.0
const START_Y: float = 178.0

func spawn_wave(container: Node2D, level_or_wave: int, brick_scene: PackedScene, is_classic_level: bool = false) -> int:
	for child: Node in container.get_children():
		child.queue_free()

	var armored_chance: float = 0.15
	var explosive_chance: float = 0.08
	var unbreakable_pairs: int = 0
	var empty_skip_chance: float = 0.18

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if is_classic_level:
		rng.seed = hash("MERKUT_CLASSIC_LVL_" + str(level_or_wave))
		armored_chance = clamp(0.10 + float(level_or_wave) * 0.03, 0.10, 0.55)
		explosive_chance = 0.09
		unbreakable_pairs = mini(int(level_or_wave / 3), 2)
	else:
		rng.randomize()
		var diff: Dictionary = DDAManager.get_wave_difficulty(level_or_wave, true)
		armored_chance = float(diff["armored_chance"])
		explosive_chance = float(diff["explosive_chance"])
		unbreakable_pairs = int(diff["unbreakable_pairs"])
		empty_skip_chance = 0.06

	var breakable_count: int = 0
	var unbreakable_placed: int = 0

	for r: int in range(ROWS):
		for c: int in range(int(COLS / 2)):
			if rng.randf() < empty_skip_chance and r > 0:
				continue

			var b_type: String = "NORMAL"
			var roll: float = rng.randf()
			if unbreakable_placed < unbreakable_pairs and r >= 2 and r <= 4 and c >= 1 and roll < 0.16:
				b_type = "UNBREAKABLE"
				unbreakable_placed += 1
			elif roll < explosive_chance:
				b_type = "EXPLOSIVE"
			elif roll < explosive_chance + armored_chance:
				b_type = "ARMORED"

			var mirror_c: int = (COLS - 1) - c
			var pair_cols: Array[int] = [c, mirror_c]
			for col_idx: int in pair_cols:
				var brick: Brick = brick_scene.instantiate() as Brick
				var pos_x: float = START_X + col_idx * (BRICK_W + GAP) + BRICK_W * 0.5
				var pos_y: float = START_Y + r * (BRICK_H + GAP) + BRICK_H * 0.5
				brick.position = Vector2(pos_x, pos_y - 260.0)
				container.add_child(brick)
				brick.setup(b_type, Vector2i(col_idx, r), level_or_wave, not is_classic_level)
				if b_type != "UNBREAKABLE":
					breakable_count += 1

				var tw: Tween = brick.create_tween()
				tw.tween_property(brick, "position:y", pos_y, 0.45 + r * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if breakable_count == 0:
		for col_idx: int in [3, 4]:
			var brick: Brick = brick_scene.instantiate() as Brick
			var pos_x: float = START_X + col_idx * (BRICK_W + GAP) + BRICK_W * 0.5
			var pos_y: float = START_Y + BRICK_H * 0.5
			brick.position = Vector2(pos_x, pos_y)
			container.add_child(brick)
			brick.setup("NORMAL", Vector2i(col_idx, 0), level_or_wave, not is_classic_level)
			breakable_count += 1

	return breakable_count
