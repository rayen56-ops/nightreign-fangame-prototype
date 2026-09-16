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
    """var debug_splits: Array[Split] = []\n\n# Dedicated RNG for procedural generation. Topology must never depend on the engine-global RNG.\nvar generation_rng := RandomNumberGenerator.new()\n\n\nfunc set_generation_seed(value: int) -> void:\n\tgeneration_rng.seed = value\n\n\nfunc _shuffle_with_generation_rng(values: Array) -> void:\n\t# Array.shuffle() consumes the global RNG. Fisher-Yates keeps the map on one private stream.\n\tfor i in range(values.size() - 1, 0, -1):\n\t\tvar j := generation_rng.randi_range(0, i)\n\t\tif i != j:\n\t\t\tvar tmp = values[i]\n\t\t\tvalues[i] = values[j]\n\t\t\tvalues[j] = tmp\n""",
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
new_setup = """\tvar depth: int = params.get(\"depth\", 1)\n\tvar generation_seed: int = int(params.get(\"generation_seed\", 1))\n\tset_generation_seed(generation_seed)\n\t_rng = generation_rng\n\t# Dice and all dungeon-generation choices share the same deterministic stream.\n\tDice._rng = _rng\n\n\tvar attempts := 50\n\tvar map: Map\n\n\twhile attempts > 0:\n\t\tmap = _initialize_empty_map(width, height, depth)\n"""
replace_once(dungeon, old_setup, new_setup)
text = dungeon.read_text(encoding="utf-8").replace("rooms.shuffle()", "_shuffle_with_generation_rng(rooms)")
dungeon.write_text(text, encoding="utf-8")

print("Applied deterministic procedural-generation RNG patch.")
