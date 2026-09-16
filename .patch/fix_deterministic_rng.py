from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Expected patch target not found in {path}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


base = Path("src/map_generators/base_generator.gd")
replace_once(
    base,
    "var debug_splits: Array[Split] = []\n",
    """var debug_splits: Array[Split] = []\n\n# Dedicated stream for room topology and deterministic shuffles. Keep this separate\n# from obstacle/decor and Dice streams so seeding does not alter their correlations.\nvar generation_rng := RandomNumberGenerator.new()\n\n\nfunc set_generation_seed(value: int) -> void:\n\tgeneration_rng.seed = value + 1013904223\n\n\nfunc _shuffle_with_generation_rng(values: Array) -> void:\n\t# Array.shuffle() consumes Godot's global RNG. Fisher-Yates keeps topology isolated.\n\tfor i in range(values.size() - 1, 0, -1):\n\t\tvar j := generation_rng.randi_range(0, i)\n\t\tif i != j:\n\t\t\tvar tmp = values[i]\n\t\t\tvalues[i] = values[j]\n\t\t\tvalues[j] = tmp\n""",
)

text = base.read_text(encoding="utf-8")
for old, new in [
    ("randi() % max_room_w", "generation_rng.randi() % max_room_w"),
    ("randi() % max_room_h", "generation_rng.randi() % max_room_h"),
    ("randi() % (w - room_w - 2)", "generation_rng.randi() % (w - room_w - 2)"),
    ("randi() % (h - room_h - 2)", "generation_rng.randi() % (h - room_h - 2)"),
    ("if randf() < horizontal_split_chance", "if generation_rng.randf() < horizontal_split_chance"),
    ("var rng := RandomNumberGenerator.new()", "var rng := generation_rng"),
    ("directions.shuffle()", "_shuffle_with_generation_rng(directions)"),
]:
    text = text.replace(old, new)
base.write_text(text, encoding="utf-8")


dungeon = Path("src/map_generators/dungeon_generator.gd")
old_setup = """\t# Initialize Dice RNG\n\tDice.set_seed()\n\n\tvar depth: int = params.get(\"depth\", 1)\n\tvar attempts := 50\n\tvar map: Map\n\n\twhile attempts > 0:\n\t\tmap = _initialize_empty_map(width, height, depth)\n\t\t_rng = RandomNumberGenerator.new()\n\t\tDice._rng = _rng\n"""
new_setup = """\tvar depth: int = params.get(\"depth\", 1)\n\tvar generation_seed: int = int(params.get(\"generation_seed\", 1))\n\n\t# Three deterministic but independent streams preserve the generator's original\n\t# behavior while making the same expedition seed exactly reproducible.\n\tset_generation_seed(generation_seed)\n\t_rng = RandomNumberGenerator.new()\n\t_rng.seed = generation_seed + 1664525\n\tDice.set_seed(generation_seed + 747796405)\n\n\tvar attempts := 50\n\tvar map: Map\n\n\twhile attempts > 0:\n\t\tmap = _initialize_empty_map(width, height, depth)\n"""
replace_once(dungeon, old_setup, new_setup)
text = dungeon.read_text(encoding="utf-8").replace("rooms.shuffle()", "_shuffle_with_generation_rng(rooms)")
dungeon.write_text(text, encoding="utf-8")

# Add useful contract diagnostics without changing validation rules. This turns a failed\n# CI run into an actionable report instead of a generic retry warning.
world = Path("src/world.gd")
text = world.read_text(encoding="utf-8")
old_contract = """func _generated_map_meets_t0_contract(map: Map, plan: WorldPlan.LevelPlan) -> bool:\n\tif map == null or map.depth != plan.depth:\n\t\treturn false\n\tvar up := _find_stairs(map, Obstacle.Type.STAIRS_UP)\n\tvar down := _find_stairs(map, Obstacle.Type.STAIRS_DOWN)\n\tif plan.up_destination != \"\" and up == Utils.INVALID_POS:\n\t\treturn false\n\tif plan.down_destination != \"\" and down == Utils.INVALID_POS:\n\t\treturn false\n\tif plan.down_destination == \"\" and down != Utils.INVALID_POS:\n\t\treturn false\n\tif up != Utils.INVALID_POS and down != Utils.INVALID_POS and not _has_walkable_route(map, up, down):\n\t\treturn false\n\treturn true\n"""
new_contract = """func _generated_map_meets_t0_contract(map: Map, plan: WorldPlan.LevelPlan) -> bool:\n\tif map == null:\n\t\tLog.w(\"T0 map contract: floor %d returned null\" % plan.depth)\n\t\treturn false\n\tif map.depth != plan.depth:\n\t\tLog.w(\"T0 map contract: floor %d depth mismatch (%d)\" % [plan.depth, map.depth])\n\t\treturn false\n\tvar up := _find_stairs(map, Obstacle.Type.STAIRS_UP)\n\tvar down := _find_stairs(map, Obstacle.Type.STAIRS_DOWN)\n\tif plan.up_destination != \"\" and up == Utils.INVALID_POS:\n\t\tLog.w(\"T0 map contract: floor %d missing entrance stairs\" % plan.depth)\n\t\treturn false\n\tif plan.down_destination != \"\" and down == Utils.INVALID_POS:\n\t\tLog.w(\"T0 map contract: floor %d missing descent stairs\" % plan.depth)\n\t\treturn false\n\tif plan.down_destination == \"\" and down != Utils.INVALID_POS:\n\t\tLog.w(\"T0 map contract: floor %d unexpectedly has descent stairs\" % plan.depth)\n\t\treturn false\n\tif up != Utils.INVALID_POS and down != Utils.INVALID_POS and not _has_walkable_route(map, up, down):\n\t\tLog.w(\"T0 map contract: floor %d stairs are disconnected (%s -> %s)\" % [plan.depth, up, down])\n\t\treturn false\n\treturn true\n"""
if old_contract in text:
    text = text.replace(old_contract, new_contract, 1)
world.write_text(text, encoding="utf-8")

print("Applied independent deterministic RNG streams and T0 diagnostics.")
